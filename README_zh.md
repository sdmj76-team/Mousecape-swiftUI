<div align="center">

<div style="width: 160px;">
  <!-- Light mode -->
  <img src="Screenshot/Icon-Light.png#gh-light-mode-only" width="160">
  <!-- Dark mode -->
  <img src="Screenshot/Icon-Dark.png#gh-dark-mode-only" width="160">
</div>

# Mousecape-swiftUI

<p>
  <!-- GitHub Downloads -->
  <a href="https://github.com/sdmj76/Mousecape-swiftUI/releases">
    <img src="https://img.shields.io/github/downloads/sdmj76/Mousecape-swiftUI/total" alt="GitHub all releases">
  </a>
  <!-- GitHub Release Version -->
  <a href="https://github.com/sdmj76/Mousecape-swiftUI/releases">
    <img src="https://img.shields.io/github/v/release/sdmj76/Mousecape-swiftUI" alt="GitHub release (with filter)">
  </a>
  <!-- GitHub Issues -->
  <a href="https://github.com/sdmj76/Mousecape-swiftUI/issues">
    <img src="https://img.shields.io/github/issues/sdmj76/Mousecape-swiftUI" alt="GitHub issues">
  </a>
  <!-- GitHub Stars -->
  <a href="https://github.com/sdmj76/Mousecape-swiftUI/stargazers">
    <img src="https://img.shields.io/github/stars/sdmj76/Mousecape-swiftUI" alt="GitHub Repo stars">
  </a>
</p>

一款免费的 macOS 光标管理器，让你轻松替换 Mac 系统指针。
<br/>
<br/>
**适配 macOS 26，全面采用液态玻璃设计。支持一键转换Windows光标**
<br/>
<br/>
[English](README.md) | 中文
</div>

---

## 界面展示

<div align="center" style="display: flex; gap: 20px; justify-content: center; align-items: flex-start;">
  <img src="Screenshot/Home_zh_lg.gif#gh-light-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit_zh_lg.gif#gh-light-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Home_zh_dk.gif#gh-dark-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit_zh_dk.gif#gh-dark-mode-only" width="48%" style="height: auto;" />
</div>

