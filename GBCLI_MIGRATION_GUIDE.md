# GBCli 迁移到 Swift ArgumentParser - 配置指南

## 已完成的工作

1. ✅ 创建了 `main.swift` - 使用 Swift ArgumentParser 实现所有 CLI 命令
2. ✅ 创建了 `mousecloak-Bridging-Header.h` - Swift/ObjC 桥接头文件
3. ✅ 配置了 Xcode 项目：
   - 移除了 main.m 的引用
   - 添加了 main.swift 和 bridging header
   - 配置了 SWIFT_OBJC_BRIDGING_HEADER 和 SWIFT_VERSION
4. ✅ 删除了 main.m 文件
5. ✅ 删除了 GBCli 目录

## 需要手动完成的步骤

### 1. 添加 Swift ArgumentParser 依赖

由于 xcodeproj gem 的限制，需要在 Xcode 中手动添加 Swift Package 依赖：

1. 打开 `Mousecape/Mousecape.xcodeproj` 在 Xcode 中
2. 选择项目文件（左侧导航栏最顶部的 Mousecape）
3. 选择 `mousecloak` target
4. 点击顶部的 "Package Dependencies" 标签
5. 点击 "+" 按钮
6. 输入 Package URL: `https://github.com/apple/swift-argument-parser`
7. 选择版本规则：Up to Next Major Version，最小版本 1.2.0
8. 点击 "Add Package"
9. 在弹出的对话框中，确保 `ArgumentParser` 被添加到 `mousecloak` target
10. 点击 "Add Package"

### 2. 验证构建设置

确认以下构建设置已正确配置（应该已经由脚本自动配置）：

- **Swift Objective-C Bridging Header**: `Mousecape/mousecloak/mousecloak-Bridging-Header.h`
- **Swift Language Version**: Swift 5.0
- **Enable Modules (C and Objective-C)**: Yes

### 3. 构建项目

1. 选择 `mousecloak` scheme
2. 按 Cmd+B 构建项目
3. 检查是否有编译错误

### 4. 测试 CLI 命令

构建成功后，测试所有命令：

```bash
# 显示帮助
./build/Debug/mousecloak --help

# 测试 reset 命令
./build/Debug/mousecloak reset

# 测试 scale 命令（获取当前缩放）
./build/Debug/mousecloak scale

# 测试 apply 命令（需要一个 .cape 文件）
./build/Debug/mousecloak apply /path/to/test.cape
```

## 命令对照表

| 旧命令 (GBCli) | 新命令 (ArgumentParser) |
|---------------|------------------------|
| `mousecloak -a <path>` | `mousecloak apply <path>` |
| `mousecloak --apply <path>` | `mousecloak apply <path>` |
| `mousecloak -r` | `mousecloak reset` |
| `mousecloak --reset` | `mousecloak reset` |
| `mousecloak -c <path>` | `mousecloak create <path>` |
| `mousecloak --create <path>` | `mousecloak create <path>` |
| `mousecloak -d <path>` | `mousecloak dump <path>` |
| `mousecloak --dump <path>` | `mousecloak dump <path>` |
| `mousecloak -x <path>` | `mousecloak convert <path>` |
| `mousecloak --convert <path>` | `mousecloak convert <path>` |
| `mousecloak -e <path> -o <out>` | `mousecloak export <path> -o <out>` |
| `mousecloak --export <path> --output <out>` | `mousecloak export <path> --output <out>` |
| `mousecloak -s` | `mousecloak scale` |
| `mousecloak -s 2.0` | `mousecloak scale 2.0` |
| `mousecloak --scale` | `mousecloak scale` |
| `mousecloak --scale 2.0` | `mousecloak scale 2.0` |
| `mousecloak --listen` | `mousecloak listen` |

## 主要变化

1. **子命令架构**: 从单字母选项（-a, -r, -c）改为子命令（apply, reset, create）
2. **更清晰的语法**: 子命令使参数更明确，减少混淆
3. **自动帮助**: ArgumentParser 自动生成帮助文档
4. **类型安全**: Swift 的类型系统提供更好的参数验证

## 故障排除

### 编译错误：找不到 ArgumentParser

- 确保已正确添加 Swift Package 依赖
- 检查 Package Dependencies 标签中是否显示 swift-argument-parser
- 尝试 Product → Clean Build Folder，然后重新构建

### 编译错误：找不到 ObjC 函数

- 检查 bridging header 路径是否正确
- 确保所有 ObjC 头文件都在 bridging header 中导入
- 检查 Build Settings 中的 SWIFT_OBJC_BRIDGING_HEADER 设置

### 链接错误

- 确保所有 ObjC .m 文件都在 mousecloak target 的 Compile Sources 中
- 检查是否有缺失的框架依赖

## 下一步

完成上述步骤后，mousecloak CLI 工具将使用 Swift ArgumentParser 而不是 GBCli。所有功能应该保持不变，但命令行接口更加现代化和用户友好。
