**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

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

## Important!!!

### Before installing the new version, please uninstall the `Helper Tool` in the old version first to avoid compatibility issues

## A Note from the Author

This project was originally just modified for my own use, but I didn't expect it to receive so many stars after release. Thank you all for your support!
Since I've been maintaining it alone (being lazy), I will slow down the update frequency after this version.
I will only release updates if there are major bugs or new features. As for suggestions for new features, pull requests are welcome; I will check them periodically.
I recently discovered a rather interesting `Wallpaper Engine for Mac` project next door, and I'm currently researching it there.

---

<a id="中文"></a>

## 中文

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

## 强烈建议！！！

### 覆盖安装新版本前，为避免兼容问题，麻烦先在旧版本内卸载 `辅助工具` ，再安装新版本

## 作者的话

这个项目本来只是改来自己使用，没想到发出来以后收获了这么多 Star，感谢大家的支持！
由于一直都是我（懒狗）独自维护，发布完这个版本以后，我将放缓更新频率。
如出现重大bug或新功能，我才会发布更新。至于新功能建议，也欢迎提 PR，我将不定期查看。
最近在隔壁发现个 `Wallpaper Engine for Mac` 项目挺有意思的，目前在那边研究。

---

## Credits | 致谢

- **Original Author | 原作者:** Alex Zielenski (2013-2025)
- **SwiftUI Redesign | SwiftUI 重构:** sdmj76 (2025)
- **Coding Assistant | 编程协助:** Claude Code (Opus)
