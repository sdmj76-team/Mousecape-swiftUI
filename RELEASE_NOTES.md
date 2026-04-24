### v1.1.3 - New Navigation & Quick Look

**What's New:**

- **Quick Look Support** — Preview `.cape` cursor files directly in Finder
  - Press Space to preview any cape file without opening the app
  - File thumbnails show cursor previews in Finder icon view
- **New Tab Navigation** — Redesigned navigation with Home, Edit, and Settings tabs
  - Edit tab appears automatically when a cape is selected
  - Cleaner layout with less clutter
- **Unified Display Mode** — "Modern" and "Classic" modes now controlled from one place in Settings > Appearance
  - Replaces the old "Simple/Advanced" naming
  - One setting controls both the edit page and home preview

**Improvements:**

- Smoother cursor reapply — switching users or waking from sleep no longer causes a brief cursor flash
- Auto-selects the currently applied cape on app startup

**Bug Fixes:**

- Fixed cursor selection being lost when switching display modes

---

### v1.1.2 - Stability & Polish

**What's New:**

- **Toast Notifications** — Success messages now appear as elegant toast notifications instead of modal alerts
  - Apply cursor, reset cursor, import/export operations show quick feedback
  - Error messages still use alerts to ensure you see them
  - Matches macOS 26's notification style

**Improvements:**

- **Better Image Quality** — Small cursor images now look sharper when imported
- **Loading Indicators** — Cape import and export operations now show progress overlays, no more frozen UI
- **Reorganized Menus** — "Reset to Default" moved to File menu for easier access

**Bug Fixes:**

- Extract Current Cursors should now work properly
- Fixed cursor extraction capturing scaled versions instead of originals
- Fixed potential thread safety issues in log file writing
- Fixed deprecated color space warnings

---

### v1.1.1 - Language Expansion

**New Features:**

- **Multi-Language Support** — Added 4 new languages with AI-powered translation
  - Japanese (日本語)
  - Korean (한국어)
  - German (Deutsch)
  - French (Français)
  - All translations reviewed for accuracy and natural phrasing

**Improvements:**

- **Decoupled menu bar icon visibility from Helper lifecycle** — Helper (MousecapeHelper) now always runs in the background for session monitoring. The "Show Menu Bar Tool" toggle now only controls the menu bar icon visibility, no longer starting or stopping the Helper process
  - Menu bar icon visibility syncs in real-time via `CFPreferences` + `DistributedNotificationCenter` cross-process communication
  - Added `MenuBarState` observable class for reactive icon visibility control
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