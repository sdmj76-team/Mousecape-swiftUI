**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

### v1.1.0 - Major Architecture Update

**This is a major update that improves launch-at-login functionality and reduces file sizes.**

**New Features:**

- **Rewritten Background Helper** — Launch-at-login helper has been completely rewritten with a menu bar icon
  - Menu bar quick access shows your currently applied cursor theme name
  - Quick actions: "Apply Cursor", "Reset Cursor", and "Open Mousecape"
  - More reliable startup behavior and better system integration

- **Improved Windows Cursor Conversion** — Significantly expanded cursor type mapping
  - Now maps 44 out of 52 macOS cursor types (85% coverage, up from 20 types in previous versions)
  - Most previously unmapped cursors now work correctly after import
  - Better compatibility with Windows cursor themes

- **Simple/Advanced Modes** — Choose your editing and preview style
  - **Edit Mode:** Switch between Simple (15 Windows cursor groups) and Advanced (52 individual macOS cursor types)
    - Simple Mode: Edit one cursor and automatically apply to all related cursor types
    - Advanced Mode: Full control over each individual cursor type
    - Switch anytime via the toolbar
  - **Preview Mode:** Choose how cursors are displayed on the home screen
    - Simple Mode: Shows one cursor per group (15 main cursors) with localized names
    - Advanced Mode: Shows all cursors in the cape
    - Configure in Settings > Appearance > Preview Panel

- **Double-click to Open** — Double-click `.cape` files in Finder to open them directly in Mousecape

- **Cape File Format 3.0** — Cape files now use HEIF image format, reducing file size by 60%
  - **Compatibility Note:** Older versions of Mousecape may not be able to open cape files saved with v1.1.0. We recommend updating to the latest version.
  - Existing cape files will continue to work and will be automatically upgraded to the new format when saved

**Improvements:**

- Faster command-line tool performance (~80% faster than before)
- Better memory management and stability
- Improved thread safety for smoother operation
- Cleaner project configuration

**Bug Fixes:**

- Fixed various UI navigation issues
- Fixed cursor state synchronization between main app and helper
- Fixed security vulnerabilities
- Improved compatibility with future macOS versions

**Technical Notes:**

- The old `mousecloakhelper` daemon is automatically removed on first launch
- If you encounter any issues with launch-at-login, try toggling the setting off and on again in Settings

---

### v1.0.4 - Features & Critical Fix

**New Features:**

- Drag-and-drop sorting — reorder your cursor themes by dragging them in the sidebar
- Drag-and-drop import — drop `.cape` files directly onto the app window to import
- Added "Reset System Cursor" button in Settings (also available via Cmd+R)
- Language now follows your system settings automatically, no more manual switching
- Reorganized menu bar for a cleaner layout
- Auto-rename duplicate cape names on import
- Success notifications for import and export operations

**Optimizations:**

- Smoother cursor zoom preview animation
- Windows cursor conversion is now ~2x faster
- Saved cursor scale is now applied on app startup

**Critical Fix:**

- **Fixed animated cursor frames bleeding into each other during import** — if you previously imported Windows animated cursors and noticed visual glitches, this is the fix. **We recommend re-importing affected cursors after updating!**

**Other Bug Fixes:**

- Improved compatibility with more Windows animated cursor (.ani) files
- Fixed GIF animation playing at wrong speed after import
- Fixed animated cursor frames rendering incorrectly
- Fixed applied cursor theme not being detected on app startup
- Fixed various UI navigation and animation glitches
- Internal code quality improvements for better stability and future macOS compatibility

**Removed:**

- Windows cursor import now requires an INF file in the folder (filename-based guessing has been removed for better accuracy)

**PS: This project does not provide support for `any non-compliant third-party cursors`. If you encounter any of these issues, please contact the cursor author for assistance.**

---

### v1.0.3 - Bug Fix

**This update fixes Windows animated cursor import issues and improves encoding support.**

**Bug Fixes:**

- Fixed animated cursor (.ani) files being rejected due to incorrect size validation
- Fixed multi-frame animated cursors (94, 140, 206 frames) not being imported properly
- Fixed GBK encoding detection for Chinese Windows cursor themes

**Improvements:**

