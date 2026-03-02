# ObjC 模型删除阻塞分析

**日期：** 2026-03-02
**分析人：** utils-migrator
**任务：** #9 - 删除 ObjC 模型文件
**状态：** 阻塞 - 无法安全删除

## 问题概述

任务 #9 要求删除 ObjC 模型文件（MCCursor、MCCursorLibrary、MCLibraryController），但检查发现 Swift 代码仍在大量使用这些 ObjC 类，**无法安全删除**。

## 详细依赖分析

### 1. AppState.swift 中的 ObjC 依赖

**文件：** `/Users/herryli/Documents/Mousecape/Mousecape/Mousecape/SwiftUI/Models/AppState.swift`

**使用情况：**
```swift
// 第 120 行
var libraryController: MCLibraryController?

// 第 144 行
libraryController = MCLibraryController(url: capesDir)

// 第 155 行
if let objcCapes = controller.capes as? Set<MCCursorLibrary>

// 第 233 行
let cursorScaleKey = "MCCursorScale"

// 第 503 行（注释）
// This releases all MCCursorLibrary and MCCursor objects and their image data

// 第 543 行（注释）
// This is the key to releasing the 27+ MB of CFData held by MCLibraryController
```

**影响：** AppState 完全依赖 MCLibraryController 来管理 Cape 文件。

### 2. Cursor.swift 中的 ObjC 依赖

**文件：** `/Users/herryli/Documents/Mousecape/Mousecape/Mousecape/SwiftUI/Models/Cursor.swift`

**使用情况：**
```swift
// 第 15 行 - 核心依赖
private let objcCursor: MCCursor

// 第 101-118 行 - 使用 MCCursorScale 枚举
guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else { ... }

// 第 148 行 - 从 ObjC 对象初始化
init(objcCursor: MCCursor)

// 第 155 行 - 创建 ObjC 对象
let cursor = MCCursor()

// 第 185 行 - 创建 ObjC 对象
let cursor = MCCursor()

// 第 200 行 - 使用 MCCursorScale
let mcScale = MCCursorScale(rawValue: UInt(scale * 100))

// 第 314 行 - 暴露底层 ObjC 对象
var underlyingCursor: MCCursor {
    return objcCursor
}
```

**影响：** Cursor.swift 只是 MCCursor 的包装器，不是独立的 Swift 实现。

### 3. CursorLibrary.swift 中的 ObjC 依赖

**文件：** `/Users/herryli/Documents/Mousecape/Mousecape/Mousecape/SwiftUI/Models/CursorLibrary.swift`

**使用情况：**
```swift
// 第 20 行 - 核心依赖
private let objcLibrary: MCCursorLibrary

// 第 78 行 - 访问 ObjC 对象
let objcCursors = objcLibrary.cursors as? Set<MCCursor> ?? []

// 第 121 行 - 查找 ObjC 对象
if let existing = objcLibrary.cursors.first(where: { ($0 as? MCCursor)?.identifier == cursorType.rawValue }) as? MCCursor

// 第 135 行 - 查找 ObjC 对象
if let existing = objcLibrary.cursors.first(where: { ($0 as? MCCursor)?.identifier == cursorType.rawValue }) as? MCCursor

// 第 181 行 - 从 ObjC 对象初始化
init(objcLibrary: MCCursorLibrary)

// 第 187 行 - 创建 ObjC 对象
let library = MCCursorLibrary(cursors: Set())

// 第 209 行 - 从文件加载 ObjC 对象
guard let library = MCCursorLibrary(contentsOf: url) else { ... }

// 第 241 行 - 创建 ObjC 对象
let library = MCCursorLibrary(cursors: Set())

// 第 271 行 - 暴露底层 ObjC 对象
var underlyingLibrary: MCCursorLibrary {
    return objcLibrary
}
```

**影响：** CursorLibrary.swift 只是 MCCursorLibrary 的包装器，不是独立的 Swift 实现。

## 根本原因分析

### 当前架构

```
SwiftUI Views
    ↓
AppState (@Observable)
    ↓
Cursor.swift / CursorLibrary.swift (包装器)
    ↓
MCCursor / MCCursorLibrary (ObjC 实现)
    ↓
MCLibraryController (ObjC 控制器)
```

