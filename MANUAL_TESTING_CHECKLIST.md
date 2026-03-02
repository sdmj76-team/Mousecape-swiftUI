# Mousecape ObjC 到 Swift 迁移 - 人工测试清单

**测试日期：** _____________
**测试人员：** _____________
**构建版本：** Git commit `ed7aec8`

---

## 📋 测试前准备

### 1. Xcode 配置（必须完成）

- [ ] 打开 `Mousecape.xcodeproj` 在 Xcode 中
- [ ] 选择 **mousecloak** target
- [ ] **General** → **Frameworks, Libraries, and Embedded Content**
- [ ] 确认 ArgumentParser 已添加（如未添加，点击 + 添加）
- [ ] File → Packages → Resolve Package Versions
- [ ] 清理构建（Cmd+Shift+K）
- [ ] 构建项目（Cmd+B）
- [ ] ✅ 确认 BUILD SUCCEEDED

### 2. 备份当前数据

- [ ] 备份 `~/Library/Application Support/Mousecape/` 目录
- [ ] 备份现有的 .cape 文件
- [ ] 记录当前应用的光标主题

---

## 🎯 核心功能测试

### A. GUI 应用测试（Mousecape.app）

#### A1. 启动和基本界面

- [ ] 启动 Mousecape.app
- [ ] 应用正常启动，无崩溃
- [ ] 主窗口正常显示
- [ ] 菜单栏图标正常显示
- [ ] 切换 Simple/Advanced 编辑模式正常

#### A2. 打开 .cape 文件（测试 Cursor.swift 反序列化）

**测试目标：** 验证 `Cursor.swift` 的 `init(dictionary:version:)` 功能

- [ ] 从 Finder 双击打开一个 .cape 文件
- [ ] 文件成功加载，无错误提示
- [ ] 所有光标类型正确显示在列表中
- [ ] 光标预览图像正确显示
- [ ] 光标属性正确显示（帧数、热点、尺寸）
- [ ] 检查控制台无错误日志

**测试用例：**
- [ ] 打开标准 .cape 文件（Version 2.0）
- [ ] 打开包含多帧动画的 .cape 文件
- [ ] 打开包含 HiDPI 图像的 .cape 文件
- [ ] 打开旧版本 .cape 文件（如果有）

#### A3. 编辑光标（测试 Cursor.swift 数据操作）

**测试目标：** 验证 `Cursor.swift` 的 `setImageData(_:for:)` 功能

- [ ] 选择一个光标类型
- [ ] 点击 "Add Cursor" 添加新光标
- [ ] 从文件选择器导入图像
- [ ] 图像成功加载并显示
- [ ] 调整热点位置
- [ ] 热点位置正确保存
- [ ] 删除光标功能正常
- [ ] 替换光标图像功能正常

**测试用例：**
- [ ] 导入 PNG 图像
- [ ] 导入 TIFF 图像
- [ ] 导入多帧动画图像
- [ ] 导入不同分辨率的图像（@1x, @2x）

#### A4. 保存 .cape 文件（测试 CursorLibrary.swift 序列化）

**测试目标：** 验证 `CursorLibrary.swift` 的 `write(to:)` 和 `toDictionary()` 功能

- [ ] 修改光标后点击 "Save"
- [ ] 文件成功保存，无错误提示
- [ ] 关闭并重新打开保存的文件
- [ ] 所有修改正确保存
- [ ] 文件格式正确（二进制 plist）
- [ ] 文件大小合理（无异常增大）

**验证文件格式：**
```bash
# 检查文件格式
file ~/path/to/saved.cape
# 应该显示: Apple binary property list

# 转换为 XML 查看内容
plutil -convert xml1 -o - ~/path/to/saved.cape | head -50
# 检查关键字段：Version, MinimumVersion, CapeName, Cursors
```

**测试用例：**
- [ ] 保存新创建的 .cape 文件
- [ ] 保存修改后的现有 .cape 文件
- [ ] 另存为新文件名
- [ ] 保存包含多个光标的 .cape 文件

#### A5. 应用光标主题

**测试目标：** 验证 AppState 与 CursorLibrary 的集成

- [ ] 选择一个 .cape 文件
- [ ] 点击 "Apply" 应用光标主题
- [ ] 系统光标成功改变
- [ ] 所有光标类型正确应用（箭头、文本、手型等）
- [ ] 动画光标正常播放
- [ ] HiDPI 显示器上光标清晰

**测试用例：**
- [ ] 应用标准光标主题
- [ ] 应用动画光标主题
- [ ] 应用自定义光标主题
- [ ] 切换不同主题
- [ ] 恢复默认光标（Reset）

#### A6. 内存管理测试

**测试目标：** 验证隐藏到菜单栏时的内存优化

