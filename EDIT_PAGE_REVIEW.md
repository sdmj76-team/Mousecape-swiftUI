# Edit 页面代码审查报告

**审查日期：** 2026-02-25
**修复日期：** 2026-02-25
**审查范围：** 21 个文件，约 7,548 行代码
**审查模型：** Claude Opus 4.6 × 4 agents（功能、UI/UX、性能、安全）
**修复状态：** P0 全部修复 ✅ | P1 全部修复 ✅ | 编译通过 ✅ | 测试通过 ✅

---

## 一、功能逻辑审查

### 严重问题

#### 1. ~~Redo 功能完全失效~~ ✅ 已修复

**文件：** `AppState.swift:443-474`

`registerUndo` 方法接收了 `redo` 闭包参数但从未存储，`redoStack` 永远为空，`canRedo` 永远为 `false`。

```swift
func registerUndo(undo undoAction: @escaping () -> Void, redo redoAction: @escaping () -> Void) {
    redoStack.removeAll()       // 清空 redo 栈
    undoStack.append(undoAction) // 只存了 undo
    // ❌ redoAction 参数被完全忽略，从未存储
}
```

**影响：** 用户无法执行任何 redo 操作。所有传入的 `redo` 闭包全部被丢弃。

**修复建议：** 将 undo 和 redo 闭包配对存储（元组 `(undo: () -> Void, redo: () -> Void)`），undo 执行时将对应的 redo 压入 redoStack，反之亦然。

#### 2. ~~Undo 后 `hasUnsavedChanges` 状态不准确~~ ✅ 已修复

**文件：** `AppState.swift:459-467`

```swift
func undo() {
    guard let undoAction = undoStack.popLast() else { return }
    undoAction()
    if undoStack.isEmpty {
        hasUnsavedChanges = false  // ❌ 栈空 ≠ 回到保存状态
    }
}
```

**问题：** `markAsChanged()` 设置 `hasUnsavedChanges = true` 但不压入 undo 栈（如图片导入），导致 undo 栈清空后状态追踪不一致。

**影响：** 用户可能在有未保存更改时被允许无确认关闭编辑，导致数据丢失。

#### 3. 新建 Cape 后 revertToSaved 残留空文件

**文件：** `AppState.swift:252-272, 492-504`

`createNewCape()` 创建后立即写入空 cape 文件并加入列表。用户选择 "Don't Save" 时，`revertToSaved()` 恢复到空 cape 状态，但空文件仍残留在磁盘和列表中。

### 中等问题

#### 4. 删除/添加光标操作不可撤销

**文件：** `AppState.swift:696-708`

`deleteSelectedCursor()` 和 `addCursor(type:)` 只调用 `markAsChanged()` 而没有 `registerUndo()`。用户误删光标后只能取消整个编辑会话来恢复。

#### 5. 图片导入操作不可撤销

**文件：** `EditOverlayView.swift:871-1188`

所有图片导入操作（PNG/JPEG/TIFF、GIF、.cur/.ani）都只调用 `markAsChanged()` 而没有注册撤销。导入新图片会覆盖旧图片数据，且无法恢复。

#### 6. Undo 闭包中 struct self 捕获问题

**文件：** `EditOverlayView.swift:449-462`

SwiftUI View 是 struct，闭包中捕获的 `self` 是值拷贝。undo 执行时修改的是闭包捕获时的副本的 `@State` 变量，可能不会反映到 UI 上，造成数据和 UI 不一致。

#### 7. GIF 帧失败率超 20% 后仍继续导入

**文件：** `EditOverlayView.swift:1034-1048`

显示警告后没有 `return false`，继续执行后续导入逻辑。大量帧损坏时导入的动画质量会很差。

#### 8. Hotspot onChange 静默 clamp 无用户反馈

**文件：** `EditOverlayView.swift:500-578`

值被静默 clamp 到 `[0, MCMaxHotspotValue]`，clamping 发生在验证之前，红色边框可能永远不会出现。

