# Mousecape GUI 功能测试报告

**测试日期：** 2026-03-02
**测试类型：** 代码审查 + 静态分析
**测试范围：** ObjC 到 Swift 迁移后的 GUI 核心功能
**Git Commit：** a4187fb (Fix Simple mode and remove context menu in Advanced mode)

---

## 执行摘要

本次测试通过代码审查和静态分析的方式，对 Mousecape GUI 应用的核心功能进行了全面评估。测试重点关注 ObjC 到 Swift 迁移（方案 B）后的功能完整性、数据流正确性和潜在风险点。

**总体评估：** ✅ **通过 - 可以进行人工测试**

- 核心功能代码逻辑正确
- Swift/ObjC 桥接层设计合理
- 序列化/反序列化实现完整
- 发现 3 个需要人工验证的边界条件
- 发现 1 个性能优化建议

---

## 1. 文件操作测试

### 1.1 打开 .cape 文件

**测试目标：** 验证 `CursorLibrary.init(dictionary:)` 和 `Cursor.init(dictionary:version:)` 的反序列化功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `CursorLibrary.swift:218-266` - 从字典初始化 CursorLibrary
- `Cursor.swift:169-211` - 从字典初始化 Cursor
- `AppState.swift:340-363` - 导入 Cape 文件的入口

**验证点：**
1. ✅ 版本兼容性检查 (`minimumVersion <= 2.0`)
2. ✅ 必需字段验证 (CapeName, Author, Identifier, CapeVersion, Cursors)
3. ✅ 可选字段处理 (HiDPI, Cloud)
4. ✅ 光标字典解析 (`Cursor.init(dictionary:version:)`)
5. ✅ TIFF 图像数据解析 (`NSBitmapImageRep(data:)`)
6. ✅ 颜色空间重标记 (`retaggedSRGBSpace()`)
7. ✅ 逻辑尺寸设置 (points vs pixels)

**发现的问题：** 无

**需要人工验证：**
- [ ] 打开包含损坏 TIFF 数据的 .cape 文件
- [ ] 打开 Version < 2.0 的旧版本文件
- [ ] 打开包含超大图像（>512×512）的文件

---

### 1.2 保存 .cape 文件

**测试目标：** 验证 `CursorLibrary.write(to:)` 和 `toDictionary()` 的序列化功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `CursorLibrary.swift:308-351` - 序列化为字典并写入文件
- `Cursor.swift:249-273` - 光标序列化为字典
- `AppState.swift:674-722` - 保存 Cape 的入口

**验证点：**
1. ✅ 版本信息正确 (`MinimumVersion: 2.0`, `Version: 2.0`)
2. ✅ 元数据完整 (CapeName, Author, Identifier, CapeVersion, HiDPI, Cloud)
3. ✅ 光标字典结构正确 (FrameCount, FrameDuration, HotSpotX/Y, PointsWide/High)
4. ✅ 图像数据使用 TIFF + LZW 压缩
5. ✅ 文件名冲突检测 (`isIdentifierExists`)
6. ✅ 原子写入 (`atomically: true`)

**发现的问题：** 无

**需要人工验证：**
- [ ] 保存后重新打开，验证数据完整性
- [ ] 检查文件格式 (`file` 命令应显示 "Apple binary property list")
- [ ] 验证文件大小合理（无异常增大）

---

### 1.3 导出光标图像

**测试目标：** 验证 `Cursor.imageData(for:)` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `Cursor.swift:290-300` - 导出 TIFF 数据
- `AppState.swift:731-771` - 导出 Cape 文件

**验证点：**
1. ✅ 获取指定缩放比例的图像表示
2. ✅ 转换为 TIFF 格式（LZW 压缩）
3. ✅ 验证 Cape 有效性 (`validateCape()`)
4. ✅ 错误处理完整

**发现的问题：** 无

---

### 1.4 文件格式验证

**测试目标：** 验证 `CursorLibrary.validate()` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `CursorLibrary.swift:379-446` - 验证 Cape 兼容性
- `MCCursorLibrary.m:validateCape` - ObjC 层验证

**验证点：**
1. ✅ 帧数限制检查 (`frameCount <= 24`)
2. ✅ 热点边界检查 (`0 <= hotspot <= 31.99`)
3. ✅ 图像尺寸检查 (`width/height <= 512`)
4. ✅ 多错误聚合 (`ValidationError.multipleErrors`)
5. ✅ 本地化错误消息

