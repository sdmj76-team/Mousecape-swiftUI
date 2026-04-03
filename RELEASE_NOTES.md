**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

### v1.1.1 - Language Expansion

**New Features:**

- **Multi-Language Support** — Added 4 new languages with AI-powered translation
  - Japanese (日本語)
  - Korean (한국어)
  - German (Deutsch)
  - French (Français)
  - All translations reviewed for accuracy and natural phrasing

**Improvements:**

- Further optimization for macOS 26 Liquid Glass effect — all overlays, loading indicators, drag feedback, zoom preview, and selection highlights now use native glass effects
- Optimized left-hand mode: diagonal resize cursors now excluded from mirroring for better usability
- Improved settings synchronization and preference handling

**Bug Fixes:**

- Fixed duplicate preference read methods
- Fixed CFPreferences synchronization warnings

---

### v1.1.0 - Architecture Update

**A major update with improved launch-at-login, smaller file sizes, easier editing, and a polished new look.**

**What's New:**

- **New App Icon** — Redesigned with a liquid glass effect that matches macOS 26's design language

- **Menu Bar Quick Access** — Enable "Launch at Login" in settings to get a menu bar icon
  - See your current cursor theme at a glance
  - Quick actions: Apply cursor, Reset cursor, Open Mousecape
  - More reliable startup experience

- **Better Windows Cursor Support** — Import Windows cursor themes with better accuracy
  - Now supports 85% of macOS cursor types (up from 40%)
  - Most cursors will work correctly after importing

- **Simple & Advanced Editing Modes** — Choose how you want to edit
  - **Simple Mode:** Edit in groups (like Windows), changes apply to related cursors automatically
  - **Advanced Mode:** Fine-tune each cursor individually
  - **Preview Mode:** Choose how many cursors to show on the home screen
  - Switch anytime via the toolbar

- **Double-Click to Open** — Double-click any `.cape` file in Finder to open it

- **Smaller File Sizes** — Cursor files are now 60% smaller

- **Export System Cursors** — Back up your original Mac cursors
  - Find it in Settings > Advanced > Reset, or in the File menu

- **Better Import/Export Warnings** — See what's wrong and choose to continue or cancel

- **Left-Hand Mode** — Switch to left-hand cursor layout in Settings > General
  - Mirrors all cursors horizontally for left-handed users
  - Preview and system cursors both flip instantly when toggled

**Improvements:**

- Faster performance and better stability
- More reliable cursor application
- Compatible with future macOS versions

**Bug Fixes:**

- Fixed Windows cursor transparency rendering — thin lines and edges now look crisp and correct
- Fixed cursor application not working when some cursors were missing
- Fixed menu bar helper stability issues
- Fixed various UI glitches
- Updated documentation links to point to the correct project repository

**Note:** Older versions of Mousecape may not open files saved with v1.1.0. We recommend updating to the latest version.

The transparent window toggle feature has been removed to simplify the codebase.

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

### v1.1.1 - 语言扩展

**新功能：**

- **多语言支持** — 新增 4 种语言，由 AI 辅助翻译
  - 日语（日本語）
  - 韩语（한국어）
  - 德语（Deutsch）
  - 法语（Français）
  - 所有翻译均经过准确性和自然度审核

**改进：**

- 进一步适配 macOS 26 液态玻璃效果 — 所有叠加层、加载指示器、拖放反馈、放大预览、选中高亮等均采用原生玻璃效果
- 优化左手模式：对角线调整光标不再镜像翻转，提升易用性
- 改进设置同步和偏好设置处理

**Bug 修复：**

- 修复重复的偏好设置读取方法
- 修复 CFPreferences 同步警告

---

### v1.1.0 - 架构更新

**改进开机启动、文件体积更小、编辑更方便、界面更精致的一次重大更新。**

**新功能：**

- **全新应用图标** — 采用液态玻璃效果重新设计，完美契合 macOS 26 设计语言

- **菜单栏快速访问** — 在设置中开启"开机自动应用"后，会显示菜单栏图标
  - 一眼看到当前使用的光标主题
  - 快速操作：应用光标、重置光标、打开 Mousecape
  - 启动更可靠

- **更好的 Windows 光标支持** — 导入 Windows 光标主题更准确
  - 现在支持 85% 的 macOS 光标类型（之前只有 40%）
  - 导入后大部分光标都能正常工作

- **简易/高级编辑模式** — 选择适合你的编辑方式
  - **简易模式：** 按分组编辑（像 Windows 一样），自动应用到相关光标
  - **高级模式：** 单独精细调整每个光标
  - **预览模式：** 选择首页显示多少光标
  - 随时通过工具栏切换

- **双击打开** — 在访达中双击任何 `.cape` 文件即可打开

- **文件体积更小** — 光标文件现在体积减少了 60%

- **导出系统光标** — 备份你的 Mac 原始光标
  - 在 设置 > 高级 > 重置 中找到，或在文件菜单中

- **更好的导入/导出提示** — 显示问题并让你选择继续或取消

- **左手模式** — 在 设置 > 通用 中切换光标方向
  - 所有光标水平翻转，适合左手用户
  - 预览和系统光标切换后立即生效

**改进：**

- 性能更快，运行更稳定
- 光标应用更可靠
- 兼容未来的 macOS 版本

**Bug 修复：**

- 修复 Windows 光标透明度渲染问题，细线和边缘现在显示清晰锐利
- 修复某些光标缺失时无法应用的问题
- 修复菜单栏助手的稳定性问题
- 修复多个界面显示问题
- 更新文档链接到正确的项目仓库

**注意：** 旧版 Mousecape 可能无法打开 v1.1.0 保存的文件，建议更新到最新版本。

透明窗口切换功能已移除，以简化代码库。

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