#### 9. `loadCursorValues` 中 `DispatchQueue.main.async` 时序依赖

**文件：** `EditOverlayView.swift:724-744`

依赖 SwiftUI onChange 在同一 RunLoop 周期内触发的假设，不同 macOS 版本可能行为不同。

#### 10. 简易模式 alias 同步的引用安全

**文件：** `CursorLibrary.swift:116-141`

`syncMetadataToAliases` 使用 `copyMetadata` 共享图像引用，先 `removeCursor` 再 `addCursor`，存在引用时序风险（实际风险较低）。

### 轻微问题

#### 11. `Cursor.init` 默认 `frameDuration = 1.0` 语义不一致

单帧光标不需要动画，应为 0。GIF 单帧导入正确设置了 0.0，但 AddCursorSheet 新建的默认是 1.0。

#### 12. `CursorLibrary.id` 使用 `ObjectIdentifier` 可能在 revert 后失效

基于 ObjC 对象内存地址，如果 revert 创建新对象则 id 会变化。实际风险较低。

#### 13. `previewImage` 使用已弃用的 `lockFocus`/`unlockFocus`

macOS 14+ 已标记弃用，应迁移到 `NSImage(size:flipped:drawingHandler:)` 或 CGContext。

#### 14. `WindowsCursorConverter` 的 `@unchecked Sendable`

无状态单例，改为 `enum` 命名空间可自动满足 `Sendable`。

---

## 二、UI/UX 审查

### 严重问题

#### 1. 大量 UI 字符串未本地化

涉及文件：EditOverlayView.swift、AddCursorSheet.swift、CapeInfoView.swift

未本地化的字符串包括：
- EditOverlayView: `"Select a Cursor"`, `"Simple"` / `"Advanced"`, `"Type"` / `"Hotspot"` / `"Animation"`, `"X:"` / `"Y:"`, `"Frames:"` / `"Speed:"`, `"frames/sec"`, `"Drag image or click to select"`, `"Recommended: 64×64 px (HiDPI 2x)"`, `"Overwrite Alias Cursors?"`, toolbar help 文本等
- AddCursorSheet: `"Add Cursor"`, `"All Cursor Groups Added"` / `"All Cursor Types Added"` 等
- CapeInfoView: `"Cape Information"`, `"Name"` / `"Author"` / `"Version"` / `"HiDPI"` 等

**注意：** SwiftUI `Text("...")` 会自动查找 .xcstrings 中的键，需确认所有字符串在 Localizable.xcstrings 中有中文条目。toolbar `.help()` 中的字符串不会自动本地化，需显式使用 `String(localized:)`。

#### 2. ~~可访问性（Accessibility）严重缺失~~ ✅ 已修复

整个编辑页面几乎没有任何可访问性标注：
- 无 `accessibilityLabel` — 光标预览图像、热点指示器、拖放区域均无语义描述
- 无 `accessibilityHint` — 拖放区域、文件选择器触发区域缺少操作提示
- 无 `accessibilityValue` — 热点坐标、FPS、帧数等数值字段缺少语义值
- `CursorPreviewDropZone` 仅有 `.help()` 提示
- `AnimatingCursorView` 动画帧切换对 VoiceOver 不可见
- `HotspotIndicator`（红色圆点）完全没有可访问性信息
- 侧边栏列表行缺少 `accessibilityElement` 组合

### 中等问题

#### 3. 热点坐标输入验证体验不佳

**文件：** `EditOverlayView.swift:488-498, 539-549`

超出范围时直接 revert 到旧值，无视觉反馈。建议允许输入后显示红色边框 + 范围提示（如 "0 ~ 31.99"）。

#### 4. FPS 标签语义不一致

**文件：** `EditOverlayView.swift:637-680`

标签 "Speed:" 与单位 "frames/sec" 不一致。建议统一为 "FPS:" 或 "Frame Rate:"。

