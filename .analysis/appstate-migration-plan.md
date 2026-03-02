# AppState ObjC 调用替换计划

## 任务概述
将 Swift 文件中的 ObjC 模型调用（MCCursor 和 MCCursorLibrary）替换为 Swift 包装器（Cursor 和 CursorLibrary）。

## 依赖状态
- ✅ Cursor.swift 包装器已完成（基础功能）
- ✅ CursorLibrary.swift 包装器已完成（基础功能）
- ⏳ 任务 #8：Cursor.swift 序列化功能（cursor-serializer 进行中）
- ⏳ 任务 #4：CursorLibrary.swift 序列化功能（library-serializer 进行中）

## 需要替换的文件和位置

### 1. WindowsCursorConverter.swift（优先级：高）

**位置：** Lines 301-316

**当前代码：**
```swift
/// Create MCCursor from the result
func createMCCursor(identifier: String) -> MCCursor? {
    guard let bitmap = createBitmapImageRep() else { return nil }

    let cursor = MCCursor()
    cursor.identifier = identifier
    cursor.frameCount = UInt(frameCount)
    cursor.frameDuration = frameDuration
    cursor.size = NSSize(width: CGFloat(width), height: CGFloat(height))
    cursor.hotSpot = NSPoint(x: CGFloat(hotspotX), y: CGFloat(hotspotY))

    // Set representation for 2x scale (standard HiDPI)
    cursor.setRepresentation(bitmap, for: MCCursorScale(rawValue: 200)!)

    return cursor
}
```

**替换为：**
```swift
/// Create Cursor from the result
func createCursor(identifier: String) -> Cursor? {
    guard let bitmap = createBitmapImageRep() else { return nil }

    let cursor = Cursor(identifier: identifier)
    cursor.frameCount = frameCount
    cursor.frameDuration = frameDuration
    cursor.size = NSSize(width: CGFloat(width), height: CGFloat(height))
    cursor.hotSpot = NSPoint(x: CGFloat(hotspotX), y: CGFloat(hotspotY))

    // Set representation for 2x scale (standard HiDPI)
    cursor.setRepresentation(bitmap, for: .scale200)

    return cursor
}
```

**影响范围：** 需要检查所有调用 `createMCCursor` 的地方并更新为 `createCursor`

---

### 2. AppState.swift（优先级：高）

#### 2.1 Line 155：加载 capes 时的类型转换

**当前代码：**
```swift
// Load capes from the ObjC controller
if let objcCapes = controller.capes as? Set<MCCursorLibrary> {
    capes = objcCapes.map { CursorLibrary(objcLibrary: $0) }
    applyCapeOrder()
}
```

**分析：** 这段代码已经在使用 CursorLibrary 包装器，只是在类型转换时引用了 MCCursorLibrary。这是合理的，因为 MCLibraryController 返回的是 ObjC 对象。

**结论：** 保持不变（这是包装器的正确用法）

---

#### 2.2 Line 550：创建轻量级 MCCursorLibrary

**当前代码：**
```swift
// Recreate a lightweight appliedCape for menu bar display (no cursor data)
if let appliedId = appliedIdentifier, let appliedName = appliedCapeName {
    // Create a minimal CursorLibrary with just metadata for menu bar display
    let lightweightLibrary = MCCursorLibrary(cursors: Set())
    lightweightLibrary.name = appliedName
    lightweightLibrary.identifier = appliedId
    appliedCape = CursorLibrary(objcLibrary: lightweightLibrary)
    debugLog("Recreated lightweight appliedCape for menu bar: \(appliedName)")
}
```

**替换为：**
```swift
// Recreate a lightweight appliedCape for menu bar display (no cursor data)
if let appliedId = appliedIdentifier, let appliedName = appliedCapeName {
    // Create a minimal CursorLibrary with just metadata for menu bar display
    let lightweightLibrary = CursorLibrary(name: appliedName, author: "")
    lightweightLibrary.identifier = appliedId
    appliedCape = lightweightLibrary
    debugLog("Recreated lightweight appliedCape for menu bar: \(appliedName)")
}
```

