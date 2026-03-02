# main.swift 代码审查

## 概述

main.swift 使用 Swift ArgumentParser 框架重新实现了 mousecloak CLI 工具，替换了原来的 GBCli 框架。

## 架构设计

### 主结构

```swift
@main
struct MousecloakCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mousecloak",
        abstract: "A command-line tool for managing macOS cursor themes",
        version: "2.0",
        subcommands: [...]
    )
}
```

使用 `@main` 属性标记入口点，ArgumentParser 会自动处理命令行参数解析和帮助文档生成。

### 子命令架构

每个命令都作为 `MousecloakCLI` 的嵌套结构体实现：

```swift
extension MousecloakCLI {
    struct Apply: ParsableCommand {
        // 命令配置和实现
    }
}
```

这种设计保持了代码的组织性和可维护性。

## 命令实现

### 1. Apply 命令

**功能：** 应用一个 cape 文件

**参数：**
- `capePath`: 位置参数，cape 文件路径

**ObjC 函数调用：**
```swift
applyCapeAtPath(capePath)
```

**对应原始命令：** `mousecloak -a <path>` 或 `mousecloak --apply <path>`

### 2. Reset 命令

**功能：** 重置为默认系统光标

**参数：** 无

**ObjC 函数调用：**
```swift
resetAllCursors()
```

**对应原始命令：** `mousecloak -r` 或 `mousecloak --reset`

### 3. Create 命令

**功能：** 从目录创建 cape 文件

**参数：**
- `inputPath`: 位置参数，输入目录路径
- `output`: 可选选项 `-o/--output`，输出文件路径

**ObjC 函数调用：**
```swift
let error = createCape(inputPath, outputPath, false)
```

**默认行为：** 如果未指定 output，使用输入路径的父目录

**对应原始命令：** `mousecloak -c <path>` 或 `mousecloak --create <path>`

### 4. Dump 命令

**功能：** 导出当前应用的光标到文件

**参数：**
- `outputPath`: 位置参数，输出文件路径

**ObjC 函数调用：**
```swift
dumpCursorsToFile(outputPath) { progress, total in
    print("Dumped \(progress) of \(total)")
    return true
}
```

**特点：** 使用闭包作为进度回调

**对应原始命令：** `mousecloak -d <path>` 或 `mousecloak --dump <path>`

### 5. Convert 命令

**功能：** 转换 MightyMouse 文件为 cape

**参数：**
- `inputPath`: 位置参数，输入 .MightyMouse 文件路径
- `output`: 可选选项 `-o/--output`，输出文件路径

**ObjC 函数调用：**
```swift
let error = createCape(inputPath, outputPath, true)
```

**注意：** 第三个参数为 `true` 表示转换模式

**对应原始命令：** `mousecloak -x <path>` 或 `mousecloak --convert <path>`

### 6. Export 命令

**功能：** 导出 cape 到目录

**参数：**
- `inputPath`: 位置参数，输入 cape 文件路径
- `output`: **必需**选项 `-o/--output`，输出目录路径

**ObjC 函数调用：**
```swift
exportCape(cape as! [AnyHashable: Any], outputDir)
```

**错误处理：**
- 检查 `-o` 选项是否提供
- 检查 cape 文件是否能成功读取

**对应原始命令：** `mousecloak -e <path> -o <output>`

**修复记录：** 最初错误地将 output 定义为位置参数，已修复为选项参数（commit d1df1c6）

### 7. Scale 命令

**功能：** 设置或获取光标缩放值

**参数：**
- `scaleValue`: 可选位置参数，缩放值

**ObjC 函数调用：**
```swift
// 设置缩放
setCursorScale(scale)

// 获取缩放
print("\(cursorScale())")
```

**行为：**
- 如果提供参数：设置缩放值
- 如果不提供参数：打印当前缩放值

**对应原始命令：**
- `mousecloak -s` 或 `mousecloak --scale`（获取）
- `mousecloak -s 2.0` 或 `mousecloak --scale 2.0`（设置）

### 8. Listen 命令

**功能：** 保持 mousecloak 运行，监听用户会话变化

**参数：** 无

**ObjC 函数调用：**
```swift
listener()
```

**注意：** 这是一个阻塞调用，会一直运行直到进程被终止

**对应原始命令：** `mousecloak --listen`

## 辅助函数

### printHeader(suppressCopyright:)

**功能：** 打印程序头部信息

**行为：**
- 在 DEBUG 模式下初始化日志系统
- 如果未抑制版权信息，打印版本号

**ANSI 颜色代码：** `\u{001B}[1m\u{001B}[37m` (粗体白色)

### printFooter(suppressCopyright:)

**功能：** 打印版权信息

**行为：**
- 如果未抑制版权信息，打印版权声明