#### 5. 拖放区域固定高度 200px

**文件：** `EditOverlayView.swift:833`

小窗口下占据过多空间。建议使用 `minHeight` + `maxHeight` 或 GeometryReader 自适应。

#### 6. ~~GIF 解码失败警告使用 NSAlert 而非 SwiftUI alert~~ ✅ 已修复

**文件：** `EditOverlayView.swift:1040-1048`

`NSAlert().runModal()` 阻塞主线程，与其他 SwiftUI `.alert()` 不一致。建议统一使用 AppState 中已有的 alert 机制。

#### 7. Simple/Advanced 模式切换无过渡动画

**文件：** `EditOverlayView.swift:226-234`

直接清空选择，右侧面板突然跳到空状态，体验生硬。

#### 8. AddCursorSheet 固定尺寸

**文件：** `AddCursorSheet.swift:50`

`.frame(width: 350, height: 420)` 固定尺寸，Advanced 模式下 20+ 种类型时滚动区域较小。

#### 9. `lockFocus`/`unlockFocus` 已弃用

**文件：** `Cursor.swift:220-226`, `AnimatingCursorView.swift:107-114`

macOS 14+ 已标记 deprecated，应迁移到 CGContext 方式。

### 轻微问题

#### 10. ~~热点指示器在红色光标上不够醒目~~ ✅ 已修复

`Color.red` 填充在红色主色调光标上难以辨认。建议添加白色外圈。

#### 11. ~~CapeInfoView 光标网格缺少空状态~~ ✅ 已修复

无光标时 `LazyVGrid` 显示空白，无提示文字。

#### 12. Animation 区域对静态光标仍可见

`frameCount = 1` 时 Frames 和 Speed 字段多余，可考虑默认折叠。

#### 13. ~~NavigationSplitView 列宽可能过窄~~ ✅ 已修复

最小宽度 180 显示长名称（如 "Working in Background"）时可能截断，建议提升到 200。

#### 14. 深色模式适配细节

- 拖放区域 `Color.accentColor.opacity(0.1)` 在深色模式下可能不够明显
- 空状态图标 `.foregroundStyle(.tertiary)` 在深色模式下可能过于暗淡

---

## 三、性能审查

### 严重问题

#### 1. ~~AnimatingCursorView 每帧创建新 NSImage~~ ✅ 已修复

**文件：** `AnimatingCursorView.swift:87-117`

每次 Timer 触发时执行 `lockFocus()` / `unlockFocus()` 创建新 NSImage。24 帧 10FPS 动画每秒创建 10 个临时对象，造成内存抖动和 GC 压力。

**建议修复：** 预缓存帧数组，使用 `CGImage.cropping(to:)` 直接裁剪：

```swift
@State private var cachedFrames: [NSImage] = []

private func buildFrameCache() {
    guard let image = cursor.image else { return }
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let frameCount = max(1, cursor.frameCount)
    let frameH = cgImage.height / frameCount
    cachedFrames = (0..<frameCount).compactMap { i in
        let rect = CGRect(x: 0, y: i * frameH, width: cgImage.width, height: frameH)
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: cgImage.width, height: frameH))
    }
}
```

#### 2. ~~图像处理全部在主线程同步执行~~ ✅ 已修复（createSpriteSheet CGContext 线程安全 + loadImage/loadGIFImage/loadWindowsCursor 异步化）

**文件：** `EditOverlayView.swift:871-1188`

`loadGIFImage`、`loadWindowsCursor`、`loadImage` 的所有图像处理（解码、缩放、sprite sheet 创建）都在主线程同步执行。大型 GIF 可能阻塞 UI 数百毫秒到数秒。

**建议修复：** 移到 `Task.detached` 并显示加载指示器。

#### 3. ~~`createSpriteSheet` 使用非线程安全的 NSGraphicsContext~~ ✅ 已修复

