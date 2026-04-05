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

A free macOS cursor manager that allows you to easily replace Mac system pointers.
<br/>一款免费的 macOS 光标管理器，让你轻松替换 Mac 系统指针。
<br/>
<br/>
**Compatible with macOS 26, featuring a fully liquid glass design. Supports one-click conversion to Windows cursor.
<br/>适配 macOS 26，全面采用液态玻璃设计。支持一键转换Windows光标**
<br/>
<br/>
**[English](#english-section) | [中文](#chinese-section)**
</div>

<a id="english-section"></a>

# English

## Interface Display

![light](Screenshot/Light_en.gif#gh-light-mode-only)
![dark](Screenshot/Dark_en.gif#gh-dark-mode-only)


> The cursor theme "Kiriko" shown in the screenshots is created by [ArakiCC](https://space.bilibili.com/14913641), available in the example files.

## Features

- Customize Mac system cursors, supporting both static and animated cursors
- One-click conversion of Windows cursor formats (.cur / .ani), mapping 85% of macOS cursor types
- Extract default system cursors, perfect for users who prefer older system cursors
- Left-hand mode: mirror cursors horizontally for left-handed users
- Multi-language support: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French

## Download & Installation
### System Requirements

- macOS Sequoia (15) or later
- Support Architectures: runs on both Intel and Apple Silicon Macs

<br>
Download the latest version from the [Releases](https://github.com/sdmj76/Mousecape-swiftUI/releases) section of this GitHub page.

If you encounter any problems, we recommend that you first check the [Troubleshooting](#Troubleshooting_en) section.

## Example Cursors

This repository includes an example Kiriko.cape file, available for [download here](Example/Kiriko.cape).

**License:** CC BY-NC-ND 4.0 (Attribution-NonCommercial-NoDerivs 4.0)

This cursor set was created by [ArakiCC](https://space.bilibili.com/14913641).

## Getting Started

<details>
<summary>Set Up Launch at Login</summary>

1. Download and open the Mousecape app
2. Go to **Settings → General** and enable **Launch at Login**

When enabled, Mousecape starts in the background at login and provides a menu bar icon that you can use to:
- Open the Mousecape app
- Reset to default system cursor

> **Note:** The Helper always runs in the background for session monitoring. The "Show Menu Bar Tool" toggle only controls the menu bar icon visibility.

</details>
<br>
<details>
<summary>Import Windows Format Cursors</summary>

Mousecape supports one-click conversion of Windows cursor themes:

1. Extract the downloaded Windows cursor package
2. Click the "+" button and select "Import Windows Cursors"
3. Select the folder containing the cursor files to import

If the folder contains an `*.inf` file, Mousecape will automatically parse it to map cursor files to the correct cursor types. Otherwise, it will use filename-based matching.

</details>
<br>
<details>
<summary>Create Custom Cursor Sets</summary>

1. Click the "+" button to add a new cursor set
2. Click the "+" button to add pointers to customize
3. Drag and drop image or cursor files into the edit window
4. Adjust hotspot position and other parameters for each cursor
5. Save and apply your theme

**Simple / Advanced Mode**

Mousecape offers two editing modes, switchable via the toolbar:

- **Simple Mode**: Displays cursors in 15 Windows cursor groups. Editing one cursor automatically applies changes to all related macOS cursor types in the same group.
- **Advanced Mode**: Edit each of the 52 macOS cursor types individually for full control.

The home screen preview also supports Simple/Advanced display modes, configurable in **Settings → Appearance → Preview Panel**.

</details>
<br>
<details>
<summary>Import/Export .cape Format Cursors</summary>

- Click the "Import" button, then select the **.cape** format cursor file in the Finder window
- Or drag and drop **.cape** files directly onto the app window to import
- Or double-click a **.cape** file in Finder to open it directly in Mousecape
- Click the "Export" button, then choose where to save the **.cape** cursor file

> **.cape** is Mousecape's proprietary cursor format, containing a complete set of cursors in one file
>
> **Note:** Cape files saved with v1.1.0+ use HEIF image format and may not be compatible with older versions of Mousecape. Existing cape files will be automatically upgraded to the new format when saved.

</details>
<br>
<details>
<summary>Reset System Cursor</summary>

If you want to revert to the default macOS cursor, you can:

- Click **macOS menu bar → File → Reset System Cursor**
- Or use the keyboard shortcut **Cmd+R**

</details>
<br>
<details>
<summary>Extract Current Cursor</summary>

If you want to extract the cursors currently in use, you can:

- Click **macOS menu bar → File → Dump Current Cursor**

</details>
<br>
<details>
<summary>Supported Image Formats</summary>

- **Standard image formats**: PNG, JPEG, TIFF, GIF
- **Windows cursor formats**: .cur (static), .ani (animated)

</details>

<a id="Troubleshooting_en"></a>

## Troubleshooting

If you encounter issues, please check the common solutions below first. For more help, please [submit an Issue](https://github.com/sdmj76/Mousecape-swiftUI/issues).

### Cursor Limitations

Due to macOS system limitations, Mousecape has the following restrictions:

**Image Size Limit**

- Maximum import size: **512×512 pixels** (larger images will be rejected)
- All cursor images are automatically scaled to **64×64 pixels** at 1x resolution
- If the imported image is larger than 64×64 (up to 512×512), it will be automatically scaled down
- If the imported image is smaller than 64×64, it will be scaled up (may result in lower quality)

**Animation Frame Limit**

- Maximum **24 frames** per animated cursor
- Animated cursors with more than 24 frames will be automatically downsampled
- The downsampling preserves animation timing by adjusting frame duration

**Example:** A 32-frame GIF animation will be downsampled to 24 frames, and the frame duration will be increased to maintain the original animation speed.

<br>
<details>
<summary>Cursor Animation Only Works in Dock Area</summary>

**Symptoms:** Custom cursor animations only appear when hovering over the Dock, but revert to the default system cursor elsewhere.

**Cause:** macOS system settings for custom pointer colors can prevent Mousecape from successfully applying cursors globally.

**Solution:** Reset the system pointer color to the default setting:

1. Open **System Settings** → **Accessibility** → **Display**
2. Find the **Pointer** section
3. Click the **Reset Color** button
4. Re-apply your cursor theme in Mousecape

The pointer must use the default color scheme (white outline, black fill) for Mousecape to work properly.

</details>
<br>
<details>
<summary>Animated Cursor Import Failed</summary>

**Symptoms:** Animated cursor files (.ani or .gif) fail to import or are rejected.

**Cause:** Animated cursors with more than 24 frames exceed macOS system limits and require automatic downsampling.

**Solution:**
- Mousecape automatically downsamples animations with more than 24 frames
- The animation speed is preserved by adjusting frame duration
- If import still fails, ensure the file is not corrupted and try re-downloading

</details>
<br>
<details>
<summary>Chinese Cursor Theme Display Issues</summary>

**Symptoms:** Chinese or other non-English cursor themes show garbled filenames or incorrect names.

**Cause:** INF file encoding not detected correctly.

**Solution:**
- Mousecape supports multiple encodings: UTF-8, UTF-16 LE/BE, GBK, GB18030, Big5, Shift_JIS, EUC-KR, ISO-8859-1
- Ensure the INF file is saved in a supported encoding
- If issues persist, try resaving the INF file as UTF-8

</details>
<br>
<details>
<summary>Cursor Image Too Large</summary>

**Symptoms:** Large cursor images are rejected during import.

**Cause:** Image exceeds the maximum supported size of 512×512 pixels.

**Solution:**
- Resize images to 512×512 pixels or smaller before importing
- All imported images are automatically scaled to 64×64 pixels
- Images larger than 512×512 will be rejected with an error message

</details>

## Donate

If you like my UI remake, you can buy me an afternoon tea :)

![Donate](Screenshot/Donate.png)

## Acknowledgments

- Original project created by [Alex Zielenski](https://github.com/alexzielenski)
- Demo and example cursor "Kiriko" created by [ArakiCC](https://space.bilibili.com/14913641)
- UI guidance by [Winter喵](https://space.bilibili.com/15016945)
- SwiftUI interface redesign and Liquid Glass adaptation by [sdmj76](https://space.bilibili.com/224661756)
- SwiftUI code programming and localization assisted by [Claude Code](https://claude.ai/code)

## Feedback & Issues

If you have questions or suggestions, please submit them on [GitHub Issues](https://github.com/sdmj76/Mousecape-swiftUI/issues).

## A Note from the Author

This is just a tool, and I've polished its UI. But what matters most is your cursor content :)

> *English version translated from Chinese by [Claude Code](https://claude.ai/code)*

---

> **License Notice:** This project uses a dual-section license. Alex Zielenski's original code (ObjC model layer, private API layer) remains under its original BSD-like terms. All SwiftUI interface, CLI rewrite, Windows cursor conversion, and documentation by sdmj76 are covered by the Mousecape Non-Commercial License, which prohibits redistribution and requires attribution. Because the compiled application includes both, redistributing the Software as a whole requires compliance with the stricter terms. See [LICENSE](LICENSE) for full details.

---

<a id="chinese-section"></a>

# 中文

## 界面展示

![light](Screenshot/Light_zh.gif#gh-light-mode-only)
![dark](Screenshot/Dark_zh.gif#gh-dark-mode-only)

> 截图中展示的光标主题 "Kiriko" 由 [ArakiCC](https://space.bilibili.com/14913641) 制作，在示例文件中提供。

## 功能特性

- 自定义 Mac 系统光标，支持静态和动画光标
- 一键转换 Windows 格式指针（.cur / .ani），覆盖 85% 的 macOS 光标类型
- 提取系统默认光标，适合喜欢旧系统光标的用户
- 左手模式：水平翻转光标，适合左手用户
- 多语言支持：简体中文、繁体中文、英语、日语、韩语、德语、法语

## 下载安装
### 系统要求

- macOS Sequoia (15) 或更高版本
- 支持架构：同时支持 Intel 和 Apple Silicon Mac

<br>
在本 GitHub 页面的 [Releases](https://github.com/sdmj76/Mousecape-swiftUI/releases) 部分下载最新版本。

如果遇到问题，建议优先查看[故障排除](#Troubleshooting_cn)章节。

## 示例光标

本仓库包含示例 Kiriko.cape 文件，可在[此处下载](Example/Kiriko.cape)。

**许可证：** CC BY-NC-ND 4.0（署名-非商业性-禁止演绎 4.0）

此光标由 [ArakiCC](https://space.bilibili.com/14913641) 制作。

## 快速开始

<details>
<summary>设置开机启动</summary>

1. 下载并打开 Mousecape 应用
2. 进入 **设置 → 通用**，开启 **开机自动应用**

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

**简易/高级模式**

Mousecape 提供两种编辑模式，可通过工具栏切换：

- **简易模式**：以 15 个 Windows 光标分组展示。编辑一个光标后自动同步到同组内所有相关的 macOS 光标类型。
- **高级模式**：逐个编辑 52 个 macOS 光标类型，保留完整控制。

首页预览也支持简易/高级显示模式，可在 **设置 → 外观 → 预览面板** 中配置。

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

- 点击 **macOS 菜单栏 → 文件 → 重置为系统光标**
- 或使用快捷键 **Cmd+R**

</details>
<br>
<details>
<summary>提取当前光标</summary>

如果你想提取当前正在使用的光标，可以：

- 点击 **macOS 菜单栏 → 文件 → 提取当前光标**

</details>

### 支持的图片格式

- **常规图片格式**：PNG、JPEG、TIFF、GIF
- **Windows 光标格式**：.cur（静态）、.ani（动画）

<a id="Troubleshooting_cn"></a>

## 故障排除

如果遇到问题，请先查看以下常见解决方案。更多帮助请[提交 Issue](https://github.com/sdmj76/Mousecape-swiftUI/issues)。

### 光标限制

由于 macOS 系统限制，Mousecape 有以下限制：

**图像尺寸限制**

- 最大导入尺寸：**512×512 像素**（超过此尺寸的图像将被拒绝）
- 所有光标图像会自动缩放至 **64×64 像素**（1x 分辨率）
- 如果导入的图像大于 64×64（最大 512×512），会自动缩小
- 如果导入的图像小于 64×64，会自动放大（可能导致质量下降）

**动画帧数限制**

- 每个动画光标最多支持 **24 帧**
- 超过 24 帧的动画光标会自动降采样
- 降采样会通过调整帧时长来保持动画速度一致

**示例：** 32 帧的 GIF 动画会被降采样到 24 帧，帧时长会增加以保持原始动画速度。

<br>
<details>
<summary>光标动画仅在 Dock 区域生效</summary>

**症状**：自定义光标动画仅在悬停在 Dock 上时显示，移动到其他地方会恢复为系统默认光标。

**原因**：macOS 系统设置中的自定义指针颜色会阻止 Mousecape 成功应用全局光标。

**解决方案**：将系统指针颜色重置为默认设置：

1. 打开 **系统设置** → **辅助功能** → **显示**
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

## 捐赠

如果你觉得我的UI重制做的不错，可以请我喝杯下午茶 :)

![捐赠](Screenshot/Donate.png)

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