**发现的问题：** 无

**需要人工验证：**
- [ ] 导入超过 24 帧的动画光标
- [ ] 导入热点超出范围的光标
- [ ] 导入超大图像（>512×512）

---

## 2. 光标编辑测试

### 2.1 添加新光标

**测试目标：** 验证 `Cursor.init(identifier:)` 和 `CursorLibrary.addCursor(_:)` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `Cursor.swift:154-162` - 创建空光标
- `CursorLibrary.swift:101-104` - 添加光标到库
- `AppState.swift:846-853` - 添加光标的入口

**验证点：**
1. ✅ 默认属性设置 (frameCount=1, frameDuration=1.0, size=32×32, hotSpot=0,0)
2. ✅ 光标缓存失效 (`_cursors = nil`)
3. ✅ 标记为已修改 (`markAsChanged()`)
4. ✅ 刷新触发器更新 (`cursorListRefreshTrigger += 1`)

**发现的问题：** 无

---

### 2.2 删除光标

**测试目标：** 验证 `CursorLibrary.removeCursor(_:)` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `CursorLibrary.swift:106-109` - 从库中移除光标
- `AppState.swift:829-843` - 删除光标的入口

**验证点：**
1. ✅ ObjC 层调用 (`objcLibrary.removeCursor`)
2. ✅ 光标缓存失效
3. ✅ 简易模式下删除整个分组 (`removeGroupCursors`)
4. ✅ 清空选中状态

**发现的问题：** 无

---

### 2.3 修改光标属性

**测试目标：** 验证光标属性的 getter/setter 桥接

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `Cursor.swift:22-76` - 属性桥接到 ObjC
- `EditOverlayView.swift` - UI 绑定

**验证点：**
1. ✅ 名称、热点、帧率、帧数的 getter/setter
2. ✅ 属性变化时的缓存失效
3. ✅ 简易模式下的别名同步 (`syncMetadataToAliases`)
4. ✅ Undo/Redo 支持

**发现的问题：** 无

---

### 2.4 设置光标图像

**测试目标：** 验证 `Cursor.setImageData(_:for:)` 和 `setRepresentation(_:for:)` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `Cursor.swift:277-288` - 设置图像数据
- `Cursor.swift:108-114` - 设置图像表示
- `EditOverlayView.swift:1021-1458` - 图像导入逻辑

**验证点：**
1. ✅ TIFF/PNG 数据解析 (`NSBitmapImageRep(data:)`)
2. ✅ 逻辑尺寸设置 (points, not pixels)
3. ✅ 图像缓存失效 (`invalidateImageCache()`)
4. ✅ 异步图像处理 (`Task {}` + `nonisolated` 函数)
5. ✅ GIF 动画帧解码 (`CGImageSourceCreateImageAtIndex`)
6. ✅ Windows 光标解析 (`WindowsCursorParser`)
7. ✅ 图像缩放到标准尺寸 (64×64)
8. ✅ 帧数限制处理 (>24 帧自动降采样)

**发现的问题：** 无

**需要人工验证：**
- [ ] 导入 PNG、TIFF、GIF、.cur、.ani 格式
- [ ] 导入不同分辨率的图像
- [ ] 导入超过 24 帧的动画
- [ ] 验证图像缩放质量

---

## 3. 简易/高级模式测试

### 3.1 模式切换

**测试目标：** 验证 Simple/Advanced 模式切换逻辑

**代码审查结果：** ✅ **通过 (最近修复)**

**关键代码路径：**
- `EditOverlayView.swift:49-95` - 模式切换工具栏
- `EditOverlayView.swift:142-234` - 光标列表（双模式）
- `AddCursorSheet.swift` - 添加光标弹窗（双模式）

**验证点：**
1. ✅ 模式切换时清空选中状态
2. ✅ 模式切换时关闭 info 面板
3. ✅ 简易模式显示 15 个 Windows 分组
4. ✅ 高级模式显示完整 52 个 macOS 光标类型
5. ✅ 模式持久化 (`@AppStorage("cursorEditMode")`)

**最近修复 (commit a4187fb):**
- ✅ 修复了简易模式下选择分组不显示编辑页面的问题
- ✅ 移除了高级模式下的右键菜单

**发现的问题：** 无

---

### 3.2 别名同步