**文件：** `CursorImageScaler.swift:148-196`

使用 `NSGraphicsContext.saveGraphicsState()` / `restoreGraphicsState()` 和 `NSGraphicsContext.current = context`，非线程安全，阻止将图像处理安全地移到后台线程。

**建议修复：** 统一使用 CGContext（与 `scaleImageToStandardSize` 和 `scaleSpriteSheet` 一致）。

### 中等问题

#### 4. @Observable 模型过度刷新风险

**文件：** `AppState.swift`

`AppState` 包含约 30 个属性，`cursorListRefreshTrigger` 等 Int 触发器每次递增都可能导致不必要的视图重建。

**建议：** 考虑将编辑相关状态拆分为独立的 `@Observable EditState` 类。

#### 5. `Cursor.previewImage` 每次调用都重新生成

**文件：** `Cursor.swift:205-227`

在列表 body 中被调用，每次视图重建都重新裁剪和绘制。建议添加缓存机制。

#### 6. `CursorLibrary.cursors` 缓存频繁失效

**文件：** `CursorLibrary.swift:73-84`

`invalidateCursorCache()` 在多处被调用，缓存失效后重新从 ObjC Set 映射、排序。当前光标数量较少影响有限。

#### 7. 撤销闭包捕获完整引用

undo/redo 闭包持有 `appState`、`cape`、`cursor` 的引用，20 步上限下内存可控但不够高效。

#### 8. GIF 警告使用 `NSAlert.runModal()` 阻塞主线程

`DispatchQueue.main.async` 中调用 `runModal()` 只是延迟了一个 runloop 周期。

### 轻微问题

#### 9. UTType 扩展每次访问创建新实例

`static var` 计算属性改为 `static let` 更高效。

#### 10. `supportedImageTypes` 每次访问创建新数组

可改为 `static let`。

#### 11. Sprite sheet 内存峰值

24 帧 256x256 动画峰值约 12MB，有硬限制保护，风险极低。

#### 12. `Cursor.displayName` 每次访问执行字符串处理

字符串很短，开销可忽略。

---

## 四、安全审查

### 严重问题

#### 1. ~~BMP 解码器 width/height 无上限检查（OOM 崩溃）~~ ✅ 已修复

**文件：** `WindowsCursorParser.swift:939`（及所有 decode*BMP 函数）

`width` 和 `height` 直接来自二进制文件头部，无上限检查。恶意 .cur/.ani 可声明 65535×65535 尺寸，导致分配约 16GB 内存。

**建议：** 在 `decodeBMPCursor` 入口处对 `actualWidth` 和 `actualHeight` 添加上限检查（`MCMaxImportSize = 512`）。

#### 2. ~~ANI 解析器 chunkSize=0 导致无限循环~~ ✅ 已修复

**文件：** `WindowsCursorParser.swift:316`

`chunkSize` 来自文件且无合理性检查。为 0 时 `reader.skip(0)` 不推进偏移量，导致无限循环。

**建议：** 添加 `guard chunkSize > 0` 和 `guard chunkSize <= reader.remaining` 检查。

#### 3. ~~CUR imageOffset+imageSize 可能整数溢出~~ ✅ 已修复

**文件：** `WindowsCursorParser.swift:272-273`

`imageOffset` 和 `imageSize` 直接来自文件，如果相加溢出 Int 可能绕过 BinaryReader 边界检查。

**建议：** seek 前验证 `imageOffset >= 0 && imageOffset + imageSize <= data.count`，并检查加法溢出。

### 中等问题

#### 4. RLE 解码器缺少循环终止保护

**文件：** `WindowsCursorParser.swift:741`

依赖文件中的 end-of-bitmap 标记终止，恶意文件可消耗大量 CPU。建议添加最大迭代次数限制。

#### 5. Sprite Sheet 帧数在降采样前无上限

**文件：** `WindowsCursorParser.swift:1330-1362`

