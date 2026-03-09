# Mousecape Technical Architecture

This document provides a detailed explanation of Mousecape's underlying mechanisms, including private API discovery, cursor registration, animation implementation, and other core technologies.

**[中文版本 / Chinese Version](#mousecape-技术架构文档)**

## Table of Contents

- [Private API Overview](#private-api-overview)
- [Why SIP Doesn't Need to Be Disabled](#why-sip-doesnt-need-to-be-disabled)
- [Cursor Registration Mechanism](#cursor-registration-mechanism)
- [Animated Cursor Implementation](#animated-cursor-implementation)
- [Multi-Display Support](#multi-display-support)
- [Multi-User Support](#multi-user-support)
- [Component Responsibilities](#component-responsibilities)
- [Risks and Limitations](#risks-and-limitations)
- [Security Analysis](#security-analysis)

---

## Private API Overview

### Public API vs Private API

| Feature | Public API | Private API |
|---------|-----------|-------------|
| Documentation | Officially documented by Apple | No official documentation |
| Stability | Stability guaranteed | May change at any time |
| App Store | Allowed | Prohibited |
| Examples | `NSCursor`, `CGImage` | `CGSRegisterCursorWithImages()` |

### How Private APIs Were Discovered

The private APIs used by Mousecape were discovered through:

1. **Reverse Engineering**
   - Project author Alex Zielenski reverse-engineered the core cursor APIs on macOS Lion 10.7.3
   - Header comment: `Cursor APIs reversed by Alex Zielenski on Lion 10.7.3`

2. **Community Collaboration**
   - Joe Ranieri discovered some APIs in 2008 (Leopard era)
   - Developer community shared reverse engineering findings

3. **Specific Discovery Techniques**

   | Technique | Description |
   |-----------|-------------|
   | `nm` / `otool` | List exported symbols from dynamic libraries |
   | `class-dump` | Extract Objective-C class and method information |
   | Disassemblers | Hopper, IDA Pro, Ghidra for analyzing function signatures |
   | Runtime debugging | `lldb` or `dtrace` to observe system calls |
   | String searching | Search for function names in binaries |

### Core Private APIs

Located in `mousecloak/CGSInternal/CGSCursor.h`:

```objc
// Register custom cursor (core API)
CGSRegisterCursorWithImages(
    CGSConnectionID cid,      // Connection to WindowServer
    char *cursorName,         // Cursor identifier
    bool setGlobally,         // Apply globally
    bool instantly,           // Apply immediately
    CGSize cursorSize,        // Cursor size
    CGPoint hotspot,          // Hotspot position
    NSUInteger frameCount,    // Animation frame count
    CGFloat frameDuration,    // Duration per frame
    CFArrayRef imageArray,    // Image array
    int *seed                 // Output: cursor seed value
);

// Reset all cursors to system defaults
CoreCursorUnregisterAll(CGSConnectionID cid);

// Read current cursor data
CGSCopyRegisteredCursorImages(...);

// Get connection to WindowServer
CGSMainConnectionID();
```

---

## Why SIP Doesn't Need to Be Disabled

### Key Point: Modifying Memory, Not Files

Mousecape **does not modify** any system files. It uses a completely different mechanism:

```
┌─────────────────────────────────────────────────────────────┐
│                    WindowServer Process                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Cursor Registry (in memory)             │   │
│  │  ┌──────────────────┬──────────────────────────┐   │   │
│  │  │ Cursor Name      │ Image Data               │   │   │
│  │  ├──────────────────┼──────────────────────────┤   │   │
│  │  │ Arrow            │ System Default → Custom  │   │   │
│  │  │ IBeam            │ System Default → Custom  │   │   │
│  │  │ Wait             │ System Default → Custom  │   │   │
│  │  └──────────────────┴──────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ Mach IPC (Inter-Process Communication)
         │
┌────────┴────────┐
│   Mousecape     │
│ CGSRegisterCursor│
│   WithImages()  │
└─────────────────┘
```

### SIP Protection Scope Comparison

| What SIP Protects | Mousecape's Actions |
|-------------------|---------------------|
| Files under `/System` directory | ❌ Not touched |
| System kernel extensions | ❌ Not touched |
| System framework binaries | ❌ Not touched |
| WindowServer runtime memory | ✅ Modified via API |

**Key difference**: SIP protects **files on disk**, not **runtime memory state**.

### Why Is This Allowed?

```
┌────────────────────────────────────────────────┐
│  macOS Security Model                          │
├────────────────────────────────────────────────┤
│  1. Any GUI app needs a CGSConnection          │
│  2. Cursor registration is normal WindowServer │
│     functionality                              │
│  3. This is a designed IPC mechanism, not a    │
│     vulnerability                              │
│  4. Reverts after restart (non-persistent)     │
└────────────────────────────────────────────────┘
```

Apple likely designed these APIs for:
- Allowing applications to create custom cursors (e.g., brush cursor in drawing apps)
- Accessibility needs (enlarged cursors, etc.)
- System component use (Dock, etc.)

### Analogy

| Concept | Analogy |
|---------|---------|
| SIP | Locked toolbox (system files) |
| WindowServer | Running machine (accepts commands) |
| CGSRegisterCursor | Command to "swap a part" |
| Mousecape | Operator (legitimately sending commands) |

---

## Cursor Registration Mechanism

### Registration Flow

```
User clicks "Apply Cape"
       │
       ▼
┌─────────────────┐
│   Mousecape     │──── Calls CGSRegisterCursorWithImages()
│   (GUI App)     │     Registers all cursors to WindowServer
└─────────────────┘
       │
       │ After registration completes...
       ▼
┌─────────────────┐
│  Can exit app   │     ← Mousecape doesn't need to keep running!
└─────────────────┘

       ║
       ║  Cursor data exists in WindowServer memory
       ▼

┌─────────────────────────────────────────────────────────────┐
│                    WindowServer (System Process)             │
│                                                             │
│  Keeps running, automatically renders cursors               │
│  Until: logout / restart / reset called                     │
└─────────────────────────────────────────────────────────────┘
```

### Core Code

```objc
// apply.m
static BOOL MCRegisterImagesForCursorName(...) {
    CGError err = CGSRegisterCursorWithImages(
        CGSMainConnectionID(),  // Get current process connection
        cursorName,             // e.g., "com.apple.coregraphics.Arrow"
        true,                   // setGlobally - apply globally
        true,                   // instantly - apply immediately
        size,                   // Cursor size
        hotSpot,                // Hotspot position
        frameCount,             // Frame count
        frameDuration,          // Frame duration
        (__bridge CFArrayRef)images,  // Image array
        &seed
    );
    return (err == kCGErrorSuccess);
}
```

### Special Cursor Handling

Some cursors have multiple aliases on newer macOS versions and need to be registered simultaneously:

```objc
// Arrow cursor synonyms
@"com.apple.coregraphics.Arrow"
@"com.apple.coregraphics.ArrowCtx"

// IBeam cursor synonyms
@"com.apple.coregraphics.IBeam"
@"com.apple.coregraphics.IBeamXOR"
```

---

## Animated Cursor Implementation

### Principle: Sprite Sheet + Frame Animation

Animated cursors use vertically arranged sprite sheets:

```
┌────────────────────────────────────────────────────────────────┐
│                    Single Sprite Sheet (Vertical)              │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────┐                                                  │
│  │ Frame 1  │  ← Frame 0                                       │
│  ├──────────┤                                                  │
│  │ Frame 2  │  ← Frame 1                                       │
│  ├──────────┤                                                  │
│  │ Frame 3  │  ← Frame 2                                       │
│  ├──────────┤                                                  │
│  │  ...     │                                                  │
│  ├──────────┤                                                  │
│  │ Frame N  │  ← Frame N-1                                     │
│  └──────────┘                                                  │
│                                                                │
│  Image height = Single frame height × frameCount               │
└────────────────────────────────────────────────────────────────┘
```

### API Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `frameCount` | Animation frame count (1-24) | 8 frames |
| `frameDuration` | Duration per frame (seconds) | 0.1s = 10 FPS |
| `imageArray` | Sprite sheet array (different scales) | 1x, 2x, 5x, 10x |
| `size` | **Single frame** size | 32×32 points |

### Frame Count Limit

```objc
if (frameCount > 24 || frameCount < 1) {
    MMLog("Frame count out of range [1...24]");
    return NO;
}
```

**Maximum 24 frames** — This is a hard limit from WindowServer.

### Animation Playback Flow

```
WindowServer Internal
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Saved during registration:
┌─────────────────────────┐
│ Cursor: "Wait"          │
│ Sprite: [1x, 2x, 5x]    │
│ Frames: 8               │
│ Duration: 0.1s          │
└─────────────────────────┘
        │
        ▼
Automatic switching during playback:
┌─────────────────────────┐
│ Time 0.0s → Show frame 0│
│ Time 0.1s → Show frame 1│
│ Time 0.2s → Show frame 2│
│ ...                     │
│ Time 0.7s → Show frame 7│
│ Time 0.8s → Loop to 0   │
└─────────────────────────┘
```

**Animation playback is entirely handled by WindowServer** — the app only needs to register once.

### Static vs Animated Cursor Comparison

| Type | frameCount | frameDuration | Sprite Sheet |
|------|-----------|---------------|--------------|
| Static (Arrow) | 1 | 0 | Single frame |
| Animated (Wait) | 8-24 | 0.05-0.2 | Vertically concatenated frames |

---

## Multi-Display Support

### Cursor Moving Between Displays

**No re-registration needed**. WindowServer handles this automatically:

```
Multiple scale images provided during registration:

imageArray = [
    image_100  (1x - 32×32 pixels)
    image_200  (2x - 64×64 pixels)
    image_500  (5x - 160×160 pixels)
    image_1000 (10x - 320×320 pixels)
]

                     ┌──────────────────┐
                     │   WindowServer   │
                     │   Stores all     │
                     └────────┬─────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
 ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
 │  MacBook Screen │ │  1080p External │ │  4K External    │
 │  Retina @2x     │ │  @1x            │ │  @2x            │
 │                 │ │                 │ │                 │
 │  Uses image_200 │ │  Uses image_100 │ │  Uses image_200 │
 └─────────────────┘ └─────────────────┘ └─────────────────┘

 WindowServer automatically selects appropriate image when cursor moves
```

### Display Configuration Changes

When displays are plugged/unplugged or resolution changes, **re-registration is needed**:

```objc
// listen.m
void reconfigurationCallback(...) {
    // 1. Re-apply entire Cape
    applyCapeAtPath(capePath);

    // 2. Refresh cursor scale (force refresh trick)
    CGSGetCursorScale(cid, &scale);
    CGSSetCursorScale(cid, scale + .3);  // Slight adjustment
    CGSSetCursorScale(cid, scale);       // Restore
}
```

### Re-registration Trigger Conditions

| Scenario | Re-register? | Reason |
|----------|--------------|--------|
| Cursor **moving** between displays | ❌ | WindowServer selects appropriate scale in real-time |
| Display **plug/unplug** | ✅ | System configuration changed, needs refresh |
| **Resolution** change | ✅ | May need different scale images |
| System **restart/logout** | ✅ | WindowServer restarts, memory cleared |
| **User switch** | ✅ | Different users may have different Capes |

---

## Multi-User Support

### Data Storage Structure

Each user has independent cursor configuration:

```
/Users/
├── alice/
│   └── Library/
│       ├── Application Support/
│       │   └── Mousecape/
│       │       └── capes/
│       │           ├── my-theme.cape      ← Alice's cursor theme
│       │           └── another.cape
│       └── Preferences/
│           └── com.alexzielenski.Mousecape.plist
│               └── MCAppliedCursor: "my-theme"
│
├── bob/
│   └── Library/
│       ├── Application Support/
│       │   └── Mousecape/
│       │       └── capes/
│       │           └── bobs-cursor.cape   ← Bob's cursor theme
│       └── Preferences/
│           └── com.alexzielenski.Mousecape.plist
│               └── MCAppliedCursor: "bobs-cursor"
```

### User Switch Flow

```
Alice logged in, using "my-theme" cursor
       │
       │ Switch user
       ▼
┌─────────────────────────────────────────────────┐
│  SCDynamicStore triggers UserSpaceChanged       │
└─────────────────────────────────────────────────┘
       │
       ▼
SCDynamicStoreCopyConsoleUser() → "bob"
       │
       ▼
NSHomeDirectoryForUser("bob") → "/Users/bob"
       │
       ▼
Read Bob's preferences → MCAppliedCursor = "bobs-cursor"
       │
       ▼
Load /Users/bob/.../capes/bobs-cursor.cape
       │
       ▼
Register Bob's cursor to WindowServer
```

### Key Code

```objc
// listen.m
NSString *appliedCapePathForUser(NSString *user) {
    // Get user's home directory
    NSString *home = NSHomeDirectoryForUser(user);

    // Read user's preferences
    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, ...);

    // Build Cape path
    // ~/Library/Application Support/Mousecape/capes/{ident}.cape
    NSString *capePath = [[[appSupport
        stringByAppendingPathComponent:@"Mousecape/capes"]
        stringByAppendingPathComponent:ident]
        stringByAppendingPathExtension:@"cape"];

    return capePath;
}
```

---

## Component Responsibilities

### Two Build Targets

| Component | Type | Needs to Keep Running | Responsibility |
|-----------|------|----------------------|----------------|
| **Mousecape** | GUI App + Menu Bar | ✅ (background) | User interface, manage Capes, trigger registration, session monitoring via embedded `startSessionMonitor()` |
| **mousecloak** | CLI Tool | ❌ | Command-line operations, execute actual registration |

### Events Monitored by Session Monitor

The session monitor (`startSessionMonitor()` in `listen.m`) runs as a non-blocking listener on the main run loop:

```
┌─────────────────────────────────────────────────────────────────┐
│              Embedded Session Monitor's Role                     │
│              (startSessionMonitor in listen.m)                   │
└─────────────────────────────────────────────────────────────────┘

1. User Switch (SCDynamicStore)
   ┌─────────────┐        ┌─────────────┐
   │  User A     │  ───►  │  User B     │
   └─────────────┘        └─────────────┘
         │                      │
         └──────────┬───────────┘
                    ▼
            Re-apply that user's Cape

2. Display Configuration Change (CGDisplayRegisterReconfigurationCallback)
   ┌─────────────┐        ┌─────────────┐
   │ Single      │  ───►  │ External    │
   │ Display     │        │ Display     │
   └─────────────┘        └─────────────┘
         │                      │
         └──────────┬───────────┘
                    ▼
            Re-apply Cape
```

### Complete Lifecycle

```
System Boot
    │
    ▼
WindowServer starts (cursor registry empty)
    │
    ▼
User Login
    │
    ▼
Mousecape launches (via Login Item or manually)
    │
    ├──► startSessionMonitor() attaches to main run loop
    ├──► Read user's configured Cape
    ├──► Call CGSRegisterCursorWithImages to register
    └──► App stays in menu bar, listening for events
              │
              ├──► User switch → Re-register
              ├──► Display change → Re-register
              └──► Keep listening (non-blocking)...
```

---

## Risks and Limitations

### Private API Risks

1. **No official documentation** - Can only rely on reverse engineering and testing
2. **No stability guarantee** - Apple can change at any time
3. **May cause system instability**
4. **App Store prohibited** - Can only distribute outside Mac App Store

### System Compatibility

- May need adaptation after each major macOS update
- Cursor identifiers may change (e.g., Arrow synonyms)
- API behavior may change

---

## Security Analysis

### Risks of Using Private APIs

| Risk Type | Severity | Description |
|-----------|----------|-------------|
| System Crash | 🟡 Low | WindowServer has protection mechanisms; bad parameters usually just return error codes |
| Cursor Anomaly | 🟢 Very Low | Worst case: cursor displays incorrectly, restart to recover |
| Data Loss | 🟢 None | Only modifies runtime memory, doesn't touch user data |
| Persistent Damage | 🟢 None | Everything reverts after restart |

### Attack Surface Analysis for Malicious Cape Files

Cape file processing flow and security at each stage:

```
.cape file (binary plist)
       │
       ▼
┌─────────────────────────────────────┐
│ 1. Path Validation                  │  ✅ Protected
│    - Check .cape extension          │
│    - Resolve symlinks               │
│    - Path traversal check           │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 2. Plist Parsing                    │  ⚠️ Potential Risk
│    dictionaryWithContentsOfFile     │
│    (System API, relatively safe)    │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. Image Parsing                    │  ⚠️ Potential Risk
│    NSBitmapImageRep initWithData    │
│    (PNG decoder)                    │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 4. Register to WindowServer         │  ✅ Relatively Safe
│    CGSRegisterCursorWithImages      │
│    (Only accepts CGImage)           │
└─────────────────────────────────────┘
```

### Potential Attack Vector Assessment

| Attack Vector | Risk Level | Analysis |
|---------------|------------|----------|
| **Malicious Plist** | 🟡 Low | `dictionaryWithContentsOfFile` is a safe system API, won't execute code |
| **Malicious PNG Image** | 🟡 Low-Medium | PNG decoder vulnerabilities have existed historically, but Apple continuously patches |
| **Buffer Overflow** | 🟡 Low | Modern macOS has ASLR, stack protection, and other mitigations |
| **Code Execution** | 🟢 Very Low | Cape files only contain data, no executable code |
| **Privilege Escalation** | 🟢 None | App runs with user privileges, no root access |
| **Persistent Malware** | 🟢 None | Cursor data only exists in memory, cleared on restart |

### Worst Case Analysis

**Scenario 1: Exploiting Image Decoder Vulnerability**

```
Malicious PNG → NSBitmapImageRep parsing → Trigger vulnerability

Possible results:
- Application crash (denial of service)
- Theoretical code execution (but system mitigations exist)

Scope of impact:
- Limited to Mousecape/helper process
- User privileges, not root
- Sandboxed (if enabled)
```

**Scenario 2: Malformed Cursor Data**

```
Abnormal parameters → CGSRegisterCursorWithImages

Possible results:
- API returns error, registration fails
- Cursor displays abnormally
- Extreme case: WindowServer anomaly (system will auto-restart it)

Recovery:
- Restart Mac to fully recover
```

### Risk Comparison with Other Software

| Software Type | Risk Level | Reason |
|---------------|------------|--------|
| Browser | 🔴 High | Executes remote code, parses complex formats |
| Office Software | 🔴 High | Macro code execution, complex file formats |
| PDF Reader | 🟠 Medium-High | JavaScript, complex parsing |
| **Mousecape** | 🟢 Low | Only processes simple data formats, no code execution |
| Image Viewer | 🟡 Low-Medium | Image decoding (similar to Mousecape) |

### Existing Security Measures in the Project

Security protections implemented in code:

```objc
// apply.m - Path validation
NSString *realPath = [path stringByResolvingSymlinksInPath];  // Resolve symlinks
NSString *standardPath = [realPath stringByStandardizingPath]; // Standardize path

// Extension validation
if (![[standardPath pathExtension] isEqualToString:@"cape"]) {
    return NO;
}

// listen.m - Path traversal protection
if ([ident containsString:@"/"] || [ident containsString:@".."]) {
    MMLog("Invalid cape identifier");
    return nil;
}

// Ensure path is within expected directory
if (![standardPath hasPrefix:expectedPrefix]) {
    MMLog("Path traversal detected");
    return nil;
}
```

### Security Recommendations

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Recommendations                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ Only download .cape files from trusted sources              │
│                                                                 │
│  ✅ Project's existing security measures:                       │
│     - Path traversal protection                                 │
│     - File extension validation                                 │
│     - Symlink resolution                                        │
│                                                                 │
│  ⚠️ Not recommended to run .cape files from unknown sources     │
│     (Similar risk to opening unknown images/documents)          │
│                                                                 │
│  ℹ️ Even in worst case scenario:                                │
│     - System files won't be damaged                             │
│     - Root privileges won't be obtained                         │
│     - Restart to fully recover                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Security Summary

**This project has very low security risk**:

1. **Doesn't touch system files** - SIP protection remains effective
2. **No persistence capability** - Cleared on restart
3. **Runs with user privileges** - Cannot escalate
4. **Read-only data processing** - Cape files only contain image data, no code execution
5. **Worst case recoverable** - Just restart Mac

---

## Acknowledgements

- **Alex Zielenski** - Project author, reverse-engineered core cursor APIs
- **Joe Ranieri** - Discovered early CGS APIs in 2008
- **Alacatia Labs** - Original contributors of CGSInternal headers

---

## Document Information

This document was generated by **Claude** (Anthropic) through analysis of the project's source code.

Analysis includes:
- Private API discovery methods and working principles
- Cursor registration mechanism and animation implementation
- Multi-display and multi-user support
- Security risk assessment

*Analysis date: January 2026*

---
---

# Mousecape 技术架构文档

本文档详细介绍 Mousecape 的底层工作原理，包括私有 API 的发现、光标注册机制、动画实现等核心技术。

**[English Version](#mousecape-technical-architecture)**

## 目录

- [私有 API 概述](#私有-api-概述)
- [为什么不需要关闭 SIP](#为什么不需要关闭-sip)
- [光标注册机制](#光标注册机制)
- [动画光标实现](#动画光标实现)
- [多显示器支持](#多显示器支持)
- [多用户支持](#多用户支持)
- [组件职责](#组件职责)
- [风险与限制](#风险与限制)
- [安全性分析](#安全性分析)

---

## 私有 API 概述

### 公有 API vs 私有 API

| 特性 | 公有 API | 私有 API |
|------|---------|---------|
| 文档 | Apple 官方文档化 | 无官方文档 |
| 稳定性 | 有稳定性保证 | 可能随时变更 |
| App Store | 允许使用 | 禁止使用 |
| 示例 | `NSCursor`、`CGImage` | `CGSRegisterCursorWithImages()` |

### 私有 API 的发现方法

Mousecape 使用的私有 API 主要通过以下方式发现：

1. **逆向工程**
   - 项目作者 Alex Zielenski 在 macOS Lion 10.7.3 上逆向了核心光标 API
   - 文件头注释：`Cursor APIs reversed by Alex Zielenski on Lion 10.7.3`

2. **社区协作**
   - Joe Ranieri 在 2008 年（Leopard 时代）发现了部分 API
   - 开发者社区共享逆向成果

3. **具体发现技术**

   | 技术 | 说明 |
   |------|------|
   | `nm` / `otool` | 列出动态库导出的符号 |
   | `class-dump` | 提取 Objective-C 类和方法信息 |
   | 反汇编器 | Hopper、IDA Pro、Ghidra 分析函数签名 |
   | 运行时调试 | `lldb` 或 `dtrace` 观察系统调用 |
   | 字符串搜索 | 在二进制中搜索函数名 |

### 核心私有 API

位于 `mousecloak/CGSInternal/CGSCursor.h`：

```objc
// 注册自定义光标（核心 API）
CGSRegisterCursorWithImages(
    CGSConnectionID cid,      // 与 WindowServer 的连接
    char *cursorName,         // 光标标识符
    bool setGlobally,         // 是否全局生效
    bool instantly,           // 是否立即生效
    CGSize cursorSize,        // 光标尺寸
    CGPoint hotspot,          // 热点位置
    NSUInteger frameCount,    // 动画帧数
    CGFloat frameDuration,    // 每帧持续时间
    CFArrayRef imageArray,    // 图像数组
    int *seed                 // 输出：光标种子值
);

// 重置所有光标为系统默认
CoreCursorUnregisterAll(CGSConnectionID cid);

// 读取当前光标数据
CGSCopyRegisteredCursorImages(...);

// 获取与 WindowServer 的连接
CGSMainConnectionID();
```

---

## 为什么不需要关闭 SIP

### 关键点：修改内存而非文件

Mousecape **不修改**任何系统文件。它使用的是完全不同的机制：

```
┌─────────────────────────────────────────────────────────────┐
│                    WindowServer 进程                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              光标注册表（内存中）                      │   │
│  │  ┌──────────────────┬──────────────────────────┐   │   │
│  │  │ 光标名称          │ 图像数据                  │   │   │
│  │  ├──────────────────┼──────────────────────────┤   │   │
│  │  │ Arrow            │ 系统默认 → 自定义覆盖     │   │   │
│  │  │ IBeam            │ 系统默认 → 自定义覆盖     │   │   │
│  │  │ Wait             │ 系统默认 → 自定义覆盖     │   │   │
│  │  └──────────────────┴──────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         ▲
         │ Mach IPC（进程间通信）
         │
┌────────┴────────┐
│   Mousecape     │
│ CGSRegisterCursor│
│   WithImages()  │
└─────────────────┘
```

### SIP 保护范围对比

| SIP 保护的内容 | Mousecape 的操作 |
|---------------|-----------------|
| `/System` 目录下的文件 | ❌ 不触碰 |
| 系统内核扩展 | ❌ 不触碰 |
| 系统框架二进制 | ❌ 不触碰 |
| WindowServer 运行时内存 | ✅ 通过 API 修改 |

**关键区别**：SIP 保护的是**磁盘上的系统文件**，而不是**运行时内存状态**。

### 为什么这被允许？

```
┌────────────────────────────────────────────────┐
│  macOS 安全模型                                 │
├────────────────────────────────────────────────┤
│  1. 任何 GUI 应用都需要 CGSConnection          │
│  2. 光标注册是 WindowServer 的正常功能          │
│  3. 这是设计好的 IPC 机制，不是漏洞             │
│  4. 重启后会恢复（非持久化修改）                │
└────────────────────────────────────────────────┘
```

Apple 设计这些 API 可能是为了：
- 让应用程序创建自定义光标（如绘图软件的画笔光标）
- 辅助功能需求（放大光标等）
- 系统组件使用（Dock 等）

### 类比解释

| 概念 | 类比 |
|------|------|
| SIP | 锁住了工具箱（系统文件） |
| WindowServer | 正在运行的机器（接受指令） |
| CGSRegisterCursor | 给机器发送"换个零件"的指令 |
| Mousecape | 操作员（合法发送指令） |

---

## 光标注册机制

### 注册流程

```
用户点击"应用 Cape"
       │
       ▼
┌─────────────────┐
│   Mousecape     │──── 调用 CGSRegisterCursorWithImages()
│   (GUI 应用)    │     注册所有光标到 WindowServer
└─────────────────┘
       │
       │ 注册完成后...
       ▼
┌─────────────────┐
│  可以退出应用   │     ← Mousecape 不需要保持运行！
└─────────────────┘

       ║
       ║  光标数据已存在于 WindowServer 内存中
       ▼

┌─────────────────────────────────────────────────────────────┐
│                    WindowServer（系统进程）                   │
│                                                             │
│  持续运行，自动渲染光标                                       │
│  直到：注销 / 重启 / 调用 reset                               │
└─────────────────────────────────────────────────────────────┘
```

### 核心代码

```objc
// apply.m
static BOOL MCRegisterImagesForCursorName(...) {
    CGError err = CGSRegisterCursorWithImages(
        CGSMainConnectionID(),  // 获取当前进程的连接
        cursorName,             // 如 "com.apple.coregraphics.Arrow"
        true,                   // setGlobally - 全局生效
        true,                   // instantly - 立即生效
        size,                   // 光标尺寸
        hotSpot,                // 热点位置
        frameCount,             // 帧数
        frameDuration,          // 帧持续时间
        (__bridge CFArrayRef)images,  // 图像数组
        &seed
    );
    return (err == kCGErrorSuccess);
}
```

### 特殊光标处理

某些光标在新版 macOS 上有多个别名，需要同时注册：

```objc
// Arrow 光标的同义词
@"com.apple.coregraphics.Arrow"
@"com.apple.coregraphics.ArrowCtx"

// IBeam 光标的同义词
@"com.apple.coregraphics.IBeam"
@"com.apple.coregraphics.IBeamXOR"
```

---

## 动画光标实现

### 原理：精灵图 + 帧动画

动画光标使用垂直排列的精灵图（Sprite Sheet）实现：

```
┌────────────────────────────────────────────────────────────────┐
│                    单张精灵图（垂直排列）                        │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────┐                                                  │
│  │  帧 1    │  ← 第 0 帧                                       │
│  ├──────────┤                                                  │
│  │  帧 2    │  ← 第 1 帧                                       │
│  ├──────────┤                                                  │
│  │  帧 3    │  ← 第 2 帧                                       │
│  ├──────────┤                                                  │
│  │  ...     │                                                  │
│  ├──────────┤                                                  │
│  │  帧 N    │  ← 第 N-1 帧                                     │
│  └──────────┘                                                  │
│                                                                │
│  图像高度 = 单帧高度 × frameCount                               │
└────────────────────────────────────────────────────────────────┘
```

### API 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `frameCount` | 动画帧数（1-24） | 8 帧 |
| `frameDuration` | 每帧持续时间（秒） | 0.1 秒 = 10 FPS |
| `imageArray` | 精灵图数组（不同缩放） | 1x、2x、5x、10x |
| `size` | **单帧**尺寸 | 32×32 点 |

### 帧数限制

```objc
if (frameCount > 24 || frameCount < 1) {
    MMLog("Frame count out of range [1...24]");
    return NO;
}
```

**最大 24 帧** —— 这是 WindowServer 的硬性限制。

### 动画播放流程

```
WindowServer 内部
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

注册时保存：
┌─────────────────────────┐
│ 光标名: "Wait"          │
│ 精灵图: [1x, 2x, 5x]    │
│ 帧数: 8                 │
│ 帧时长: 0.1s            │
└─────────────────────────┘
        │
        ▼
播放时自动切换：
┌─────────────────────────┐
│ 时间 0.0s → 显示帧 0    │
│ 时间 0.1s → 显示帧 1    │
│ 时间 0.2s → 显示帧 2    │
│ ...                     │
│ 时间 0.7s → 显示帧 7    │
│ 时间 0.8s → 循环到帧 0  │
└─────────────────────────┘
```

**动画播放完全由 WindowServer 处理**，应用只需注册一次，不需要持续更新。

### 静态 vs 动态光标对比

| 类型 | frameCount | frameDuration | 精灵图 |
|------|-----------|---------------|--------|
| 静态（Arrow） | 1 | 0 | 单帧图像 |
| 动态（Wait） | 8-24 | 0.05-0.2 | 垂直拼接的帧 |

---

## 多显示器支持

### 光标在显示器间移动

**不需要重新注册**。WindowServer 自动处理：

```
注册时提供多个缩放比例的图像：

imageArray = [
    image_100  (1x - 32×32 像素)
    image_200  (2x - 64×64 像素)
    image_500  (5x - 160×160 像素)
    image_1000 (10x - 320×320 像素)
]

                     ┌──────────────────┐
                     │   WindowServer   │
                     │   保存所有版本    │
                     └────────┬─────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
 ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
 │  MacBook 内屏   │ │  1080p 外接     │ │  4K 外接        │
 │  Retina @2x     │ │  @1x            │ │  @2x            │
 │                 │ │                 │ │                 │
 │  使用 image_200 │ │  使用 image_100 │ │  使用 image_200 │
 └─────────────────┘ └─────────────────┘ └─────────────────┘

 光标移动时，WindowServer 自动选择合适的图像版本
```

### 显示器配置变化

当显示器插拔或分辨率变化时，**需要重新注册**：

```objc
// listen.m
void reconfigurationCallback(...) {
    // 1. 重新应用整个 Cape
    applyCapeAtPath(capePath);

    // 2. 刷新光标缩放（强制刷新技巧）
    CGSGetCursorScale(cid, &scale);
    CGSSetCursorScale(cid, scale + .3);  // 微调
    CGSSetCursorScale(cid, scale);       // 恢复
}
```

### 重新注册的触发条件

| 场景 | 是否重新注册 | 原因 |
|------|-------------|------|
| 光标在显示器间**移动** | ❌ | WindowServer 实时选择合适的缩放版本 |
| 显示器**插拔** | ✅ | 系统配置变化，需刷新状态 |
| **分辨率**变化 | ✅ | 可能需要不同缩放的图像 |
| 系统**重启/注销** | ✅ | WindowServer 重启，内存清空 |
| **用户切换** | ✅ | 不同用户可能有不同 Cape |

---

## 多用户支持

### 数据存储结构

每个用户有独立的光标配置：

```
/Users/
├── alice/
│   └── Library/
│       ├── Application Support/
│       │   └── Mousecape/
│       │       └── capes/
│       │           ├── my-theme.cape      ← Alice 的光标主题
│       │           └── another.cape
│       └── Preferences/
│           └── com.alexzielenski.Mousecape.plist
│               └── MCAppliedCursor: "my-theme"
│
├── bob/
│   └── Library/
│       ├── Application Support/
│       │   └── Mousecape/
│       │       └── capes/
│       │           └── bobs-cursor.cape   ← Bob 的光标主题
│       └── Preferences/
│           └── com.alexzielenski.Mousecape.plist
│               └── MCAppliedCursor: "bobs-cursor"
```

### 用户切换流程

```
Alice 登录中，使用 "my-theme" 光标
       │
       │ 切换用户
       ▼
┌─────────────────────────────────────────────────┐
│  SCDynamicStore 触发 UserSpaceChanged 回调       │
└─────────────────────────────────────────────────┘
       │
       ▼
SCDynamicStoreCopyConsoleUser() → "bob"
       │
       ▼
NSHomeDirectoryForUser("bob") → "/Users/bob"
       │
       ▼
读取 Bob 的偏好设置 → MCAppliedCursor = "bobs-cursor"
       │
       ▼
加载 /Users/bob/.../capes/bobs-cursor.cape
       │
       ▼
注册 Bob 的光标到 WindowServer
```

### 关键代码

```objc
// listen.m
NSString *appliedCapePathForUser(NSString *user) {
    // 获取用户主目录
    NSString *home = NSHomeDirectoryForUser(user);

    // 读取该用户的偏好设置
    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, ...);

    // 拼接 Cape 路径
    // ~/Library/Application Support/Mousecape/capes/{ident}.cape
    NSString *capePath = [[[appSupport
        stringByAppendingPathComponent:@"Mousecape/capes"]
        stringByAppendingPathComponent:ident]
        stringByAppendingPathExtension:@"cape"];

    return capePath;
}
```

---

## 组件职责

### 两个构建目标

| 组件 | 类型 | 需要保持运行 | 职责 |
|------|------|-------------|------|
| **Mousecape** | GUI 应用 + 菜单栏 | ✅（后台） | 用户界面，管理 Cape，触发注册，通过内嵌 `startSessionMonitor()` 进行会话监听 |
| **mousecloak** | CLI 工具 | ❌ | 命令行操作，执行实际注册 |

### 会话监听器监听的事件

会话监听器（`listen.m` 中的 `startSessionMonitor()`）以非阻塞方式运行在主 RunLoop 上：

```
┌─────────────────────────────────────────────────────────────────┐
│              内嵌会话监听器的作用                                  │
│              (listen.m 中的 startSessionMonitor)                  │
└─────────────────────────────────────────────────────────────────┘

1. 用户切换（SCDynamicStore）
   ┌─────────────┐        ┌─────────────┐
   │  用户 A     │  ───►  │  用户 B     │
   └─────────────┘        └─────────────┘
         │                      │
         └──────────┬───────────┘
                    ▼
            重新应用该用户的 Cape

2. 显示器配置变化（CGDisplayRegisterReconfigurationCallback）
   ┌─────────────┐        ┌─────────────┐
   │ 单显示器    │  ───►  │ 外接显示器  │
   └─────────────┘        └─────────────┘
         │                      │
         └──────────┬───────────┘
                    ▼
            重新应用 Cape
```

### 完整生命周期

```
系统启动
    │
    ▼
WindowServer 启动（光标注册表为空）
    │
    ▼
用户登录
    │
    ▼
Mousecape 启动（通过登录项或手动启动）
    │
    ├──► startSessionMonitor() 挂载到主 RunLoop
    ├──► 读取用户配置的 Cape
    ├──► 调用 CGSRegisterCursorWithImages 注册
    └──► 应用驻留菜单栏，持续监听事件
              │
              ├──► 用户切换 → 重新注册
              ├──► 显示器变化 → 重新注册
              └──► 持续监听（非阻塞）...
```

---

## 风险与限制

### 私有 API 的风险

1. **无官方文档** - 只能靠逆向和测试
2. **无稳定性保证** - Apple 可随时更改
3. **可能导致系统不稳定**
4. **App Store 禁止** - 只能在 Mac App Store 之外分发

### 系统兼容性

- 每次 macOS 大版本更新可能需要适配
- 光标标识符可能变化（如 Arrow 的同义词）
- API 行为可能改变

---

## 安全性分析

### 私有 API 使用的风险

| 风险类型 | 严重程度 | 说明 |
|---------|---------|------|
| 系统崩溃 | 🟡 低 | WindowServer 有保护机制，错误参数通常只会返回错误码 |
| 光标异常 | 🟢 极低 | 最坏情况：光标显示异常，重启即可恢复 |
| 数据丢失 | 🟢 无 | 只修改运行时内存，不触及用户数据 |
| 持久性破坏 | 🟢 无 | 重启后一切恢复原状 |

### 恶意 Cape 文件的攻击面分析

Cape 文件的处理流程及各环节的安全性：

```
.cape 文件（二进制 plist）
       │
       ▼
┌─────────────────────────────────────┐
│ 1. 路径验证                          │  ✅ 有保护
│    - 检查扩展名 .cape                │
│    - 解析符号链接                    │
│    - 路径遍历检查                    │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 2. Plist 解析                        │  ⚠️ 潜在风险点
│    dictionaryWithContentsOfFile      │
│    （系统 API，相对安全）             │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. 图像解析                          │  ⚠️ 潜在风险点
│    NSBitmapImageRep initWithData     │
│    （PNG 解码器）                    │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 4. 注册到 WindowServer               │  ✅ 相对安全
│    CGSRegisterCursorWithImages       │
│    （只接受 CGImage）                │
└─────────────────────────────────────┘
```

### 潜在攻击向量评估

| 攻击向量 | 风险等级 | 分析 |
|---------|---------|------|
| **恶意 Plist** | 🟡 低 | `dictionaryWithContentsOfFile` 是安全的系统 API，不会执行代码 |
| **恶意 PNG 图像** | 🟡 低-中 | PNG 解码器漏洞历史上存在，但 Apple 持续修补 |
| **缓冲区溢出** | 🟡 低 | 现代 macOS 有 ASLR、栈保护等缓解措施 |
| **代码执行** | 🟢 极低 | Cape 文件只包含数据，不含可执行代码 |
| **权限提升** | 🟢 无 | 应用以用户权限运行，无 root 权限 |
| **持久化恶意软件** | 🟢 无 | 光标数据只存在于内存，重启清除 |

### 最坏情况分析

**情况 1：利用图像解码漏洞**

```
恶意 PNG → NSBitmapImageRep 解析 → 触发漏洞

可能结果：
- 应用崩溃（拒绝服务）
- 理论上的代码执行（但有系统缓解措施）

影响范围：
- 仅限 Mousecape/helper 进程
- 用户权限，非 root
- 受沙箱限制（如果启用）
```

**情况 2：畸形光标数据**

```
异常参数 → CGSRegisterCursorWithImages

可能结果：
- API 返回错误，注册失败
- 光标显示异常
- 极端情况：WindowServer 异常（系统会自动重启它）

恢复方式：
- 重启 Mac 即可完全恢复
```

### 与其他软件风险对比

| 软件类型 | 风险级别 | 原因 |
|---------|---------|------|
| 浏览器 | 🔴 高 | 执行远程代码、解析复杂格式 |
| Office 软件 | 🔴 高 | 宏代码执行、复杂文件格式 |
| PDF 阅读器 | 🟠 中-高 | JavaScript、复杂解析 |
| **Mousecape** | 🟢 低 | 只处理简单数据格式，无代码执行 |
| 图片查看器 | 🟡 低-中 | 图像解码（与 Mousecape 类似） |

### 项目已有的安全措施

代码中已实现的安全防护：

```objc
// apply.m - 路径验证
NSString *realPath = [path stringByResolvingSymlinksInPath];  // 解析符号链接
NSString *standardPath = [realPath stringByStandardizingPath]; // 标准化路径

// 扩展名验证
if (![[standardPath pathExtension] isEqualToString:@"cape"]) {
    return NO;
}

// listen.m - 路径遍历防护
if ([ident containsString:@"/"] || [ident containsString:@".."]) {
    MMLog("Invalid cape identifier");
    return nil;
}

// 确保路径在预期目录内
if (![standardPath hasPrefix:expectedPrefix]) {
    MMLog("Path traversal detected");
    return nil;
}
```

### 安全建议

```
┌─────────────────────────────────────────────────────────────────┐
│                         安全建议                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ 只从可信来源下载 .cape 文件                                  │
│                                                                 │
│  ✅ 项目已有的安全措施：                                         │
│     - 路径遍历防护                                              │
│     - 文件扩展名验证                                            │
│     - 符号链接解析                                              │
│                                                                 │
│  ⚠️ 不建议运行来历不明的 .cape 文件                              │
│     （与打开未知图片/文档的风险类似）                            │
│                                                                 │
│  ℹ️ 即使最坏情况发生：                                          │
│     - 不会损坏系统文件                                          │
│     - 不会获得 root 权限                                        │
│     - 重启即可完全恢复                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 安全性总结

**此项目的安全风险非常低**：

1. **不触及系统文件** - SIP 保护依然有效
2. **无持久化能力** - 重启即清除所有修改
3. **用户权限运行** - 无法提权
4. **数据只读处理** - Cape 文件只包含图像数据，不执行代码
5. **最坏情况可恢复** - 重启 Mac 即可

---

## 致谢

- **Alex Zielenski** - 项目作者，逆向了核心光标 API
- **Joe Ranieri** - 2008 年发现了早期的 CGS API
- **Alacatia Labs** - CGSInternal 头文件的原始贡献者

---

## 文档信息

本文档由 **Claude** (Anthropic) 通过分析项目源代码生成。

分析内容包括：
- 私有 API 的发现方法和工作原理
- 光标注册机制和动画实现
- 多显示器和多用户支持
- 安全性风险评估

*分析日期：2026年1月*