**测试目标：** 验证简易模式下的 Auto-Alias 机制

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `CursorLibrary.swift:115-159` - 别名同步函数
- `Cursor.swift:215-245` - 光标复制函数
- `EditOverlayView.swift` - 同步触发点

**验证点：**
1. ✅ 完整同步 (`syncCursorToAliases`) - 图像导入时
2. ✅ 元数据同步 (`syncMetadataToAliases`) - 参数修改时
3. ✅ 添加时自动创建别名 (`addCursorWithAliases`)
4. ✅ 删除时删除整个分组 (`removeGroupCursors`)
5. ✅ Undo/Redo 包含别名同步

**发现的问题：** 无

**需要人工验证：**
- [ ] 简易模式下修改热点，验证同组别名同步
- [ ] 简易模式下导入图像，验证同组别名同步
- [ ] 简易模式下删除光标，验证整个分组被删除

---

### 3.3 别名一致性检查

**测试目标：** 验证首次编辑分组时的一致性检查

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `EditOverlayView.swift:1530-1598` - 一致性检查逻辑

**验证点：**
1. ✅ 检查同组光标的 hotspot/frameCount/frameDuration 是否一致
2. ✅ 发现差异时弹出确认弹窗
3. ✅ Cancel 时清空选中状态
4. ✅ Continue 时继续编辑

**发现的问题：** 无

---

## 4. 应用/重置测试

### 4.1 应用光标主题

**测试目标：** 验证 `AppState.applyCape(_:)` 与 ObjC 桥接

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `AppState.swift:372-398` - 应用 Cape
- `MCLibraryController.m:applyCape:` - ObjC 层应用逻辑
- `apply.m` - 私有 API 调用

**验证点：**
1. ✅ 调用 ObjC 层 (`libraryController?.applyCape`)
2. ✅ 更新 appliedCape 状态
3. ✅ 保存到 UserDefaults (`lastAppliedCapeIdentifier`)
4. ✅ 写入 CFPreferences (`MCAppliedCursor`)
5. ✅ 同步偏好设置 (`CFPreferencesSynchronize`)
6. ✅ 调试日志记录

**发现的问题：** 无

---

### 4.2 重置为默认

**测试目标：** 验证 `AppState.resetToDefault()` 功能

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `AppState.swift:401-424` - 重置为默认
- `MCLibraryController.m:restoreCape` - ObjC 层重置逻辑
- `restore.m` - 私有 API 调用

**验证点：**
1. ✅ 调用 ObjC 层 (`libraryController?.restoreCape`)
2. ✅ 清空 appliedCape 状态
3. ✅ 清除 UserDefaults (`lastAppliedCapeIdentifier`)
4. ✅ 清除 CFPreferences (`MCAppliedCursor`)
5. ✅ 调试日志记录

**发现的问题：** 无

---

## 5. 窗口生命周期测试

### 5.1 内存优化

**测试目标：** 验证隐藏到菜单栏时的内存释放

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `AppState.swift:482-572` - 清除内存缓存
- `MousecapeApp.swift` - 窗口生命周期管理

**验证点：**
1. ✅ 清除所有光标图像缓存
2. ✅ 清除 capes 数组
3. ✅ 清除编辑状态
4. ✅ 清除对话框状态
5. ✅ 清除 Undo/Redo 历史
6. ✅ 释放 libraryController (关键！)
7. ✅ 创建轻量级 appliedCape 用于菜单栏显示
8. ✅ 多次 autoreleasepool 强制清理
9. ✅ 内存使用报告

**发现的问题：** 无

**需要人工验证：**
- [ ] 打开大型 Cape 文件，记录内存使用
- [ ] 隐藏到菜单栏，等待 5 秒
- [ ] 验证内存释放约 27+ MB
- [ ] 重新打开窗口，验证数据正确恢复

---

### 5.2 状态恢复

**测试目标：** 验证窗口重新打开时的状态恢复

**代码审查结果：** ✅ **通过**

**关键代码路径：**
- `AppState.swift:590-615` - 恢复状态

**验证点：**
1. ✅ 重新创建 libraryController
2. ✅ 重新加载 capes
3. ✅ 恢复选中状态 (`lastSelectedCapeIdentifier`)
4. ✅ 恢复应用状态 (`lastAppliedCapeIdentifier`)
5. ✅ 清除临时 UserDefaults

**发现的问题：** 无

---

## 6. 线程安全测试

### 6.1 @MainActor 使用