- Automatic downsampling now works correctly for all animated cursors with >24 frames
- Multi-encoding support for INF files: UTF-8, UTF-16 LE/BE, GBK, GB18030, Big5, Shift_JIS, EUC-KR, ISO-8859-1
- Cleaner code: removed redundant validation that served no purpose

**PS: This project does not provide support for `any non-compliant third-party cursors`. If you encounter any of these issues, please contact the cursor author for assistance.**

---

### v1.0.2 - Bug Fixes

**This update focuses on fixing bugs and improving stability.**

**Bug Fixes:**

- Fixed GIF animation import that wasn't working before
- Fixed issues where imported Windows cursors wouldn't apply correctly
- Fixed crashes that could happen when importing certain cursor files
- Fixed a problem where the helper tool might stop working after updating the app
- Fixed animation playback speed being incorrect when importing GIF or ANI files
- Added hotspot validation on import to ensure accurate cursor positioning

**Improvements:**

- Improved compatibility with Windows cursor themes
- Added memory protection to prevent crashes when importing large cursor files (max 4096×4096 pixels)
- Faster CI builds
- (Debug build) Optimized log file cleanup with 100MB total size limit

---

### v1.0.1 - Native Windows Cursor Conversion

**Major Update: Windows cursor conversion rewritten from Python to native Swift**

- Replaced external Python script with pure Swift implementation
- No longer requires bundled Python runtime, unified into single version (previously Premium version included Python)
- Significantly reduced app size (from ~50MB to ~5MB)
- Faster conversion speed with optimized performance
- Improved parsing reliability for .cur and .ani formats

**New Features:**

- Add Windows install.inf parser for automatic cursor type mapping
- Add support for legacy Windows cursor formats (16-bit RGB555/RGB565, 8-bit/4-bit/1-bit indexed, RLE compression)
- Add transparent window toggle in appearance settings
- Add GitHub Actions CI workflow for automated builds

**Improvements:**

- Backport to macOS 15 Sequoia with adaptive styling (Liquid Glass on macOS 26, Material on macOS 15)
- Convert mousecloak helper to ARC (Automatic Reference Counting) for better memory management
- Fix transparent window background for dark mode

**Bug Fixes:**

- Fixed memory alignment crash when parsing certain cursor files
- Fixed cape rename error when saving imported cursors
- Fixed dark mode transparent window showing washed-out colors

---

### v1.0.0 - SwiftUI Redesign for macOS Tahoe

> **Important:** This version requires **macOS Tahoe (26)** or later.

**UI:**

- Completely rebuilt the interface using SwiftUI, fully embracing the new Liquid Glass design language
- Added enlarged cursor preview on the home screen for better visibility
- Replaced TabView with page-based navigation and improved toolbar layout
- Full Dark Mode support with automatic system appearance switching
- Added localization support with Chinese language option

**Features:**

- Windows cursor import (Premium version only): One-click import from Windows cursor files
  - Supports `.cur` (static) and `.ani` (animated) formats
  - Automatically detects frame count and imports hotspot information
- Unified cursor size to 64px × 64px for consistency
- Updated CoreGraphics API for macOS Tahoe compatibility
- Improved helper daemon with better session change handling

**Other:**

- Removed Sparkle update framework (updates now via GitHub Releases)
- Cleaned up legacy Objective-C code and unused assets
- Fixed multiple UI display and preview issues
- Fixed edit function stability
- Security vulnerability fixes

---

### Known Limitations

Due to macOS system limitations, Mousecape has the following restrictions:

- **Image Size:** Maximum import size is 512×512 pixels. All images are automatically scaled to 64×64 pixels.
- **Animation Frames:** Maximum 24 frames per animated cursor. Animations with more frames are automatically downsampled.

---

### Version Selection Guide

The Debug version has no functional differences from the regular version, it only includes logging for error tracking.
For normal use, download the regular version.

<a id="中文"></a>

## 中文

### v1.1.0 - 重大架构更新

**这是一次重大更新，改进了开机启动功能并大幅减小文件体积。**

**新功能：**

- **重写后台助手** — 开机启动助手已完全重写，带有菜单栏图标
  - 菜单栏快速访问可查看当前应用的光标主题名称
  - 快速操作："应用光标"、"重置光标"和"打开 Mousecape"
  - 更可靠的启动行为和更好的系统集成

