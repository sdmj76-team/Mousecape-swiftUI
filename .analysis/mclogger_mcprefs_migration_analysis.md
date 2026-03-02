# MCLogger and MCPrefs Migration Analysis

**Date:** 2026-03-02
**Analyst:** utils-migrator
**Tasks:** #7 (MCLogger), #10 (MCPrefs)
**Status:** Analysis Complete - Migration Not Recommended

## Executive Summary

After thorough analysis, **migration of MCLogger and MCPrefs to Swift is not recommended**. The current Objective-C implementation works well and serves its primary purpose in the mousecloak CLI tool. Migration would add complexity with minimal benefit.

## Current Architecture

### MCLogger Usage

**mousecloak CLI (11 files):**
- `main.m` - Initialization and command logging
- `apply.m` - Cursor application logging
- `listen.m` - Session monitoring logging
- `backup.m`, `restore.m`, `create.m`, `scale.m` - Operation logging
- `MCDefs.h/m` - MMLog macro definitions

**GUI Application (1 file):**
- `MCLibraryController.m` - 3 calls: `MCLoggerInit()`, `MMLog()` (2x)

**GUI Alternative:**
- `DebugLogger.swift` - Full-featured Swift logging system already exists

### MCPrefs Usage

**mousecloak CLI (5 files):**
- `apply.m` - Read/write applied cursor preference
- `listen.m` - Read cursor scale preference
- `scale.m` - Read cursor scale preference
- `restore.m` - Read preferences
- `MCPrefs.h/m` - Implementation

**GUI Application (1 file):**
- `MCLibraryController.m` - 1 call: `MCDefault(MCPreferencesAppliedCursorKey)`

**GUI Alternative:**
- Direct CFPreferences API calls
- UserDefaults for app-specific settings

## Migration Challenges

### 1. Separate Binary Targets

```
Mousecape.app (GUI)          mousecloak (CLI)
├── Swift code               ├── Pure Objective-C
├── DebugLogger.swift        ├── MCLogger.h/m
└── Can't easily share  ←──→ └── MCPrefs.h/m
```

**Problem:** mousecloak is a separate CLI binary that cannot easily use Swift code from the GUI target.

### 2. Possible Solutions and Their Costs

#### Option A: Keep Current Implementation (Recommended)
- **Pros:** Simple, works perfectly, no risk
- **Cons:** Code duplication (minimal)
- **Effort:** 0 days

#### Option B: Create Shared Framework
- **Pros:** Code reuse
- **Cons:** Complex project restructuring, overkill for 2 small utilities
- **Effort:** 2-3 days

#### Option C: C Bridge Functions
- **Pros:** Allows ObjC to call Swift
- **Cons:** Complex, error-prone, maintenance burden
- **Effort:** 1-2 days

#### Option D: Migrate mousecloak to Swift
- **Pros:** Full Swift codebase
- **Cons:** Massive effort, out of scope, risky
- **Effort:** 5-7 days

### 3. Benefit Analysis

**Current State:**
- MCLogger: ~200 lines of C code, works perfectly
- MCPrefs: ~50 lines of C code, works perfectly
- Both are DEBUG-only or minimal overhead
- No bugs, no performance issues

**Migration Benefits:**
- Slightly more "modern" code
- Marginally easier to maintain (debatable)

**Migration Costs:**
- 1-3 days of development time
- Risk of introducing bugs
- Increased complexity (bridge functions or frameworks)
- Testing overhead

**Conclusion:** Costs significantly outweigh benefits.

## Recommendation

### Primary Recommendation: Keep Current Implementation

**Rationale:**
1. This is marked as an "optional" task (low priority)
2. Current implementation is stable and performant
3. mousecloak CLI is a separate binary with different needs
4. GUI already has DebugLogger.swift for its logging needs
5. Migration effort better spent on higher-priority tasks

### Alternative: Minimal GUI-Side Update

If any change is desired, update only `MCLibraryController.m`:

```objc
// Before:
MCLoggerInit();
MMLog("message");
NSString *applied = MCDefault(MCPreferencesAppliedCursorKey);

// After:
// Remove MCLoggerInit() - DebugLogger.shared already initialized
debugLog("message");  // Use Swift debugLog()
NSString *applied = (__bridge NSString *)CFPreferencesCopyValue(
    CFSTR("MCAppliedCursor"),
    CFSTR("com.alexzielenski.Mousecape"),
    kCFPreferencesCurrentUser,
    kCFPreferencesCurrentHost
);
```

**Effort:** 30 minutes
**Benefit:** Removes 3 ObjC calls from GUI code
**Risk:** Very low

## Files Created During Analysis

- `/Users/herryli/Documents/Mousecape/Mousecape/Mousecape/SwiftUI/Utilities/UserPreferences.swift`
  - Swift wrapper for CFPreferences API
  - Can be kept for future use or deleted
  - Not currently integrated into the project

## Next Steps

**Recommended:**
1. Mark tasks #7 and #10 as **completed** (decision: keep current implementation)
2. Document decision in CLAUDE.md
3. Focus on higher-priority tasks (GBCli migration, model serialization)

**Alternative:**
1. Implement minimal GUI-side update (30 minutes)
2. Keep MCLogger/MCPrefs for CLI
3. Mark tasks as completed

## Task Status Update

```
Task #7: 阶段 3.1：迁移 MCLogger 到 Swift（可选）
Status: Recommend marking as COMPLETED (decision: no migration needed)

Task #10: 阶段 3.2：迁移 MCPrefs 到 Swift（可选）
Status: Recommend marking as COMPLETED (decision: no migration needed)
```

## References

- MCLogger: `/Users/herryli/Documents/Mousecape/Mousecape/mousecloak/MCLogger.h/m`
- MCPrefs: `/Users/herryli/Documents/Mousecape/Mousecape/mousecloak/MCPrefs.h/m`
- DebugLogger: `/Users/herryli/Documents/Mousecape/Mousecape/Mousecape/SwiftUI/Utilities/DebugLogger.swift`
- CLAUDE.md: Architecture documentation