**代码审查结果：** ✅ **通过**

**验证点：**
1. ✅ AppState 标记为 `@MainActor`
2. ✅ 所有 UI 状态更新在主线程
3. ✅ 图像处理使用异步任务 (`Task {}`)
4. ✅ 文件级 `nonisolated` 函数用于后台处理

**发现的问题：** 无

---

### 6.2 ObjC 桥接线程安全

**代码审查结果：** ⚠️ **需要人工验证**

**潜在风险：**
- ObjC 对象 (MCCursor, MCCursorLibrary) 不是线程安全的
- Swift 包装器通过 `@MainActor` 保护
- 需要验证并发访问时的行为

**需要人工验证：**
- [ ] 快速切换不同 Cape 文件
- [ ] 在保存过程中关闭窗口
- [ ] 同时打开多个 Cape 文件

---

## 7. 发现的问题汇总

### 7.1 需要人工验证的边界条件

| 编号 | 严重程度 | 问题描述 | 测试方法 |
|------|----------|----------|----------|
| 1 | 🟢 Minor | 损坏的 TIFF 数据处理 | 创建包含损坏 TIFF 的 .cape 文件并尝试打开 |
| 2 | 🟢 Minor | 旧版本文件兼容性 | 打开 Version < 2.0 的 .cape 文件 |
| 3 | 🟡 Major | 并发访问 ObjC 对象 | 快速切换文件、保存时关闭窗口 |

---

### 7.2 性能优化建议

| 编号 | 优先级 | 建议 | 预期收益 |
|------|--------|------|----------|
| 1 | Low | 考虑使用 `NSCache` 替代手动缓存管理 | 更好的内存压力响应 |

---

## 8. 代码质量评估

### 8.1 优点

1. ✅ **清晰的架构分层**
   - Swift 包装器层 (Cursor.swift, CursorLibrary.swift)
   - ObjC 模型层 (MCCursor, MCCursorLibrary)
   - 私有 API 层 (mousecloak/)

2. ✅ **完整的错误处理**
   - 验证错误 (`ValidationError`)
   - 文件操作错误
   - 用户友好的错误消息

3. ✅ **良好的内存管理**
   - 缓存失效机制
   - 内存优化策略
   - Autoreleasepool 使用

4. ✅ **类型安全**
   - Swift 类型系统
   - 枚举替代魔法数字
   - Optional 处理

5. ✅ **可维护性**
   - 清晰的注释
   - 一致的命名
   - 模块化设计

---

### 8.2 改进建议

1. **添加单元测试**
   - 序列化/反序列化测试
   - 验证逻辑测试
   - 边界条件测试

2. **添加集成测试**
   - 文件操作端到端测试
   - 应用/重置流程测试

3. **性能测试**
   - 大型文件加载性能
   - 内存使用基准测试

---

## 9. 测试结论

### 9.1 总体评估

✅ **通过 - 可以进行人工测试**

代码审查显示所有核心功能的逻辑正确，Swift/ObjC 桥接层设计合理，序列化/反序列化实现完整。发现的 3 个边界条件需要人工验证，但不影响正常使用场景。

---

### 9.2 建议的人工测试优先级

**高优先级（必须测试）：**
1. 打开/保存 .cape 文件
2. 应用/重置光标主题
3. 简易/高级模式切换
4. 内存优化验证

**中优先级（建议测试）：**
1. 导入各种格式的图像
2. 别名同步功能
3. Undo/Redo 功能

**低优先级（可选测试）：**
1. 边界条件（损坏文件、旧版本文件）
2. 并发访问测试
3. 性能基准测试

---

### 9.3 风险评估

**低风险：**
- 核心功能代码逻辑正确
- ObjC 层保持不变，风险可控
- 已有的功能测试覆盖

**中风险：**
- 并发访问 ObjC 对象（需要人工验证）
- 边界条件处理（需要人工验证）

**高风险：**
- 无

---

## 10. 下一步行动

1. ✅ 完成代码审查（本报告）
2. ⏭️ 执行人工测试（参考 `MANUAL_TESTING_CHECKLIST.md`）
3. ⏭️ 修复发现的问题（如果有）
4. ⏭️ 添加单元测试和集成测试
5. ⏭️ 性能基准测试

---

**测试人员：** ui-tester (Claude Opus 4.6)
**测试完成时间：** 2026-03-02
**签名：** ✅ 代码审查通过，建议进行人工测试
