<div align="center">
  <a href="https://github.com/sdmj76/Mousecape-swiftUI" target="_blank">
    <img width="160" src="Screenshot/icon.png" alt="logo">
  </a>
  <h2 id="koishi">Mousecape-swiftUI</h1>

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

<div align="center" style="display: flex; gap: 20px; justify-content: center; align-items: flex-start;">
  <img src="Screenshot/Home.gif" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit.gif" width="48%" style="height: auto;" />
</div>


> The cursor theme "Kiriko" shown in the screenshots is created by [ArakiCC](https://space.bilibili.com/14913641), available in the example files.

## Features

**System Requirements:** macOS Sequoia (15) or later

- Customize Mac system cursors, supporting both static and animated cursors
- One-click import of Windows cursor formats (.cur / .ani)
- Uses private, non-intrusive CoreGraphics API, safe and reliable
- Background helper with menu bar icon for quick access and cursor management
- Optional launch at login to automatically apply your cursor theme

## Download & Installation

Download the latest version from the [Releases](https://github.com/sdmj76/Mousecape/releases) section of this GitHub page.

If you encounter any problems, we recommend that you first check the [Troubleshooting](#Troubleshooting_en) section.

### System Requirements

- macOS Sequoia (15) or later
- Support Architectures: runs on both Intel and Apple Silicon Macs

## Example Cursors

This repository includes an example Kiriko.cape file, available for [download here](Example/Kiriko.cape).

**License:** CC BY-NC-ND 4.0 (Attribution-NonCommercial-NoDerivs 4.0)

This cursor set was created by [ArakiCC](https://space.bilibili.com/14913641).

To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

## Getting Started

### Set Up Launch at Login (Optional, for automatic cursor application after restart)

1. Download and open the Mousecape app
2. Go to **Settings → General** and enable **Launch at Login**

When enabled, MousecapeHelper starts in the background at login and automatically applies your last cursor theme. The helper provides a menu bar icon that you can use to:
- Open the main Mousecape app
- Apply or reset cursor themes
- Quit the helper

The main Mousecape app can be closed independently, while the helper continues running in the background to maintain your cursor theme.

### Import Windows Format Cursors

Mousecape supports batch importing Windows cursor themes:

1. Extract the downloaded Windows cursor package
2. Click the "+" button and select "Import Windows Cursors"
3. Select the folder containing the cursor files to import

If the folder contains an `*.inf` file, Mousecape will automatically parse it to map cursor files to the correct cursor types. Otherwise, it will use filename-based matching.

### Create Custom Cursor Sets

1. Click the "+" button to add a new cursor set
2. Click the "+" button to add pointers to customize
3. Drag and drop image or cursor files into the edit window
4. Adjust hotspot position and other parameters for each cursor
5. Save and apply your theme

### Import/Export **.cape** Format Cursors

- Click the "Import" button, then select the **.cape** format cursor file in the Finder window
- Or drag and drop **.cape** files directly onto the app window to import
- Click the "Export" button, then choose where to save the **.cape** cursor file

> **.cape** is Mousecape's proprietary cursor format, containing a complete set of cursors in one file

### Reset System Cursor

If you want to revert to the default macOS cursor, you can:

- Click **Settings → Reset System Cursor**
- Or use the keyboard shortcut **Cmd+R**

### Supported Image Formats

- **Standard image formats**: PNG, JPEG, TIFF, GIF
- **Windows cursor formats**: .cur (static), .ani (animated)

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

<a id="Troubleshooting_en"></a>

## Troubleshooting

If you encounter issues, please check the common solutions below first. For more help, please [submit an Issue](https://github.com/sdmj76/Mousecape/issues).

### Migrating from Older Versions

If you previously installed an older version of Mousecape with a separate helper daemon, the new version will automatically unregister the old `com.sdmj76.mousecloakhelper` LaunchAgent on first launch. No manual action is needed.

If you still see the old daemon running, you can manually remove it:
```bash
launchctl bootout gui/$(id -u)/com.sdmj76.mousecloakhelper
```

### Cursor Animation Only Works in Dock Area

**Symptoms:** Custom cursor animations only appear when hovering over the Dock, but revert to the default system cursor elsewhere.

**Cause:** macOS system settings for custom pointer colors can prevent Mousecape from successfully applying cursors globally.

**Solution:** Reset the system pointer color to the default setting:

1. Open **System Settings** → **Accessibility** → **Display**
2. Find the **Pointer** section
3. Click the **Reset Color** button
4. Re-apply your cursor theme in Mousecape

The pointer must use the default color scheme (white outline, black fill) for Mousecape to work properly.

### Animated Cursor Import Failed

**Symptoms:** Animated cursor files (.ani or .gif) fail to import or are rejected.

**Cause:** Animated cursors with more than 24 frames exceed macOS system limits and require automatic downsampling.

**Solution:**
- Mousecape automatically downsamples animations with more than 24 frames
- The animation speed is preserved by adjusting frame duration
- If import still fails, ensure the file is not corrupted and try re-downloading

### Chinese Cursor Theme Display Issues

**Symptoms:** Chinese or other non-English cursor themes show garbled filenames or incorrect names.

**Cause:** INF file encoding not detected correctly.

**Solution:**
- Mousecape supports multiple encodings: UTF-8, UTF-16 LE/BE, GBK, GB18030, Big5, Shift_JIS, EUC-KR, ISO-8859-1
- Ensure the INF file is saved in a supported encoding
- If issues persist, try resaving the INF file as UTF-8

### Cursor Image Too Large

**Symptoms:** Large cursor images are rejected during import.

**Cause:** Image exceeds the maximum supported size of 512×512 pixels.

**Solution:**
- Resize images to 512×512 pixels or smaller before importing
- All imported images are automatically scaled to 64×64 pixels
- Images larger than 512×512 will be rejected with an error message

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

If you have questions or suggestions, please submit them on [GitHub Issues](https://github.com/sdmj76/Mousecape/issues).

## A Note from the Author

This is just a tool, and I've polished its UI. But what matters most is your cursor content :)

> *English version translated from Chinese by [Claude Code](https://claude.ai/code)*

---

<a id="chinese-section"></a>

# 中文

## 界面展示

<div align="center" style="display: flex; gap: 20px; justify-content: center; align-items: flex-start;">
  <img src="Screenshot/Home.gif" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit.gif" width="48%" style="height: auto;" />
</div>

> 截图中展示的光标主题 "Kiriko" 由 [ArakiCC](https://space.bilibili.com/14913641) 制作，在示例文件中提供。

## 功能特性

**系统要求：** macOS Sequoia (15) 或更高版本

- 自定义 Mac 系统光标，支持静态和动画光标
- 一键导入 Windows 格式指针（.cur / .ani）
- 使用私有、非侵入式的 CoreGraphics API，安全可靠
- 后台助手提供菜单栏图标，快速访问和光标管理
- 可选开机启动，自动应用光标主题

## 下载安装

在本 GitHub 页面的 [Releases](https://github.com/sdmj76/Mousecape/releases) 部分下载最新版本。

如果遇到问题，建议优先查看[故障排除](#Troubleshooting_cn)章节。

### 系统要求

- macOS Sequoia (15) 或更高版本
- 支持架构：同时支持 Intel 和 Apple Silicon Mac

## 示例光标

本仓库包含示例 Kiriko.cape 文件，可在[此处下载](Example/Kiriko.cape)。

**许可证：** CC BY-NC-ND 4.0（署名-非商业性-禁止演绎 4.0）

此光标由 [ArakiCC](https://space.bilibili.com/14913641) 制作。

查看许可证副本：https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh

## 快速开始

### 设置开机启动（可选，用于重启后自动应用光标）

1. 下载并打开 Mousecape 应用
2. 进入 **设置 → 通用**，开启 **Launch at Login**

开启后，MousecapeHelper 会在登录时后台启动并自动应用上次使用的光标主题。Helper 提供菜单栏图标，你可以通过它：
- 打开主 Mousecape 应用
- 应用或重置光标主题
- 退出 Helper

主 Mousecape 应用可以独立关闭，而 Helper 会继续在后台运行以维持你的光标主题。

### 导入 Windows 格式光标

Mousecape 支持批量导入 Windows 光标主题：

1. 下载的 Windows 光标包解压
2. 点击 "+" 按钮，选择"导入 Windows 光标"
3. 选择包含光标文件的文件夹导入即可

如果文件夹中包含 `*.inf` 文件，Mousecape 会自动解析该文件以正确映射光标类型。否则，将使用基于文件名的匹配。

### 创建自定义光标套装

1. 点击 "+" 按钮添加新光标套装
2. 点击 "+" 按钮添加要自定义的指针
3. 将图片或光标文件拖放到编辑窗口中
4. 调整热点位置和其他参数
5. 保存并应用你的主题

### 导入/导出 **.cape** 格式光标

- 点击 "导入" 按键，在弹出的finder窗口，选择要导入的 **.cape** 格式光标
- 或直接将 **.cape** 文件拖放到应用窗口即可导入
- 点击 "导出" 按键，在弹出的finder窗口，选择要保存 **.cape** 光标的位置

> **.cape** 为 Mousecape 专用光标格式，文件内包含了一整套光标的内容

### 重置系统光标

如果你想恢复为 macOS 默认光标，可以：

- 点击 **设置 → 重置为系统光标**
- 或使用快捷键 **Cmd+R**

### 支持的图片格式

- **常规图片格式**：PNG、JPEG、TIFF、GIF
- **Windows 光标格式**：.cur（静态）、.ani（动画）

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

<a id="Troubleshooting_cn"></a>

## 故障排除

如果遇到问题，请先查看以下常见解决方案。更多帮助请[提交 Issue](https://github.com/sdmj76/Mousecape/issues)。

### 从旧版本迁移

如果你之前安装过带有独立守护进程的旧版 Mousecape，新版本会在首次启动时自动注销旧的 `com.sdmj76.mousecloakhelper` LaunchAgent，无需手动操作。

如果旧守护进程仍在运行，可以手动移除：
```bash
launchctl bootout gui/$(id -u)/com.sdmj76.mousecloakhelper
```

### 光标动画仅在 Dock 区域生效

**症状**：自定义光标动画仅在悬停在 Dock 上时显示，移动到其他地方会恢复为系统默认光标。

**原因**：macOS 系统设置中的自定义指针颜色会阻止 Mousecape 成功应用全局光标。

**解决方案**：将系统指针颜色重置为默认设置：

1. 打开 **系统设置** → **辅助功能** → **显示**
2. 找到 **指针** 部分
3. 点击 **重设颜色** 按钮
4. 重新在 Mousecape 中应用光标主题

光标必须使用默认颜色方案（白色轮廓、黑色填充），Mousecape 才能正常工作。

### 动画光标导入失败

**症状**：动画光标文件（.ani 或 .gif）无法导入或被拒绝。

**原因**：超过 24 帧的动画光标超出了 macOS 系统限制，需要自动降采样。

**解决方案**：
- Mousecape 会自动对超过 24 帧的动画进行降采样
- 动画速度会通过调整帧时长来保持一致
- 如果仍然无法导入，请确保文件未损坏，尝试重新下载

### 中文光标主题显示乱码

**症状**：中文或其他非英文光标主题显示乱码或名称不正确。

**原因**：INF 文件编码检测不正确。

**解决方案**：
- Mousecape 支持多种编码：UTF-8、UTF-16 LE/BE、GBK、GB18030、Big5、Shift_JIS、EUC-KR、ISO-8859-1
- 确保 INF 文件使用支持的编码保存
- 如果问题持续，尝试将 INF 文件另存为 UTF-8 编码

### 光标图像过大

**症状**：大型光标图像在导入时被拒绝。

**原因**：图像超过了最大支持的 512×512 像素尺寸。

**解决方案**：
- 在导入前将图像调整为 512×512 像素或更小
- 所有导入的图像会自动缩放到 64×64 像素
- 超过 512×512 的图像将被拒绝并显示错误消息

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

如有问题或建议，欢迎在 [GitHub Issues](https://github.com/sdmj76/Mousecape/issues) 提出。

## 作者的话

这只是一个工具，我美化了它的UI。但最重要的还是你的光标内容 :)