- **改进 Windows 光标转换** — 大幅扩展光标类型映射
  - 现在映射 52 个 macOS 光标类型中的 44 个（85% 覆盖率，旧版仅 20 个）
  - 大部分之前不生效的光标现在导入后可以正常工作
  - 更好的 Windows 光标主题兼容性

- **简易/高级模式** — 选择你的编辑和预览方式
  - **编辑模式：** 在简易模式（15 个 Windows 光标分组）和高级模式（52 个独立 macOS 光标类型）之间切换
    - 简易模式：编辑一个光标后自动应用到所有相关光标类型
    - 高级模式：完全控制每个独立的光标类型
    - 随时通过工具栏切换
  - **预览模式：** 选择首页光标的显示方式
    - 简易模式：每组显示一个代表光标（15 个主要光标），使用本地化名称
    - 高级模式：显示 Cape 中所有光标
    - 在设置 > 外观 > 预览面板中配置

- **双击打开** — 在访达中双击 `.cape` 文件即可直接在 Mousecape 中打开

- **Cape 文件格式 3.0** — Cape 文件现在使用 HEIF 图像格式，文件体积减少 60%

  - **兼容性说明：** 旧版本的 Mousecape 可能无法打开使用 v1.1.0 保存的 cape 文件。建议更新到最新版本。
  - 现有的 cape 文件可以继续使用，保存时会自动升级到新格式

**改进：**

- 命令行工具性能提升约 80%
- 更好的内存管理和稳定性
- 改进线程安全性，运行更流畅
- 更清晰的项目配置

**Bug 修复：**

- 修复多个界面导航问题
- 修复主应用和助手之间的光标状态同步
- 修复安全漏洞
- 改进与未来 macOS 版本的兼容性

**技术说明：**

- 旧的 `mousecloakhelper` 守护进程会在首次启动时自动移除
- 如果遇到开机启动问题，尝试在设置中关闭再打开该选项

---

### v1.0.4 - 功能更新 & 重大修复

**新功能：**

- 拖拽排序 — 在侧边栏拖动即可调整光标主题的顺序
- 拖拽导入 — 直接将 `.cape` 文件拖到窗口即可导入
- 设置页新增"重置为系统光标"按钮（也可通过 Cmd+R 快捷键使用）
- 语言现在自动跟随系统设置，无需手动切换
- 重新整理了菜单栏布局，更加清晰
- 导入时自动重命名重复的 Cape 名称
- 导入和导出操作完成后会显示成功通知

**优化：**

- 光标放大预览动画更流畅
- Windows 光标转换速度提升约 2 倍
- 启动时自动应用已保存的光标缩放比例

**重大修复：**

- **修复动画光标导入后帧画面互相渗透的问题** — 如果你之前导入的 Windows 动画光标出现画面错乱，就是这个问题。**建议更新后重新导入受影响的光标！！！**

**其他 Bug 修复：**

- 提升了对更多 Windows 动画光标（.ani）文件的兼容性
- 修复 GIF 动画导入后播放速度不正确的问题
- 修复动画光标帧渲染错误
- 修复启动时无法检测到已应用的光标主题
- 修复多个界面导航和动画问题
- 内部代码质量改进，提升稳定性和未来 macOS 版本兼容性

**移除：**

- Windows 光标导入现在必须包含 INF 文件（移除了基于文件名的猜测匹配，提高准确性）

**PS：本项目不会提供对 `任何不符合规范的第三方光标` 提供支持，如有以上问题，麻烦联系光标作者解决**

---

### v1.0.3 - Bug 修复

**本次更新修复了 Windows 动画光标导入问题，并改进了编码支持。**

**Bug 修复：**

- 修复了动画光标 (.ani) 文件因尺寸验证错误而被拒绝的问题
- 修复了多帧动画光标（94、140、206 帧）无法正确导入的问题
- 修复了中文 Windows 光标主题的 GBK 编码检测问题

**改进：**

- 自动降采样现在对所有超过 24 帧的动画光标都能正常工作
- INF 文件多编码支持：UTF-8、UTF-16 LE/BE、GBK、GB18030、Big5、Shift_JIS、EUC-KR、ISO-8859-1
- 代码更简洁：移除了没有实际作用的冗余验证

