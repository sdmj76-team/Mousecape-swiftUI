# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

@README.md - 项目介绍、功能说明、使用指南
@RELEASE_NOTES.md - 版本更新日志

## 项目概述

Mousecape 是一款免费的 macOS 光标管理器，使用私有 CoreGraphics API 来自定义系统光标。它由两个构建目标组成，协同工作以应用和持久化自定义光标主题（"cape"）。

**系统要求：** macOS Sequoia (15.0) 或更高版本

**技术栈：** SwiftUI + Swift + Objective-C 混合架构
- GUI 层：纯 SwiftUI（@Observable 状态管理）
- CLI 工具：Swift（使用 ArgumentParser）
- 数据模型层：Swift 包装器 + ObjC 实现（保留 ObjC 以维护稳定性）
- 私有 API 层：Objective-C（使用 CoreGraphics 私有 API）

## 构建命令

在 Xcode 中打开 `Mousecape/Mousecape.xcodeproj`：

```bash
# 构建应用
xcodebuild -project Mousecape/Mousecape.xcodeproj -scheme Mousecape build

# 构建特定目标
xcodebuild -project Mousecape/Mousecape.xcodeproj -target mousecloak build
```

## 架构

### 三个构建目标

1. **Mousecape**（GUI 应用）- 使用 SwiftUI 界面的主 macOS 应用程序
   - 入口：`Mousecape/SwiftUI/MousecapeApp.swift`
   - 自适应设计：macOS 26+ 使用液态玻璃（Liquid Glass），macOS 15 使用 Material 背景
   - 窗口管理：标准 `.regular` 模式，关闭窗口后程序退出
   - 与 Helper 通信：通过 `SMAppService.loginItem(identifier:)` 控制 Helper 的启动/停止

2. **MousecapeHelper**（后台助手）- 负责开机启动和会话监听的独立应用
   - 入口：`Mousecape/MousecapeHelper/MousecapeHelperApp.swift`
   - 菜单栏常驻：通过 `MenuBarExtra` 提供菜单栏图标，可唤起主应用
   - 开机启动：通过 `SMAppService.loginItem` 注册为系统登录项
   - 会话监听：通过 `startSessionMonitor()` 监听用户会话变化和显示器重配置，自动重新应用光标
   - 系统集成：作为 Login Item 注册，由系统管理生命周期

3. **mousecloak**（CLI 工具）- 用于应用 cape 的命令行工具
   - 入口：`Mousecape/mousecloak/main.swift`
   - 命令：`apply`、`reset`、`create`、`dump`、`scale`、`convert`、`export`、`listen`
   - 使用 Swift ArgumentParser 进行参数解析
   - 通过 bridging header 桥接 ObjC 私有 API 层

### 数据流

```
SwiftUI Views (AppState @Observable)
    ↓
Swift 包装器 (Cursor.swift, CursorLibrary.swift)
    ↓
ObjC 模型 (MCCursor, MCCursorLibrary)
    ↓
MCLibraryController
    ↓
私有 API (mousecloak/apply.m)

主应用 ↔ Helper 通信:
Mousecape (SMAppService API) ←→ MousecapeHelper (Login Item)
    ↓ NSWorkspace.shared.open()
Helper 会话监听:
startSessionMonitor() → UserSpaceChanged / reconfigurationCallback → applyCapeAtPath()
```

### 核心数据模型（Mousecape/Mousecape/src/models/）

- **MCCursor** - 单个光标，包含多个缩放比例表示（1x、2x、5x、10x）、动画帧、热点和持续时间
- **MCCursorLibrary** - Cape（光标主题），包含元数据和光标集合

### 私有 API 层（Mousecape/mousecloak/）