`parseANI` 中 sprite sheet 在降采样之前创建，ANI 声明数千帧时可能非常大。建议先降采样再创建。

#### 6. INF 路径解析未完全防御路径遍历

**文件：** `WindowsINFParser.swift:257-284`

`resolveFilename` 提取最后路径组件，但文件名含 `..` 时未显式验证。实际风险较低。

**建议：** 验证文件名不包含 `/`、`\` 和 `..`。

#### 7. `validateBeforeSave` 缺少热点坐标上限检查

**文件：** `AppState.swift:781`

只检查 `< 0`，不检查 `> MCMaxHotspotValue`。可通过直接修改 .cape plist 绕过 UI 验证。

#### 8. Cape plist 反序列化缺少类型验证

**文件：** `apply.m:332`

加载 cape 后直接访问字典值，无类型检查。恶意 .cape 可能导致 unrecognized selector 崩溃。

#### 9. Name/Author 字段仅允许 ASCII

**文件：** `AppState.swift:732-733`

`allowedNameCharacters` 只含 `alphanumerics` + ` -_()`，中文字符被过滤。INF 导入时中文名称会被过滤为空字符串。

### 轻微问题

#### 10. GIF 帧数无上限检查

**文件：** `EditOverlayView.swift:956`

降采样前先解码所有帧，恶意 GIF 含数千帧时临时内存峰值很高。建议添加帧数上限（如 1000）。

#### 11. ~~拖放 URL 未验证 scheme~~ ✅ 已修复

**文件：** `EditOverlayView.swift:855-857`

未检查 `url.isFileURL`，理论上可拖入 `http://` URL。

#### 12. 调试日志可能泄露文件路径

DEBUG 构建记录完整路径和用户名。风险极低（24h 自动清理，仅 DEBUG 有效）。

#### 13. CUR `imageCount` 无上限

UInt16 最大 65535，每个 entry 16 字节约 1MB，BinaryReader 边界检查会兜底。建议添加合理上限（如 256）。

---

## 优先修复建议

| 优先级 | 问题 | 类别 | 影响 | 状态 |
|--------|------|------|------|------|
| **P0** | BMP 解码器宽高上限检查 | 安全 | 恶意文件 OOM 崩溃 | ✅ 已修复 |
| **P0** | ANI chunkSize=0 无限循环 | 安全 | 恶意文件卡死应用 | ✅ 已修复 |
| **P0** | Redo 功能完全失效 | 功能 | 核心功能 bug | ✅ 已修复 |
| **P1** | 图像处理移到后台线程 | 性能 | 主线程阻塞卡顿 | ✅ 已修复 |
| **P1** | AnimatingCursorView 帧缓存 | 性能 | 动画预览内存抖动 | ✅ 已修复 |
| **P1** | Undo 后 hasUnsavedChanges 状态 | 功能 | 潜在数据丢失 | ✅ 已修复 |
| **P1** | CUR imageOffset 整数溢出 | 安全 | 恶意文件绕过检查 | ✅ 已修复 |
| **P2** | UI 字符串本地化 | UI | 中文用户体验 | ✅ 已修复 |
| **P2** | 可访问性标注 | UI | VoiceOver 支持 | ✅ 已修复 |
| **P2** | Name/Author 支持中文 | 安全/功能 | 中文用户需求 | 待修复 |
| **P2** | 删除/添加光标可撤销 | 功能 | 误操作恢复 | 待修复 |
| **P2** | NSAlert 统一为 SwiftUI alert | UI | 代码一致性 | ✅ 已修复 |
| **P3** | lockFocus 迁移到 CGContext | 性能/UI | 弃用 API 迁移 | ✅ 已修复 |
| **P3** | createSpriteSheet 线程安全 | 性能 | 后台处理前置条件 | ✅ 已修复 |
| **P3** | 其他轻微问题 | 各类 | 代码质量提升 | ✅ 大部分已修复 |