**PS：本项目不会提供对 `任何不符合规范的第三方光标` 提供支持，如有以上问题，麻烦联系光标作者解决**

---

### v1.0.2 - Bug 修复

**本次更新主要修复了若干 bug 并提升稳定性。**

**Bug 修复：**

- 修复了 GIF 动画导入无法正常工作的问题
- 修复导入的 Windows 光标无法正确应用的问题
- 修复导入某些光标文件时可能崩溃的问题
- 修复更新应用后辅助工具可能失效的问题
- 修复导入 GIF 或 ANI 文件时动画播放速度不正确的问题
- 热点验证导入，确保光标位置准确

**改进：**

- 改进与 Windows 光标主题的兼容性
- 添加内存保护，防止导入大型光标文件时崩溃（最大 4096×4096 像素）
- 加快 CI 构建速度
- （Debug版）优化日志文件清理，总大小限制 100MB

---

### v1.0.1 - 原生 Windows 光标转换

**重大更新：Windows 光标转换从 Python 重写为原生 Swift**

- 使用纯 Swift 实现替代外挂 Python 脚本
- 不再需要内置 Python 环境，统一为单一版本（此前 Premium 版本内置 Python）
- 大幅减小应用体积（从约 50MB 降至约 5MB）
- 优化性能，转换速度更快
- 提升 .cur 和 .ani 格式的解析可靠性

**新功能：**

- 添加 Windows install.inf 解析器，自动识别光标类型映射
- 支持旧版 Windows 光标格式（16 位 RGB555/RGB565、8/4/1 位索引色、RLE 压缩）
- 在外观设置中添加透明窗口开关
- 添加 GitHub Actions CI 工作流，实现自动化构建

**改进：**

- 向下兼容 macOS 15 Sequoia，支持自适应样式（macOS 26 使用液态玻璃，macOS 15 使用 Material）
- 将 mousecloak 辅助程序转换为 ARC（自动引用计数），改善内存管理
- 修复深色模式下透明窗口背景

**Bug 修复：**

- 修复解析某些光标文件时的内存对齐崩溃问题
- 修复导入光标保存时的 cape 重命名错误
- 修复深色模式透明窗口显示颜色失真问题

---

### v1.0.0 - SwiftUI 重构，适配 macOS Tahoe

> **重要提示：** 此版本需要 **macOS Tahoe (26)** 或更高版本。

**界面：**

- 使用 SwiftUI 完全重写界面，全面适配全新的液态玻璃设计语言
- 主页新增放大光标预览功能，预览更清晰
- 使用分页式导航替代 TabView，优化工具栏布局
- 完整支持深色模式，自动跟随系统外观切换
- 新增本地化支持，支持中文界面

**功能：**

- Windows 光标导入（仅限 Premium 版本）：一键从 Windows 光标文件导入
  - 支持 `.cur`（静态）和 `.ani`（动态）格式
  - 自动识别帧数并导入热点信息
- 光标尺寸统一为 64px × 64px，保持一致性
- 更新 CoreGraphics API 以支持 macOS Tahoe
- 改进守护进程，优化会话变化处理

**其他：**

- 移除 Sparkle 更新框架（现通过 GitHub Releases 更新）
- 清理遗留的 Objective-C 代码和未使用的资源
- 修复多个界面显示和预览问题
- 修复编辑功能稳定性问题
- 安全漏洞修复

---

### 已知限制

由于 macOS 系统限制，Mousecape 有以下限制：

- **图像尺寸：** 最大导入尺寸为 512×512 像素。所有图像会自动缩放到 64×64 像素。
- **动画帧数：** 每个动画光标最多 24 帧。超过此帧数的动画会自动降采样。

---

### 版本选择建议

Debug版本与普通版本无功能上的差异，只是加入了日志记录功能用于记录错误。
正常使用时，下载普通版本即可。

---

## Credits | 致谢

- **Original Author | 原作者:** @AlexZielenski (2013-2025)
- **SwiftUI Redesign | SwiftUI 重构:** @sdmj76 (2025)
- **Coding Assistant | 编程协助:** Claude Code (Opus)