> 截图中展示的光标主题 "Kiriko" 由 [ArakiCC](https://space.bilibili.com/14913641) 制作，在示例文件中提供。

## 功能特性

- 自定义 Mac 系统光标，支持静态和动画光标
- 一键转换 Windows 格式指针（.cur / .ani），覆盖 85% 的 macOS 光标类型
- 可快捷预览Windows格式指针，为macOS快速预览支持
- 提取系统默认光标，适合喜欢旧系统光标的用户
- 左手模式：水平翻转光标，适合左手用户
- 多语言支持：简体中文、繁体中文、英语、日语、韩语、德语、法语

## 下载安装
### 系统要求

- macOS Sequoia (15) 或更高版本
- 支持架构：同时支持 Intel 和 Apple Silicon Mac（通用二进制）

> **注意：** Debug 版本仅包含构建机器的架构，可能无法在所有 Mac 上运行。正常使用请下载普通（Release）版本。

在本 GitHub 页面的 [Releases](https://github.com/sdmj76/Mousecape-swiftUI/releases) 部分下载最新版本。

如果遇到问题，建议优先查看[故障排除](#故障排除)章节。

## 示例光标

本仓库的示例光标位于 [Example](Example/) 目录下，包含以下光标

**Kiriko.cape**： 由 [ArakiCC](https://space.bilibili.com/14913641) 制作，使用 CC BY-NC-ND 4.0（署名-非商业性-禁止演绎 4.0）许可证

**Default_macOS 15.cape**： 由 macOS 15系统提取的默认光标

**Default_macOS 26.cape**： 由 macOS 26系统提取的默认光标

[Windows](Example/Windows/)： 存放部分示例光标的 Windows版本

## 快速开始

<details>
<summary>设置开机启动</summary>

1. 下载并打开 Mousecape 应用
2. 进入 **设置 > 通用**，开启 **开机自动应用**

开启后，Mousecape 会在登录时后台启动，并提供菜单栏图标，你可以通过它：
- 打开 Mousecape 应用
- 重置为系统默认光标

> **注意：** Helper 始终在后台运行以进行会话监控。"显示菜单栏工具"开关仅控制菜单栏图标的可见性。

</details>
<br>
<details>
<summary>导入 Windows 格式光标</summary>

Mousecape 支持一键转换 Windows 光标类型：

1. 下载的 Windows 光标包解压
2. 点击 "+" 按钮，选择"导入 Windows 光标"
3. 选择包含光标文件的文件夹导入即可

如果文件夹中包含 `*.inf` 文件，Mousecape 会自动解析该文件以正确映射光标类型。否则，将使用基于文件名的匹配。

</details>
<br>
<details>
<summary>创建自定义光标套装</summary>

1. 点击 "+" 按钮添加新光标套装
2. 点击 "+" 按钮添加要自定义的指针
3. 将图片或光标文件拖放到编辑窗口中
4. 调整热点位置和其他参数
5. 保存并应用你的主题

**现代 / 传统 模式**

Mousecape 提供两种 `显示 / 编辑` 模式，可通过 设置 > 外观 > 显示模式 切换：

- **现代模式**：以 15 个 Windows 光标分组展示。编辑一个光标后自动同步到同组内所有相关的 macOS 光标类型。
- **传统模式**：逐个编辑 52 个 macOS 光标类型，保留完整控制。

</details>
<br>
<details>
<summary>导入/导出 .cape 格式光标</summary>

- 点击 "导入" 按键，在弹出的finder窗口，选择要导入的 **.cape** 格式光标
- 或直接将 **.cape** 文件拖放到应用窗口即可导入
- 或在访达中双击 **.cape** 文件即可直接在 Mousecape 中打开
- 点击 "导出" 按键，在弹出的finder窗口，选择要保存 **.cape** 光标的位置

> **.cape** 为 Mousecape 专用光标格式，文件内包含了一整套光标的内容
>
> **注意：** 使用 v1.1.0+ 保存的 Cape 文件采用 HEIF 图像格式，可能无法被旧版本 Mousecape 打开。现有的 Cape 文件可以继续使用，保存时会自动升级到新格式。

</details>
<br>
<details>
<summary>重置系统光标</summary>

如果你想恢复为 macOS 默认光标，可以：

- 点击 **macOS 菜单栏 > 文件 > 重置为系统光标**
- 或使用快捷键 **Cmd+R**

</details>
<br>
<details>
<summary>提取当前光标</summary>

如果你想提取当前正在使用的光标，可以：

- 点击 **macOS 菜单栏 > 文件 > 提取当前光标**

</details>

### 支持的图片格式

- **常规图片格式**：PNG、JPEG、TIFF、GIF
- **Windows 光标格式**：.cur（静态）、.ani（动画）

## 故障排除

如果遇到问题，请先查看以下常见解决方案。更多帮助请[提交 Issue](https://github.com/sdmj76/Mousecape-swiftUI/issues)。

> **由于 macOS 系统限制，Mousecape 有以下限制：** 
>
> *图像尺寸限制*
>
> - 最大导入尺寸：**512×512 像素**（超过此尺寸的图像将被拒绝）
> - 所有光标图像会自动缩放至 **64×64 像素**（1x 分辨率）
> - 如果导入的图像大于 64×64（最大 512×512），会自动缩小
> - 如果导入的图像小于 64×64，会自动放大（可能导致质量下降）
>
> *动画帧数限制*
>
> - 每个动画光标最多支持 **24 帧**
> - 超过 24 帧的动画光标会自动降采样
> - 降采样会通过调整帧时长来保持动画速度一致
>
> *示例：* 32 帧的 GIF 动画会被降采样到 24 帧，帧时长会增加以保持原始动画速度。

<br>
<details>
<summary>光标在部分软件不生效</summary>

**症状**：光标在软件窗口内不生效，如终端、Excel

**原因**：部分软件会配置自定义光标，覆盖系统光标配置

**解决方案**：暂无安全解决方案，此问题只会在部分软件出现，影响范围不大。

</details>
<br>
<details>
<summary>光标动画仅在 Dock 区域生效</summary>

**症状**：自定义光标动画仅在悬停在 Dock 上时显示，移动到其他地方会恢复为系统默认光标。

**原因**：macOS 系统设置中的自定义指针颜色会阻止 Mousecape 成功应用全局光标。

**解决方案**：将系统指针颜色重置为默认设置：

1. 打开 **系统设置** > **辅助功能** > **显示**
2. 找到 **指针** 部分
3. 点击 **重设颜色** 按钮
4. 重新在 Mousecape 中应用光标主题

光标必须使用默认颜色方案（白色轮廓、黑色填充），Mousecape 才能正常工作。

</details>
<br>
<details>
<summary>动画光标导入失败</summary>

**症状**：动画光标文件（.ani 或 .gif）无法导入或被拒绝。

**原因**：超过 24 帧的动画光标超出了 macOS 系统限制，需要自动降采样。

**解决方案**：
- Mousecape 会自动对超过 24 帧的动画进行降采样
- 动画速度会通过调整帧时长来保持一致
- 如果仍然无法导入，请确保文件未损坏，尝试重新下载

</details>
<br>
<details>
<summary>中文光标主题显示乱码</summary>

**症状**：中文或其他非英文光标主题显示乱码或名称不正确。

**原因**：INF 文件编码检测不正确。

**解决方案**：
- Mousecape 支持多种编码：UTF-8、UTF-16 LE/BE、GBK、GB18030、Big5、Shift_JIS、EUC-KR、ISO-8859-1
- 确保 INF 文件使用支持的编码保存
- 如果问题持续，尝试将 INF 文件另存为 UTF-8 编码

</details>
<br>
<details>
<summary>光标图像过大</summary>

**症状**：大型光标图像在导入时被拒绝。

**原因**：图像超过了最大支持的 512×512 像素尺寸。

**解决方案**：
- 在导入前将图像调整为 512×512 像素或更小
- 所有导入的图像会自动缩放到 64×64 像素
- 超过 512×512 的图像将被拒绝并显示错误消息

</details>
<br>

**MacBook Neo 特定**

此机型上的自定义指针，目前可能因 macOS 省电策略而失效。
由于缺乏测试设备，此问题暂无计划修复，需等待 Apple 官方更新。 [相关讨论](https://www.reddit.com/r/macbook/comments/1rvde0d/strange_laggy_cursor_issue_with_neo/)

## 捐赠

如果你觉得我的UI重制做的不错，可以支持我一下 :)

<div align="center">
<img src="Screenshot/Donate.png" width="640">
</div>

## 致谢

- 原始项目由 [Alex Zielenski](https://github.com/alexzielenski) 创建
- 演示以及示例光标 "Kiriko" 由 [ArakiCC](https://space.bilibili.com/14913641) 制作
- UI指导由 [Winter喵](https://space.bilibili.com/15016945) 帮助
- SwiftUI 界面重构及液态玻璃适配由 [sdmj76](https://space.bilibili.com/224661756) 完成
- SwiftUI 代码编程及本地化由 [Claude Code](https://claude.ai/code) 辅助编写

## 反馈与问题

如有问题或建议，欢迎在 [GitHub Issues](https://github.com/sdmj76/Mousecape-swiftUI/issues) 提出。

## 作者的话

这只是一个工具，我美化了它的UI。但最重要的还是你的光标内容 :)

---

> **许可证声明：** 本项目采用双段式许可证。Alex Zielenski 的原始代码（ObjC 模型层、私有 API 层）保留其原始 BSD 类条款。sdmj76 的所有 SwiftUI 界面、CLI 重写、Windows 光标转换及文档受 Mousecape 非商业许可证约束，禁止再分发且必须保留署名。由于编译后的应用同时包含两部分代码，再分发整体软件需遵守更严格的条款。详见 [LICENSE](LICENSE)。