### 问题

1. **Cursor.swift 和 CursorLibrary.swift 不是真正的 Swift 实现**
   - 它们只是薄包装器（thin wrappers）
   - 所有数据和逻辑仍在 ObjC 层
   - 删除 ObjC 文件会导致编译失败

2. **任务完成状态不准确**
   - 任务 #8（扩展 Cursor.swift）标记为 completed
   - 任务 #11（替换 AppState ObjC 调用）标记为 completed
   - 但实际上只是添加了包装器，没有真正迁移

3. **任务 #4 仍在进行中**
   - 扩展 CursorLibrary.swift 功能
   - 但如果只是包装器，无法真正替代 ObjC

## 需要完成的工作

要真正删除 ObjC 模型文件，需要：

### 1. 完整的 Swift 数据模型

**Cursor.swift 需要：**
- 移除 `private let objcCursor: MCCursor`
- 实现原生 Swift 数据存储（图像数据、热点、帧数等）
- 实现序列化/反序列化（不依赖 ObjC）
- 实现所有 MCCursor 的功能

**CursorLibrary.swift 需要：**
- 移除 `private let objcLibrary: MCCursorLibrary`
- 实现原生 Swift 数据存储（元数据、光标集合）
- 实现 Cape 文件读写（不依赖 ObjC）
- 实现所有 MCCursorLibrary 的功能

### 2. 替换 MCLibraryController

**AppState.swift 需要：**
- 移除 `var libraryController: MCLibraryController?`
- 直接使用 CursorLibrary.swift 管理 Cape 文件
- 实现 Cape 文件扫描和加载逻辑

### 3. 移除 MCCursorScale 依赖

**Cursor.swift 需要：**
- 定义 Swift 原生的 Scale 枚举
- 移除所有 `MCCursorScale` 引用

## 估算工作量

基于当前代码分析：

1. **完整实现 Cursor.swift**：2-3 天
   - 原生数据存储
   - 图像处理逻辑
   - 序列化/反序列化

2. **完整实现 CursorLibrary.swift**：2-3 天
   - 原生数据存储
   - Cape 文件读写
   - 验证逻辑

3. **重构 AppState.swift**：1-2 天
   - 移除 MCLibraryController
   - 实现 Cape 管理逻辑

4. **测试和调试**：1-2 天

**总计：6-10 天**

## 建议

### 选项 A：完成真正的 Swift 迁移（推荐）

1. 重新评估任务 #4、#8、#11 的完成状态
2. 分配足够的时间完成真正的 Swift 实现
3. 然后再执行任务 #9（删除 ObjC 文件）

**优点：**
- 真正的 Swift 原生实现
- 代码更清晰、更易维护
- 符合项目目标

**缺点：**
- 需要 6-10 天额外工作
- 风险较高（需要重写核心逻辑）

### 选项 B：保留 ObjC 模型（不推荐）

1. 标记任务 #9 为 "不需要"
2. 保留 MCCursor、MCCursorLibrary、MCLibraryController
3. Cursor.swift 和 CursorLibrary.swift 继续作为包装器

**优点：**
- 无需额外工作
- 风险低（当前代码工作正常）

**缺点：**
- 没有真正完成 Swift 迁移
- 代码库仍然混合 ObjC 和 Swift
- 不符合项目目标

### 选项 C：分阶段迁移

1. 先完成 Cursor.swift 的真正实现（2-3 天）
2. 再完成 CursorLibrary.swift 的真正实现（2-3 天）
3. 最后重构 AppState.swift（1-2 天）
4. 每个阶段都进行测试和验证

**优点：**
- 风险可控（分阶段验证）
- 可以随时回滚
- 符合项目目标

**缺点：**
- 总时间仍需 6-10 天
- 需要仔细规划每个阶段

## 结论

**当前无法安全删除 ObjC 模型文件。** 需要先完成真正的 Swift 实现，才能执行任务 #9。

建议采用**选项 C（分阶段迁移）**，这样可以在保证质量的同时，逐步完成 Swift 迁移。

## 下一步行动

等待 team-lead 决策：
1. 是否继续完成真正的 Swift 迁移？
2. 如果是，采用哪种方案（A/B/C）？
3. 如果不是，任务 #9 应该如何处理？