**注意：** 需要确保 CursorLibrary 的 `identifier` 属性是可写的（当前是通过 objcLibrary 桥接的）

---

### 3. 字符串常量（优先级：低）

以下文件中的 "MCCursorScale" 只是字符串常量，不是类型引用，无需修改：
- AppState.swift Line 233
- SettingsView.swift Line 70
- DebugLogger.swift Lines 102, 107, 109

这些是 UserDefaults/CFPreferences 的键名，保持不变以维持向后兼容性。

---

## 迁移步骤

### 阶段 1：准备工作（当前）
- [x] 审查所有 ObjC 调用点
- [x] 制定迁移计划
- [ ] 等待任务 #4 完成（CursorLibrary 序列化功能）

### 阶段 2：替换 WindowsCursorConverter.swift
1. 重命名 `createMCCursor` 为 `createCursor`
2. 修改返回类型为 `Cursor?`
3. 使用 `Cursor(identifier:)` 初始化
4. 使用 `CursorScale.scale200` 替代 `MCCursorScale(rawValue: 200)`
5. 查找所有调用点并更新

### 阶段 3：替换 AppState.swift
1. 修改 Line 550 的轻量级 library 创建逻辑
2. 确保 CursorLibrary.identifier 可写
3. 测试菜单栏显示功能

### 阶段 4：回归测试
1. 测试 Windows 光标导入功能
2. 测试 Cape 加载和保存
3. 测试菜单栏显示
4. 测试内存管理（clearMemoryCaches）
5. 测试编辑功能
6. 测试应用光标功能

### 阶段 5：清理和提交
1. 移除不必要的 import
2. 更新注释
3. 运行完整测试套件
4. 提交代码

---

## 风险评估

### 高风险区域
1. **WindowsCursorConverter.swift**
   - 影响 Windows 光标导入功能
   - 需要仔细测试所有导入场景（.cur, .ani, 文件夹导入）

2. **AppState.swift Line 550**
   - 影响菜单栏显示
   - 需要测试窗口隐藏/显示时的内存管理

### 低风险区域
1. **AppState.swift Line 155**
   - 已经在使用包装器，只是类型转换
   - 无需修改

2. **字符串常量**
   - 不涉及类型调用
   - 无需修改

---

## 测试清单

### 功能测试
- [ ] 导入 .cur 文件
- [ ] 导入 .ani 文件
- [ ] 导入 Windows 光标文件夹（带 .inf）
- [ ] 导入 Windows 光标文件夹（无 .inf）
- [ ] 创建新 Cape
- [ ] 编辑 Cape 元数据
- [ ] 添加光标到 Cape
- [ ] 删除光标
- [ ] 保存 Cape
- [ ] 导出 Cape
- [ ] 应用 Cape
- [ ] 重置光标
- [ ] 菜单栏显示当前应用的 Cape
- [ ] 窗口隐藏到菜单栏
- [ ] 从菜单栏恢复窗口

### 内存测试
- [ ] 窗口隐藏时内存释放
- [ ] 窗口恢复时状态恢复
- [ ] 大型 Cape 加载和卸载
- [ ] 多次导入和删除 Cape

### 边界测试
- [ ] 空 Cape
- [ ] 超大动画帧数（>24 帧）
- [ ] 超大图像尺寸（>512px）
- [ ] 无效热点坐标
- [ ] 损坏的 .cur/.ani 文件

---

## 完成标准

1. ✅ 所有 MCCursor 直接调用已替换为 Cursor
2. ✅ 所有 MCCursorLibrary 直接调用已替换为 CursorLibrary
3. ✅ 所有功能测试通过
4. ✅ 无崩溃和错误
5. ✅ 内存管理正常
6. ✅ 代码已提交到 git

---

## 备注

- Cursor.swift 和 CursorLibrary.swift 内部使用 ObjC 对象是正常的，它们是包装器
- MCLibraryController 仍然使用 ObjC，这是预期的（它管理底层 ObjC 对象）
- 字符串常量 "MCCursorScale" 保持不变以维持向后兼容性