- **CGSInternal/** - 私有 CoreGraphics API 头文件（CGSCursor.h 是关键）
- **apply.m** - 通过 `CGSRegisterCursorWithImages()` 注册光标
- **backup.m/restore.m** - 备份和恢复原始系统光标，使用 `MCEnumerateAllCursorIdentifiers()` 遍历所有光标
- **listen.m** - 会话变化监听器，提供两个入口：
  - `listener()` — 阻塞式，用于 CLI `--listen` 命令，启动独立 RunLoop
  - `startSessionMonitor()` — 非阻塞式，用于主程序内嵌监听，附加到主 RunLoop
- **MCDefs.h/m** - 共享常量（`MCMaxFrameCount`、`MCMaxImportSize`、`MCMaxHotspotValue`）和工具函数

**Nullability：** 所有 ObjC 头文件均已添加 `NS_ASSUME_NONNULL_BEGIN/END` 注解，Swift 桥接时无需多余的 Optional 处理。

### 使用的关键私有 API

```objc
CGSRegisterCursorWithImages()   // 注册自定义光标图像
CoreCursorUnregisterAll()       // 将所有光标重置为系统默认
CGSCopyRegisteredCursorImages() // 读取当前光标数据
```

### SwiftUI 架构（Mousecape/Mousecape/SwiftUI/）

单窗口设计，基于叠层的导航：

```
SwiftUI/
├── MousecapeApp.swift（入口、MenuBarExtra 菜单栏、AppDelegate 登录启动检测与旧 Helper 迁移、窗口生命周期管理）
├── Models/
│   ├── AppState.swift（@Observable 状态管理）
│   ├── AppState+WindowsImport.swift（Windows 光标文件夹导入）
│   ├── AppEnums.swift
│   ├── Cursor.swift（MCCursor 包装器）
│   └── CursorLibrary.swift（MCCursorLibrary 包装器）
├── Views/
│   ├── MainView.swift（页面切换 + 工具栏）
│   ├── HomeView.swift（cape 列表 + 预览）
│   ├── SettingsView.swift
│   ├── EditOverlayView.swift（编辑时的叠层）
│   ├── CapeInfoView.swift（Cape 元数据编辑器）
│   ├── AddCursorSheet.swift（添加光标类型弹窗）
│   ├── CapePreviewPanel.swift
│   └── MousecapeCommands.swift（菜单命令）
├── Utilities/
│   ├── CursorImageScaler.swift（共享图像缩放常量和工具）
│   ├── LocalizationManager.swift（多语言支持）
│   ├── WindowsCursorParser.swift
│   ├── WindowsCursorConverter.swift
│   └── WindowsINFParser.swift
└── Helpers/
    ├── AnimatingCursorView.swift
    └── GlassEffectContainer.swift
```

**共享常量（CursorImageScaler.swift）：**
- `CursorImageScaler.standardCursorSize` = 64（标准光标像素尺寸）
- `CursorImageScaler.maxFrameCount` = 24（最大动画帧数）
- `CursorImageScaler.maxImportSize` = 512（最大导入图像尺寸）
- ObjC 侧对应：`MCMaxFrameCount`、`MCMaxImportSize`（定义在 MCDefs.h/m）

状态管理通过 `@Observable @MainActor AppState` 单例实现，带有手动撤销/重做栈（配对闭包）。

### 窗口生命周期管理

**简化设计：** 主应用使用标准 `.regular` 模式，关闭窗口后程序退出。开机启动和菜单栏功能由独立的 MousecapeHelper 负责。

**关键设计：**
- **标准窗口行为：** 主应用始终使用 `.regular` 模式（有 Dock 图标），关闭窗口后程序正常退出
- **Helper 独立运行：** MousecapeHelper 作为独立应用运行，提供菜单栏图标和开机启动功能
- **XPC 通信：** 主应用通过 XPC 连接控制 Helper 的启动/停止和光标应用
- **用户控制：** 用户通过"Launch at Login"开关控制 Helper 的开机启动行为
- **菜单栏唤起：** 用户点击 Helper 的菜单栏图标可唤起主应用窗口
- **文件打开事件：** `handleOpenDocumentEvent` 使用 `MainActor.assumeIsolated` 同步执行（Apple Event handler 在主线程）
- **主窗口引用：** `AppDelegate.mainWindow`（weak）在 `setupWindowDelegate` 时保存，避免每次通过 `NSApp.windows` 查找
- **WindowDelegate timer：** `setupWindowDelegate` 调用前先 `stopObserving()` 清理旧 timer，防止重复调用时 timer 泄漏

### 编辑模式：简易模式 / 高级模式

编辑界面支持两种模式，通过工具栏 Segmented Picker 切换，使用 `@AppStorage("cursorEditMode")` 持久化（0=简易，1=高级）。

**简易模式（Simple）：** 以 Windows 光标分组（15 组）展示，编辑一个分组时自动同步到组内所有 macOS 光标类型（Auto-Alias）。

**高级模式（Advanced）：** 逐个 macOS 光标类型编辑，保留完整控制。

#### WindowsCursorGroup 枚举（AppEnums.swift）

15 个分组对应 Windows 光标位置 0-14，复用 `WindowsINFParser.schemeRegPositionMapping` 映射到 macOS CursorType。

#### Auto-Alias 机制

- `Cursor.copy(withIdentifier:)` — 深拷贝光标（含图像）
- `Cursor.copyMetadata(withIdentifier:)` — 只拷贝元数据（hotspot/fps/frameCount），共享图像引用（性能优化）
- `CursorLibrary.syncCursorToAliases(_:)` — 完整同步到同组别名（图像导入时使用）
- `CursorLibrary.syncMetadataToAliases(_:)` — 只同步元数据到别名（参数修改时使用，避免不必要的图像深拷贝）
- `CursorLibrary.addCursorWithAliases(_:)` — 添加光标并自动创建同组别名
- `CursorLibrary.removeGroupCursors(for:)` — 删除分组中所有光标

#### 同步触发点（EditOverlayView.swift）

- hotspotX/Y、frameCount、fps 的 onChange → `syncMetadataToAliases`
- 图像导入（静态/GIF/Windows 光标）→ `syncCursorToAliases`
- undo/redo 闭包中也包含 alias 同步，通过 `capturedEditMode` 捕获模式值

#### 模式切换行为

- 切换模式时强制清空选中状态（`selectedGroup = nil`、`selection = nil`），回到 "Select a Cursor" 空状态
- 切换模式时关闭 info 面板
- 进入编辑页面时为无选择状态，由用户手动选择
- 删除光标后回到无选择状态
- 简易模式下删除光标会删除整个分组（`removeGroupCursors`）

#### 别名一致性检查

简易模式下首次编辑分组时，检查组内别名是否有不同的 hotspot/frameCount/frameDuration。如有差异，弹出确认弹窗。Cancel 会清空选中状态回到空状态。

#### AddCursorSheet 双模式

- 简易模式：显示 `WindowsCursorGroup` 分组列表，添加时调用 `addCursorWithAliases`
- 高级模式：显示完整 `CursorType` 列表（原有行为）

## 内存管理

**全 ARC 代码库：**
- Swift 文件：ARC（自动）
- Objective-C 文件：ARC（自动）

所有 mousecloak/ 目录下的 Objective-C 文件已于 2026-01 迁移至 ARC，不再使用手动内存管理（MRR）。

## ObjC 到 Swift 部分迁移（2026-03）

**迁移策略：** 采用"部分迁移"方案，保留稳定的 ObjC 核心层，扩展 Swift 包装器。

### 已迁移到 Swift

1. **CLI 工具（mousecloak）**
   - 从 `main.m` + GBCli 迁移到 `main.swift` + Swift ArgumentParser
   - 删除 GBCli 依赖（1,170 行 ObjC 代码）
   - 通过 `mousecloak-Bridging-Header.h` 桥接 ObjC 私有 API 层
   - 8 个子命令：apply, reset, create, dump, convert, export, scale, listen

2. **数据模型包装器**
   - `Cursor.swift` - 扩展序列化功能（`init(dictionary:)`, `toDictionary()`, `setImageData`, `imageData`）
   - `CursorLibrary.swift` - 扩展序列化、验证、变更追踪功能
   - 使用 KVC 访问 ObjC 私有属性（changeCount, lastChangeCount）

3. **GUI 应用状态管理**
   - `AppState.swift` - 完全使用 Swift 包装器，移除直接的 ObjC 模型调用

### 保留 ObjC 实现

**原因：** 稳定可靠，迁移风险大，与私有 API 紧密耦合

1. **数据模型层（src/models/）**
   - `MCCursor.h/m` - 光标模型（792 行）
   - `MCCursorLibrary.h/m` - Cape 容器
   - `MCLibraryController.h/m` - 库管理器

2. **私有 API 层（mousecloak/）**
   - `apply.m`, `backup.m`, `restore.m`, `listen.m` - 核心功能（3,262 行）
   - `CGSInternal/` - 私有 CoreGraphics API 头文件
   - `MCDefs.h/m`, `MCLogger.h/m`, `MCPrefs.h/m` - 工具类

### 架构设计

```
Swift GUI 层（SwiftUI Views + AppState）
    ↓ 使用
Cursor.swift / CursorLibrary.swift（Swift 包装器）
    ↓ 内部使用
MCCursor / MCCursorLibrary（ObjC 模型层）← 保留
    ↓ 使用
私有 API 层（mousecloak/）← 保留
```

**关键约束：**
- Cape 文件格式不变 - 使用 NSDictionary 序列化（不用 Codable）
- 线程安全策略 - 使用 @MainActor（与 SwiftUI 架构一致）
- 向后兼容 - 所有旧版本 cape 文件可正常加载

### 迁移成果

- **删除：** 1,170 行 ObjC（GBCli）
- **新增：** 642 行 Swift（CLI + 序列化）
- **保留：** 4,054 行 ObjC（模型层 + 私有 API）
- **净减少：** 528 行代码
- **性能提升：** CLI 工具比 GBCli 快 80%（~40ms 提升）
- **安全性评分：** 7.5/10（高优先级问题已修复）



Cape 是二进制 plist 文件（`.cape` 扩展名），包含：
- 元数据：名称、作者、标识符、版本、hiDPI 标志
- 按标识符索引的光标字典（例如 `com.apple.coregraphics.Arrow`）
- 每个光标包含 100x、200x、500x、1000x 缩放比例的 HEIF 数据表示（无损压缩，quality = 1.0）

**Cape 库位置：** `~/Library/Application Support/Mousecape/capes/`

**序列化实现：**
- Swift 层：`Cursor.swift` 和 `CursorLibrary.swift` 提供 `toDictionary()` 和 `init(dictionary:)` 方法
- 使用 NSDictionary 序列化（不使用 Codable），确保与旧版本 cape 文件完全兼容
- 图像数据使用 HEIF 无损压缩格式存储（compressionFactor = 1.0），文件大小比 TIFF 小约 60%
- 读取时通过 `NSBitmapImageRep(data:)` 自动检测格式，兼容旧版 PNG/TIFF cape 文件

## Windows 光标转换

使用原生 Swift 实现，无需外部依赖：
- `WindowsCursorParser.swift` - 原生 Swift 解析器，支持 .cur/.ani 格式
- `WindowsCursorConverter.swift` - 转换器，将解析结果转为 Mousecape 格式
- `WindowsINFParser.swift` - 解析 Windows install.inf 文件，基于 `[Scheme.Reg]` 位置映射

### INF 解析逻辑

Windows 光标主题通过 `[Scheme.Reg]` 段定义光标位置顺序（固定 0-16 位），这是 Windows 注册表的标准格式：

**编码支持：**

INF 解析器自动检测文件编码，支持多种编码格式：
- **Unicode**: UTF-8, UTF-16 LE, UTF-16 BE
- **中文**: GBK (0x0631), GB18030, Big5
- **亚洲**: Shift_JIS, EUC-KR
- **西文**: ISO-8859-1

使用 `CFStringCreateWithBytes` API 直接支持非 Unicode 编码（如 GBK），并通过内容验证（替换字符检测、控制字符比例、中文字符检测）确保选择正确的编码。

| 位置 | Windows 光标 | macOS CursorType |
|-----|-------------|------------------|
| 0 | Normal Select | `.arrow`, `.arrowCtx`, `.arrowS`, `.ctxMenu` |
| 1 | Help Select | `.help` |
| 2 | Working in Background | `.wait` |
| 3 | Busy | `.busy`, `.countingUp`, `.countingDown`, `.countingUpDown` |
| 4 | Precision Select | `.crosshair`, `.crosshair2`, `.cell`, `.cellXOR` |
| 5 | Text Select | `.iBeam`, `.iBeamXOR`, `.iBeamS`, `.iBeamH` |
| 6 | Handwriting | `.open`, `.closed` |
| 7 | Unavailable | `.forbidden` |
| 8 | Vertical Resize | `.resizeNS`, `.windowNS`, `.resizeN`, `.resizeS`, `.windowN`, `.windowS` |
| 9 | Horizontal Resize | `.resizeWE`, `.windowEW`, `.resizeW`, `.resizeE`, `.windowE`, `.windowW` |
| 10 | Diagonal Resize 1 | `.windowNWSE`, `.windowNW`, `.windowSE` |
| 11 | Diagonal Resize 2 | `.windowNESW`, `.windowNE`, `.windowSW` |
| 12 | Move | `.move`, `.resizeSquare` |
| 13 | Alternate Select | `.alias` |
| 14 | Link Select | `.pointing`, `.link` |
| 15-16 | Location/Person | 无 macOS 对应 |

**未映射的类型（8个）：** `copy`, `copyDrag`, `camera`, `camera2`, `poof`, `zoomIn`, `zoomOut`, `empty` — 无合适的 Windows 对应类型。

**覆盖率：** 44/52 macOS 光标类型被映射（85%）。

路径解析支持两种格式：
- `%10%\Cursors\%pointer%` - 从 `[Strings]` 段查找变量对应的文件名
- `%10%\Cursors\Normal.ani` - 直接使用文件名

### 动画光标帧数限制与速度计算

**系统限制：** macOS 光标动画最大支持 **24 帧**。导入超过 24 帧的动画时会自动抽帧。

#### GIF 动画导入

**帧数限制逻辑** ([EditOverlayView.swift:1021-1144](Mousecape/Mousecape/SwiftUI/Views/EditOverlayView.swift#L1021-L1144)):
```swift
let maxFrameCount = 24
if frames.count > maxFrameCount {
    let downsampledFrames = downsampleFrames(frames, targetCount: maxFrameCount)
    frames = downsampledFrames
    // 调整总时长以保持动画播放速度一致
    totalDuration *= Double(originalFrameCount) / Double(maxFrameCount)
}
```

**速度计算：**
1. 从 GIF 属性读取帧延迟：`kCGImagePropertyGIFDelayTime` 或 `kCGImagePropertyGIFUnclampedDelayTime`
2. 默认延迟：0.1 秒（100ms）
3. FPS 计算：`fps = 1 / frameDuration`

**示例：** 32 帧 GIF，每帧 0.1 秒
- 抽帧后：24 帧
- 调整后帧时长：`0.1 × (32/24) = 0.133 秒`
- 最终 FPS：`1 / 0.133 ≈ 7.5`

#### ANI 动画导入

**帧数限制逻辑** ([WindowsCursorConverter.swift:163-211](Mousecape/Mousecape/SwiftUI/Utilities/WindowsCursorConverter.swift#L163-L211)):
```swift
if parseResult.frameCount > maxFrameCount {
    // 抽帧处理 sprite sheet
    guard let downsampledData = downsampleSpriteSheet(...) else { ... }

    // 调整帧时长以保持动画播放速度一致
    let adjustedDuration = parseResult.frameDuration *
        (Double(parseResult.frameCount) / Double(maxFrameCount))
}
```

**速度计算：** ([WindowsCursorParser.swift:356-363](Mousecape/Mousecape/SwiftUI/Utilities/WindowsCursorParser.swift#L356-L363))
1. 从 ANI 头部读取 `displayRate` 或 `rate` chunk
2. Jiffies 转换：`frameDuration = rate / 60.0`（1 jiffy = 1/60 秒）
3. FPS 计算：`fps = 1 / adjustedDuration`

**示例：** 32 帧 ANI，displayRate = 10（每帧 10 jiffys）
- 原始帧时长：`10 / 60 = 0.167 秒`
- 抽帧后帧时长：`0.167 × (32/24) = 0.222 秒`
- 最终 FPS：`1 / 0.222 ≈ 4.5`

#### 抽帧策略

**均匀采样算法** ([EditOverlayView.swift:1191-1208](Mousecape/Mousecape/SwiftUI/Views/EditOverlayView.swift#L1191-L1208))：
```swift
private func downsampleFrames(_ frames: [NSImage], targetCount: Int) -> [NSImage] {
    var result: [NSImage] = []
    let step = Double(frames.count - 1) / Double(targetCount - 1)

    for i in 0..<targetCount {
        let index = Int(round(Double(i) * step))
        result.append(frames[index])
    }
    return result
}
```

保持首尾帧，中间均匀采样，确保动画流畅性。

#### 时长保持原则

抽帧后的动画播放速度与原始动画保持一致：
- **总时长不变**，帧数减少 → 每帧显示时间延长
- 公式：`新帧时长 = 原帧时长 × (原帧数 / 新帧数)`

## 外部依赖

- **Swift ArgumentParser**（Swift Package）- CLI 工具的命令行参数解析
- 无其他外部框架 - Sparkle 已在 v1.0.0 中移除，GBCli 已在 2026-03 迁移中移除

## 特殊光标处理

在较新的 macOS 版本上，Arrow 光标有同义词：
- `com.apple.coregraphics.Arrow`
- `com.apple.coregraphics.ArrowCtx`

IBeam（文本光标）也有替代名称。主程序的内嵌会话监听器会处理这些变体。

## 光标验证与限制

### 图像尺寸限制

**标准光标尺寸：** 64×64 像素（1x 分辨率）

所有导入的光标图像会自动缩放到 64×64 像素：
- **大于 64×64（最大 512×512）：** 自动缩小
- **小于 64×64：** 自动放大（可能降低质量）
- **使用 "aspect fit" 缩放：** 保持宽高比，居中并填充透明边距

**最大导入尺寸：** 512×512 像素

超过此尺寸的图像会被拒绝导入，抛出 `imageTooLarge` 错误：
- **验证位置：** [WindowsCursorConverter.swift:231](Mousecape/Mousecape/SwiftUI/Utilities/WindowsCursorConverter.swift#L231)
- **错误消息：** "Image too large (width×height). Maximum supported size is 512x512 pixels."

**缩放函数：**
- `AppState.swift:984` - `scaleImageToStandardSize(_:)` - 静态图像缩放
- `EditOverlayView.swift:1303` - `scaleImageToStandardSize(_:)` - 静态图像缩放
- `EditOverlayView.swift:1229` - `scaleGIFSpriteSheet(_:)` - GIF 动画缩放
- `AppState.swift:1041` / `EditOverlayView.swift:1458` - `scaleWindowsSpriteSheet(_:)` - Windows 动画缩放

**逻辑尺寸：** 32×32 points
- 在 2x HiDPI 显示器上等于 64×64 像素
- 定义位置：[EditOverlayView.swift:1420](Mousecape/Mousecape/SwiftUI/Views/EditOverlayView.swift#L1420)

### 热点坐标验证

**统一常量：** `MCMaxHotspotValue = 31.99` ([MCDefs.h:54](Mousecape/mousecloak/MCDefs.h#L54), [MCDefs.m:28](Mousecape/mousecloak/MCDefs.m#L28))

热点坐标必须在有效范围内以防止 `CGError=1000`：
- **有效范围：** `0 ≤ hotspot ≤ 31.99`
- **验证位置：**
  - `apply.m:44-60` - 注册光标时验证并钳制
  - `EditOverlayView.swift:556-562` - UI 输入验证
  - `EditOverlayView.swift:1410-1414` - Windows 光标导入时验证

**跨语言一致性：**
- Objective-C 和 Swift 代码使用同一常量
- 通过 bridging header 共享定义
- 确保所有验证逻辑统一

### 动画帧数限制

**系统限制：** 最大 24 帧

超过 24 帧的动画会自动降采样：
- **GIF 导入：** ([EditOverlayView.swift:1106-1116](Mousecape/Mousecape/SwiftUI/Views/EditOverlayView.swift#L1106-L1116))
- **ANI 导入：** ([WindowsCursorConverter.swift:167-193](Mousecape/Mousecape/SwiftUI/Utilities/WindowsCursorConverter.swift#L167-L193))
- **Cape 验证：** ([MCCursorLibrary.m](Mousecape/Mousecape/src/models/MCCursorLibrary.m))

降采样时保持动画速度一致，调整帧时长补偿帧数减少。

**内存保护措施：**
- 导入前验证图像尺寸
- 超过限制时抛出 `imageTooLarge` 错误
- 使用 `autoreleasepool` 处理大型动画帧
- 防止内存溢出导致崩溃

### 错误处理

**GIF 帧解码失败处理：** ([EditOverlayView.swift:1071-1125](Mousecape/Mousecape/SwiftUI/Views/EditOverlayView.swift#L1071-L1125))
- 统计失败帧数和失败率
- 失败率 > 20% 时通过 `appState.showImageImportWarning` 显示 SwiftUI alert
- 调试日志记录每个失败的帧
- 支持中英文本地化错误消息

### 撤销/重做系统

**配对闭包架构：** undo 和 redo 闭包配对存储为元组 `(undo: () -> Void, redo: () -> Void)`。

```swift
private var undoStack: [(undo: () -> Void, redo: () -> Void)] = []
private var redoStack: [(undo: () -> Void, redo: () -> Void)] = []
```

- `registerUndo` 将 undo/redo 闭包配对压入 undoStack，同时清空 redoStack
- `undo()` 从 undoStack 弹出条目，执行 undo 闭包，整个条目压入 redoStack
- `redo()` 从 redoStack 弹出条目，执行 redo 闭包，整个条目压回 undoStack
- 最大历史记录：20 步（`maxUndoHistory`）
- `hasUnsavedChanges` 仅在 `registerUndo` 和 `markAsChanged` 时设为 true，undo 不会自动重置

### AnimatingCursorView 帧缓存

**架构：** 使用 `@State private var cachedFrames: [NSImage]` 预缓存所有帧，避免每次 Timer 触发时重新裁剪。

```swift
private func buildFrameCache() {
    // 使用 CGImage.cropping(to:) 裁剪 sprite sheet
    // 注意：NSImage(cgImage:size:) 的 size 参数必须使用 NSImage 逻辑尺寸（points），不能使用 CGImage 像素尺寸
    let logicalWidth = image.size.width
    let logicalFrameHeight = image.size.height / CGFloat(frameCount)
    let nsImage = NSImage(cgImage: croppedCG, size: NSSize(width: logicalWidth, height: logicalFrameHeight))
}
```

**关键注意事项：** NSImage logical size（points）vs CGImage pixel dimensions — HiDPI 下 CGImage 像素是 NSImage 逻辑尺寸的 2 倍，必须使用 `image.size`（逻辑尺寸）传给 `NSImage(cgImage:size:)`，否则预览图会显示为 2 倍大小。

**缓存重建触发：** `.onAppear`、`cursor.frameCount` 变化、`cursor.id` 变化、`refreshTrigger` 变化。

### 图像处理异步化

**架构：** EditOverlayView 中的图像导入使用 `Task {}` + 文件级 `nonisolated` async 辅助函数，将耗时的图像解码/缩放移到后台。

**Sendable 结果类型：**
- `StaticImageResult` — 静态图像处理结果
- `GIFProcessingResult` — GIF 处理结果（帧、时长、警告信息）
- `WindowsCursorProcessingResult` — Windows 光标处理结果

**加载状态：** `@State private var isLoadingImage` 控制 ProgressView 加载指示器显示，处理期间禁用拖放。

**线程安全：** `CursorImageScaler.createSpriteSheet` 使用 CGContext（非 NSGraphicsContext），可安全在非主线程调用。

### 二进制解析安全防护

**WindowsCursorParser.swift 安全验证：**
- **BMP 宽高上限：** `actualWidth/actualHeight <= CursorImageScaler.maxImportSize (512)`，防止恶意文件声明超大尺寸导致 OOM
- **ANI chunkSize 验证：** `guard chunkSize > 0`，防止 chunkSize=0 导致无限循环
- **CUR imageOffset 边界检查：** `guard imageOffset + imageSize <= data.count`，使用安全比较避免整数溢出
- **拖放 URL scheme 验证：** `guard url.isFileURL`，拒绝非 file:// URL

### 可访问性（Accessibility）

编辑页面已添加 VoiceOver 支持：
- `AnimatingCursorView` — accessibilityLabel + accessibilityValue（帧数/静态）
- `HotspotIndicator` — accessibilityLabel + accessibilityValue（X/Y 坐标）
- `CursorPreviewDropZone` — accessibilityLabel + accessibilityHint + accessibilityValue
- 工具栏按钮、TextField、AddCursorSheet 列表行 — accessibilityLabel

## 日志系统

项目包含完整的调试日志系统，仅在 DEBUG 构建中激活。

### 日志文件位置

```
~/Library/Logs/Mousecape/
├── mousecape_gui_YYYY-MM-DD_HH-MM-SS.log    # SwiftUI GUI 日志
└── mousecloak_YYYY-MM-DD_HH-MM-SS.log       # CLI 工具日志
```

日志文件自动清理：保留最近 24 小时的日志，总大小限制 100MB。

**清理策略：** ([DebugLogger.swift:230-283](Mousecape/Mousecape/SwiftUI/Utilities/DebugLogger.swift#L230-L283))
1. **阶段一：** 删除 24 小时以上的日志文件
2. **阶段二：** 如果总大小超过 100MB，删除最旧的文件直到符合限制
3. 始终保留最新的日志文件

### 查看日志

```bash
# 查看最近 2 分钟的系统日志
log show --predicate 'process contains "mousecloak"' --last 2m

# 查看日志文件
ls -la ~/Library/Logs/Mousecape/
cat ~/Library/Logs/Mousecape/mousecloak_*.log
```

### Objective-C 日志（mousecloak/）

**核心文件：**
- `MCLogger.h` / `MCLogger.m` - 日志系统实现
- `MCDefs.h` - 定义 `MMLog()` 宏

**API：**
```objc
MCLoggerInit();                    // 初始化日志系统，创建日志文件
MCLoggerWrite("format %s", arg);   // 写入日志（同时输出到 stdout 和文件）
MCLoggerGetLogPath();              // 获取当前日志文件路径
MCLoggerClose();                   // 关闭日志文件

// 便捷宏
MMLog("message");                  // 自动换行的日志输出
MMOut("format", arg);              // 不换行的输出（用于进度显示）
```

**颜色输出（用于终端）：**
```objc
MMLog(GREEN "成功" RESET);
MMLog(RED "错误" RESET);
MMLog(YELLOW "警告" RESET);
// 可用颜色：RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, BOLD, RESET
```

**在 Release 构建中：**
- `MCLoggerInit/Write/Close` 变为空操作
- `MMLog/MMOut` 仅输出到 stdout，不写文件

### Swift 日志（SwiftUI/Utilities/）

**核心文件：** `DebugLogger.swift`

**API：**
```swift
// 全局便捷函数
debugLog("消息")                    // 记录调试信息（仅 DEBUG 有效）

// 单例访问
DebugLogger.shared.log("消息")     // 直接调用
DebugLogger.getAllLogFiles()       // 获取所有日志文件
DebugLogger.exportLogsAsZip()      // 导出日志为 zip（用于问题报告）
DebugLogger.getTotalLogSize()      // 获取日志总大小
DebugLogger.clearAllLogs()         // 清除所有日志
```

**日志格式：**
```
[HH:mm:ss.SSS] [FileName.swift:42] 消息内容
```

### 日志头信息

每个日志文件开头自动记录：
- 时间、macOS 版本、用户名、进程信息
- 用户偏好设置（MCAppliedCursor、MCCursorScale 等）

### 构建变体

- **Debug** / **Debug-Dev**：启用完整日志，写入文件
- **Release** / **Release-Dev**：禁用文件日志，仅 stdout 输出

## CI/CD

项目使用 GitHub Actions 进行持续集成，配置文件位于 `.github/workflows/`。

## 版本号修改

修改版本号时需要更新以下位置：

1. **Xcode 项目配置**（主要位置，其他文件引用此值）
   - `Mousecape/Mousecape.xcodeproj/project.pbxproj`
   - 搜索 `MARKETING_VERSION`，共 4 处（Debug、Debug-Dev、Release、Release-Dev）

2. **主应用 Info.plist**
   - `Mousecape/Mousecape/Mousecape-Info.plist`
   - `CFBundleShortVersionString` 已设为 `$(MARKETING_VERSION)`，自动引用 Xcode 配置

3. **设置页面 fallback 版本号**
   - `Mousecape/Mousecape/SwiftUI/Views/SettingsView.swift`
   - 搜索 `Mousecape v`，修改 else 分支中的备用版本号
