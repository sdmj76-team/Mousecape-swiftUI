**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

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