- [ ] 打开一个大型 .cape 文件（多个高分辨率光标）
- [ ] 记录内存使用（Activity Monitor）
- [ ] 关闭主窗口（隐藏到菜单栏）
- [ ] 等待 5 秒
- [ ] 检查内存使用是否显著降低
- [ ] 从菜单栏重新打开窗口
- [ ] 所有数据正确恢复

**预期结果：**
- 隐藏到菜单栏后，内存应该释放约 27+ MB（CFData）
- 重新打开后，数据应该正确重新加载

---

### B. CLI 工具测试（mousecloak）

**测试目标：** 验证 Swift ArgumentParser 替换 GBCli 的功能

#### B1. 基本命令测试

```bash
# 构建 mousecloak CLI
cd /Users/herryli/Documents/Mousecape/Mousecape
xcodebuild -project Mousecape.xcodeproj -target mousecloak -configuration Debug

# 找到构建产物
MOUSECLOAK="./build/Debug/mousecloak"
```

- [ ] `$MOUSECLOAK --help` - 显示帮助信息
- [ ] `$MOUSECLOAK --version` - 显示版本信息
- [ ] 所有子命令列出：apply, reset, create, dump, convert, export, scale, listen

#### B2. Apply 命令

```bash
$MOUSECLOAK apply ~/path/to/test.cape
```

- [ ] 成功应用光标主题
- [ ] 系统光标改变
- [ ] 无错误输出

#### B3. Reset 命令

```bash
$MOUSECLOAK reset
```

- [ ] 成功恢复默认光标
- [ ] 系统光标恢复正常
- [ ] 无错误输出

#### B4. Create 命令

```bash
$MOUSECLOAK create --name "Test Cape" --author "Tester" --output ~/test-new.cape
```

- [ ] 成功创建新的 .cape 文件
- [ ] 文件格式正确
- [ ] 包含正确的元数据（name, author）

#### B5. Dump 命令

```bash
$MOUSECLOAK dump ~/path/to/test.cape
```

- [ ] 成功输出 .cape 文件内容
- [ ] 显示所有光标类型
- [ ] 显示元数据（Version, CapeName, Author）
- [ ] 显示光标属性（帧数、尺寸、热点）

#### B6. Convert 命令

```bash
$MOUSECLOAK convert ~/path/to/test.cape --output ~/converted.cape
```

- [ ] 成功转换文件
- [ ] 输出文件格式正确
- [ ] 数据完整性保持

#### B7. Export 命令

```bash
$MOUSECLOAK export ~/path/to/test.cape --output ~/exported/
```

- [ ] 成功导出所有光标图像
- [ ] 图像文件格式正确（PNG/TIFF）
- [ ] 文件命名正确
- [ ] 所有光标类型都导出

#### B8. Scale 命令

```bash
$MOUSECLOAK scale ~/path/to/test.cape --scale 2.0 --output ~/scaled.cape
```

- [ ] 成功缩放光标
- [ ] 输出文件包含缩放后的图像
- [ ] 图像质量良好
- [ ] 热点位置正确调整

#### B9. Listen 命令

```bash
$MOUSECLOAK listen
```

- [ ] 成功启动监听模式
- [ ] 检测到光标变化时输出信息
- [ ] Ctrl+C 可以正常退出
- [ ] 无内存泄漏

---

## 🔒 安全性测试

### C1. 文件格式验证

**测试目标：** 验证 `CursorLibrary.validate()` 功能

- [ ] 尝试打开损坏的 .cape 文件
- [ ] 应用显示错误提示，不崩溃
- [ ] 尝试打开非 .cape 文件
- [ ] 应用拒绝打开，显示错误提示

**测试用例：**
```bash
# 创建损坏的文件
echo "invalid data" > ~/test-invalid.cape

# 创建缺少必需字段的文件
cat > ~/test-missing-fields.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CapeName</key>
    <string>Test</string>
</dict>
</plist>
EOF
plutil -convert binary1 ~/test-missing-fields.plist -o ~/test-missing-fields.cape
```

- [ ] 打开 `test-invalid.cape` - 应该显示错误
- [ ] 打开 `test-missing-fields.cape` - 应该显示验证错误

### C2. 边界条件测试

- [ ] 打开空的 .cape 文件（无光标）
- [ ] 打开包含 100+ 光标的大型文件
- [ ] 导入超大图像（>10MB）
- [ ] 导入超小图像（1x1 像素）
- [ ] 应用在所有情况下都不崩溃

### C3. 并发测试

- [ ] 同时打开多个 .cape 文件
- [ ] 快速切换不同文件
- [ ] 在保存过程中关闭窗口
- [ ] 应用保持稳定，无数据损坏

---

## ⚡ 性能测试

### D1. 启动性能

- [ ] 记录应用启动时间（从点击到窗口显示）
- [ ] 启动时间 < 2 秒
- [ ] 内存占用合理（< 100 MB）

### D2. 文件加载性能

