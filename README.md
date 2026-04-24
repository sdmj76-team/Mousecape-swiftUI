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
English | [中文](README_zh.md)
</div>

---

## Interface Display

<div align="center" style="display: flex; gap: 20px; justify-content: center; align-items: flex-start;">
  <img src="Screenshot/Home_en_lg.gif#gh-light-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit_en_lg.gif#gh-light-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Home_en_dk.gif#gh-dark-mode-only" width="48%" style="height: auto;" />
  <img src="Screenshot/Edit_en_dk.gif#gh-dark-mode-only" width="48%" style="height: auto;" />
</div>

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
- Support Architectures: runs on both Intel and Apple Silicon Macs (Universal Binary)

> **Note:** The Debug version only includes the architecture of the build machine and may not run on all Macs. For normal use, please download the regular (Release) version.

Download the latest version from the [Releases](https://github.com/sdmj76/Mousecape-swiftUI/releases) section of this GitHub page.

If you encounter any problems, we recommend that you first check the [Troubleshooting](#troubleshooting) section.

## Example Cursors

Example cursors are located in the `Example/` directory, including the following:

**Kiriko.cape**: Created by [ArakiCC](https://space.bilibili.com/14913641), licensed under CC BY-NC-ND 4.0 (Attribution-NonCommercial-NoDerivs 4.0)

**Default_macOS 15.cape**: Default cursors extracted from macOS 15 system

**Default_macOS 26.cape**: Default cursors extracted from macOS 26 system

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

### Supported Image Formats

- **Standard image formats**: PNG, JPEG, TIFF, GIF
- **Windows cursor formats**: .cur (static), .ani (animated)

## Troubleshooting

If you encounter issues, please check the common solutions below first. For more help, please [submit an Issue](https://github.com/sdmj76/Mousecape-swiftUI/issues).

> **Due to macOS system limitations, Mousecape has the following restrictions:**
>
> *Image Size Limit*
>
> - Maximum import size: **512×512 pixels** (larger images will be rejected)
> - All cursor images are automatically scaled to **64×64 pixels** at 1x resolution
> - If the imported image is larger than 64×64 (up to 512×512), it will be automatically scaled down
> - If the imported image is smaller than 64×64, it will be scaled up (may result in lower quality)
>
> *Animation Frame Limit*
>
> - Maximum **24 frames** per animated cursor
> - Animated cursors with more than 24 frames will be automatically downsampled
> - The downsampling preserves animation timing by adjusting frame duration
>
> *Example:* A 32-frame GIF animation will be downsampled to 24 frames, and the frame duration will be increased to maintain the original animation speed.

<br>
<details>
<summary>Cursor Not Working in Some Apps</summary>

**Symptoms:** Cursor does not take effect inside certain app windows, such as Terminal or Excel.

**Cause:** Some apps configure their own custom cursors, which override the system cursor settings.

**Solution:** There is currently no safe workaround. This issue only occurs in certain apps and has limited impact.

</details>
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