### printError(_:)

**功能：** 打印错误消息

**ANSI 颜色代码：** `\u{001B}[1m\u{001B}[31m` (粗体红色)

### printSuccess(_:)

**功能：** 打印成功消息

**ANSI 颜色代码：** `\u{001B}[1m\u{001B}[32m` (粗体绿色)

## 共享选项

### suppressCopyright

**类型：** `@Flag`

**功能：** 抑制版权信息的显示

**使用：** `--suppressCopyright`

**实现：** 通过 `@OptionGroup` 在所有子命令中共享

## ObjC 互操作

### Bridging Header

所有 ObjC 函数通过 `mousecloak-Bridging-Header.h` 导入：

```objc
#import "apply.h"
#import "restore.h"
#import "create.h"
#import "scale.h"
#import "listen.h"
#import "MCLogger.h"
#import "MCDefs.h"
```

### 函数签名

所有 ObjC 函数都使用 `NS_ASSUME_NONNULL_BEGIN/END` 注解，因此在 Swift 中不需要处理 Optional。

### 类型转换

**NSDictionary 转换：**
```swift
guard let cape = NSDictionary(contentsOfFile: inputPath) else { ... }
exportCape(cape as! [AnyHashable: Any], outputDir)
```

**NSString 路径操作：**
```swift
let outputPath = output ?? (inputPath as NSString).deletingLastPathComponent
```

## 与原始实现的差异

### 命令行接口变化

| 原始 (GBCli) | 新版 (ArgumentParser) | 说明 |
|-------------|---------------------|------|
| `mousecloak -a <path>` | `mousecloak apply <path>` | 子命令架构 |
| `mousecloak -r` | `mousecloak reset` | 子命令架构 |
| `mousecloak -c <path>` | `mousecloak create <path>` | 子命令架构 |
| `mousecloak -d <path>` | `mousecloak dump <path>` | 子命令架构 |
| `mousecloak -x <path>` | `mousecloak convert <path>` | 子命令架构 |
| `mousecloak -e <path> -o <out>` | `mousecloak export <path> -o <out>` | 子命令架构 |
| `mousecloak -s` | `mousecloak scale` | 子命令架构 |
| `mousecloak -s 2.0` | `mousecloak scale 2.0` | 子命令架构 |
| `mousecloak --listen` | `mousecloak listen` | 子命令架构 |

### 改进之处

1. **更清晰的命令结构**
   - 子命令比单字母选项更易理解
   - 每个命令有独立的帮助文档

2. **自动生成的帮助**
   - ArgumentParser 自动生成格式化的帮助文档
   - 支持 `--help` 和 `-h` 选项

3. **类型安全**
   - Swift 的类型系统提供编译时检查
   - 减少运行时错误

4. **更好的错误处理**
   - ArgumentParser 自动处理参数验证
   - 提供清晰的错误消息

## 潜在问题和注意事项

### 1. 强制类型转换

```swift
exportCape(cape as! [AnyHashable: Any], outputDir)
```

使用 `as!` 强制转换可能导致运行时崩溃。但由于 `NSDictionary` 总是可以转换为 `[AnyHashable: Any]`，这里是安全的。

### 2. DEBUG 宏

```swift
#if DEBUG
MCLoggerInit()
MCLoggerWrite("=== mousecloak CLI Started ===")
#endif
```

依赖于 DEBUG 宏的定义。确保在 Debug 配置中定义了 DEBUG。

### 3. 可选参数的默认值

Scale 命令使用可选参数来区分"获取"和"设置"操作。这与原始实现的行为一致。

### 4. 阻塞调用

Listen 命令调用 `listener()` 是一个阻塞调用，会一直运行。这与原始实现一致。

## 测试建议

### 单元测试

1. 测试每个命令的参数解析
2. 测试错误处理（缺少参数、无效路径等）
3. 测试 ObjC 函数调用

### 集成测试

1. 测试完整的命令行工作流
2. 测试与现有 cape 文件的兼容性
3. 测试 listen 命令的会话监听功能

### 回归测试

1. 确保所有原始功能都能正常工作
2. 测试边界情况（空文件、无效格式等）
3. 测试性能（与原始实现对比）

## 总结

main.swift 的实现：

✅ **优点：**
- 代码结构清晰，易于维护
- 使用现代 Swift 特性
- 自动生成帮助文档
- 类型安全

⚠️ **需要注意：**
- 命令行接口有变化（从选项到子命令）
- 需要更新文档和用户指南
- 需要充分测试以确保兼容性

🔧 **已修复的问题：**
- Export 命令的参数定义（commit d1df1c6）

📝 **待完成：**
- 在 Xcode 中配置 ArgumentParser 依赖
- 编译和测试
- 更新用户文档