- [ ] 打开小型 .cape 文件（< 1 MB）- 应该 < 0.5 秒
- [ ] 打开中型 .cape 文件（1-5 MB）- 应该 < 2 秒
- [ ] 打开大型 .cape 文件（> 5 MB）- 应该 < 5 秒

### D3. 保存性能

- [ ] 保存小型 .cape 文件 - 应该 < 0.5 秒
- [ ] 保存大型 .cape 文件 - 应该 < 3 秒
- [ ] 保存过程中 UI 不冻结

### D4. 内存使用

- [ ] 打开多个 .cape 文件，内存增长合理
- [ ] 关闭文件后，内存正确释放
- [ ] 长时间运行无内存泄漏

---

## 🔄 兼容性测试

### E1. 文件格式兼容性

**测试目标：** 确保 .cape 文件格式向后兼容

- [ ] 使用旧版本 Mousecape 创建的 .cape 文件可以正常打开
- [ ] 新版本保存的 .cape 文件可以在旧版本中打开（如果有旧版本）
- [ ] 文件结构符合规范：
  - `Version: 2.0`
  - `MinimumVersion: 2.0`
  - `Cursors` 字典包含正确的键值对
  - 图像数据使用 TIFF + LZW 压缩

**验证命令：**
```bash
# 检查文件结构
plutil -convert xml1 -o - ~/path/to/test.cape | grep -A 5 "Version\|MinimumVersion\|Cursors"
```

### E2. macOS 版本兼容性

- [ ] 在当前 macOS 版本上测试（Darwin 25.1.0）
- [ ] 如果可能，在其他 macOS 版本上测试

### E3. 显示器兼容性

- [ ] 在标准分辨率显示器上测试
- [ ] 在 Retina 显示器上测试
- [ ] 光标在所有显示器上清晰显示

---

## 🐛 回归测试

### F1. 已知问题验证

- [ ] 内存优化功能正常（隐藏到菜单栏时释放内存）
- [ ] 窗口生命周期管理正常
- [ ] 从 Finder 双击打开 .cape 文件正常
- [ ] Simple/Advanced 编辑模式切换正常

### F2. ObjC 代码保留验证

**测试目标：** 确认保留的 ObjC 代码正常工作

- [ ] MCCursor 类正常工作（通过 Cursor.swift 包装器）
- [ ] MCCursorLibrary 类正常工作（通过 CursorLibrary.swift 包装器）
- [ ] MCLibraryController 正常管理 Cape 文件
- [ ] 私有 API 层（mousecloak/）正常应用光标

---

## 📊 测试结果汇总

### 通过的测试

- [ ] GUI 应用测试：_____ / _____ 通过
- [ ] CLI 工具测试：_____ / _____ 通过
- [ ] 安全性测试：_____ / _____ 通过
- [ ] 性能测试：_____ / _____ 通过
- [ ] 兼容性测试：_____ / _____ 通过
- [ ] 回归测试：_____ / _____ 通过

### 发现的问题

| 编号 | 严重程度 | 问题描述 | 重现步骤 | 状态 |
|------|----------|----------|----------|------|
| 1    |          |          |          |      |
| 2    |          |          |          |      |
| 3    |          |          |          |      |

**严重程度：**
- 🔴 Critical：应用崩溃、数据丢失
- 🟡 Major：功能无法使用
- 🟢 Minor：UI 问题、性能问题
- 🔵 Trivial：文档、提示信息

### 总体评估

- [ ] ✅ 所有核心功能正常，可以发布
- [ ] ⚠️ 有一些小问题，需要修复后发布
- [ ] ❌ 有严重问题，需要进一步开发

### 测试人员签名

**测试完成日期：** _____________
**测试人员：** _____________
**签名：** _____________

---

## 📚 附录：测试数据准备

### 创建测试用的 .cape 文件

```bash
# 使用 mousecloak CLI 创建测试文件
$MOUSECLOAK create --name "Test Cape" --author "Tester" --output ~/test.cape

# 或者从现有的 Cape 库中复制
cp ~/Library/Application\ Support/Mousecape/*.cape ~/test-capes/
```

### 准备测试图像

```bash
# 创建测试图像目录
mkdir -p ~/test-images

# 准备不同格式和尺寸的图像
# - PNG 图像（标准、@2x）
# - TIFF 图像
# - 动画图像（多帧）
# - 不同尺寸（16x16, 32x32, 64x64, 128x128）
```

### 监控工具

- **Activity Monitor**：监控内存和 CPU 使用
- **Console.app**：查看应用日志和错误
- **Instruments**：性能分析（可选）

---

## 🔗 相关文档

- `GBCLI_MIGRATION_GUIDE.md` - GBCli 迁移指南
- `OBJC_TO_SWIFT_MIGRATION_ANALYSIS.md` - 迁移分析报告
- `.analysis/` 目录 - 详细的分析文档
