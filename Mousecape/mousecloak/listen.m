//
//  listen.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "listen.h"
#import "apply.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "MCPrefs.h"
#import "MCDefs.h"
#import "CGSCursor.h"
#import <Cocoa/Cocoa.h>
#import "scale.h"

#define PERIODIC_NUDGE_INTERVAL_SEC 60.0

// Periodic scale nudge callback — keeps cursor registrations fresh while the Helper runs.
// Mirrors the nudge pattern in apply.m: bump + 30ms delay + restore with retry.
static void periodicNudgeCallback(CFRunLoopTimerRef timer, void *info) {
    float scale = cursorScale();
    if (scale <= 0.0f) {
        MMLog("Periodic nudge: skipped — no valid scale (scale=%.2f)", scale);
        return;
    }

    MMLog("Periodic nudge: scale=%.2f", scale);

    CGSConnectionID cid = CGSMainConnectionID();

    // Bump scale to force cursor system to re-evaluate registrations
    CGSSetCursorScale(cid, scale + 0.3f);

    // Small delay for cursor system to process the scale change
    usleep(30000); // 30ms

    // Restore with retry — the cursor system may not immediately apply the scale
    float afterRestore = scale;
    for (int retry = 0; retry < 3; retry++) {
        CGSSetCursorScale(cid, scale);
        afterRestore = cursorScale();
        if (fabsf(afterRestore - scale) < 0.01f) {
            break;
        }
        usleep(20000); // 20ms between retries
    }

    if (fabsf(afterRestore - scale) >= 0.01f) {
        MMLog(RED "Periodic nudge FAILED: target=%.2f, final=%.2f" RESET, scale, afterRestore);
    } else {
        MMLog("Periodic nudge OK: %.2f", scale);
    }
}

NSString *appliedCapePathForUser(NSString *user) {
    // Validate user - must not be empty or contain path separators
    if (!user || user.length == 0 || [user containsString:@"/"] || [user containsString:@".."]) {
        MMLog(BOLD RED "Invalid username" RESET);
        return nil;
    }

    NSString *home = NSHomeDirectoryForUser(user);
    if (!home) {
        MMLog(BOLD RED "Could not get home directory for user" RESET);
        return nil;
    }

    NSString *ident = MCDefaultFor(@"MCAppliedCursor", user, (NSString *)kCFPreferencesCurrentHost);

    // Validate identifier - remove any path traversal attempts
    if (ident && ([ident containsString:@"/"] || [ident containsString:@".."])) {
        MMLog(BOLD RED "Invalid cape identifier" RESET);
        return nil;
    }

    if (!ident || ident.length == 0) {
        return nil;
    }

    NSString *appSupport = [home stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *capePath = [[[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByAppendingPathComponent:ident] stringByAppendingPathExtension:@"cape"];

    // Ensure the final path is within the expected directory
    NSString *standardPath = [capePath stringByStandardizingPath];
    NSString *expectedPrefix = [[appSupport stringByAppendingPathComponent:@"Mousecape/capes"] stringByStandardizingPath];
    if (![standardPath hasPrefix:expectedPrefix]) {
        MMLog(BOLD RED "Path traversal detected" RESET);
        return nil;
    }

    return capePath;
}

static void UserSpaceChanged(SCDynamicStoreRef	store, CFArrayRef changedKeys, void *info) {
    MMLog("========================================");
    MMLog("=== USER SPACE CHANGED EVENT ===");
    MMLog("========================================");

    CFStringRef currentConsoleUser = SCDynamicStoreCopyConsoleUser(store, NULL, NULL);

    MMLog("Console user: %s", currentConsoleUser ? [(__bridge NSString *)currentConsoleUser UTF8String] : "(null)");
    MMLog("Changed keys count: %ld", CFArrayGetCount(changedKeys));

    if (!currentConsoleUser || CFEqual(currentConsoleUser, CFSTR("loginwindow"))) {
        MMLog("Skipping - loginwindow or no user");
        if (currentConsoleUser) CFRelease(currentConsoleUser);
        return;
    }

    NSString *appliedPath = appliedCapePathForUser((__bridge NSString *)currentConsoleUser);
    MMLog(BOLD GREEN "User Space Changed to %s, applying cape..." RESET, [(__bridge NSString *)currentConsoleUser UTF8String]);
    MMLog("Cape path: %s", appliedPath ? appliedPath.UTF8String : "(none)");

    // Only attempt to apply if there's a valid cape path
    if (appliedPath) {
        BOOL success = applyCapeAtPath(appliedPath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
        if (!success) {
            MMLog(BOLD RED "Application of cape failed" RESET);
        }
    } else {
        MMLog("No cape configured for user");
    }

    // Restore scale according to the active mode
    if (customScaleMode()) {
        float maxScale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
        if (maxScale <= 0.0f) maxScale = 1.0f;
        MMLog("Session monitor: restoring custom scale %.2f", maxScale);
        setCursorScale(maxScale);
    } else {
        float globalScale = [MCDefault(@"MCGlobalCursorScale") floatValue];
        if (globalScale < 0.5f || globalScale > 16.0f) globalScale = 1.0f;
        MMLog("Session monitor: restoring global scale %.2f", globalScale);
        setCursorScale(globalScale);
    }

    CFRelease(currentConsoleUser);
}

void reconfigurationCallback(CGDirectDisplayID display,
    	CGDisplayChangeSummaryFlags flags,
    	void *userInfo) {
    MMLog("========================================");
    MMLog("=== DISPLAY RECONFIGURATION EVENT ===");
    MMLog("========================================");
    MMLog("Display ID: %u", display);
    MMLog("Flags: 0x%x", flags);
    MMLog("  kCGDisplayBeginConfigurationFlag: %s", (flags & kCGDisplayBeginConfigurationFlag) ? "YES" : "NO");
    MMLog("  kCGDisplaySetMainFlag: %s", (flags & kCGDisplaySetMainFlag) ? "YES" : "NO");
    MMLog("  kCGDisplayAddFlag: %s", (flags & kCGDisplayAddFlag) ? "YES" : "NO");
    MMLog("  kCGDisplayRemoveFlag: %s", (flags & kCGDisplayRemoveFlag) ? "YES" : "NO");

    NSString *capePath = appliedCapePathForUser(NSUserName());
    MMLog("Cape path: %s", capePath ? capePath.UTF8String : "(none)");
    if (capePath) {
        BOOL success = applyCapeAtPath(capePath);
        MMLog("Apply result: %s", success ? "SUCCESS" : "FAILED");
    }
    // Restore scale according to the active mode (same logic as UserSpaceChanged)
    if (customScaleMode()) {
        float maxScale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
        if (maxScale <= 0.0f) maxScale = 1.0f;
        MMLog("Reconfig: restoring custom scale %.2f", maxScale);
        setCursorScale(maxScale);
    } else {
        float globalScale = [MCDefault(@"MCGlobalCursorScale") floatValue];
        if (globalScale < 0.5f || globalScale > 16.0f) globalScale = 1.0f;
        MMLog("Reconfig: restoring global scale %.2f", globalScale);
        setCursorScale(globalScale);
    }
}


void listener(void) {
#ifdef DEBUG
    MCLoggerInit();
#endif

    MMLog("========================================");
    MMLog("=== MOUSECAPE HELPER DAEMON STARTED ===");
    MMLog("========================================");

    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    MMLog("macOS version: %ld.%ld.%ld",
          (long)ver.majorVersion, (long)ver.minorVersion, (long)ver.patchVersion);
    MMLog("Process: %s (PID: %d)",
          [[[NSProcessInfo processInfo] processName] UTF8String],
          [[NSProcessInfo processInfo] processIdentifier]);
    MMLog("User: %s", NSUserName().UTF8String);
    MMLog("Home: %s", NSHomeDirectory().UTF8String);

    // Log environment variables
    MMLog("--- Environment Variables ---");
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    for (NSString *key in @[@"USER", @"HOME", @"DISPLAY", @"XPC_SERVICE_NAME"]) {
        MMLog("  %s = %s", key.UTF8String, [env[key] UTF8String] ?: "(null)");
    }

    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    assert(store != NULL);

    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    assert(key != NULL);

    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    assert(keys != NULL);

    Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
    assert(success);

    NSApplicationLoad();
    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);

    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    assert(rls != NULL);
    MMLog(BOLD CYAN "Listening for User changes" RESET);

    // Check CGS Connection
    MMLog("--- Checking CGS Connection ---");
    CGSConnectionID cid = CGSMainConnectionID();
    MMLog("CGSMainConnectionID: %d", cid);

    // Apply the cape for the user on load (if configured)
    MMLog("--- Initial Cape Check ---");
    NSString *initialCapePath = appliedCapePathForUser(NSUserName());
    MMLog("Cape path: %s", initialCapePath ? initialCapePath.UTF8String : "(none)");
    if (initialCapePath) {
        MMLog("--- Applying initial cape ---");
        BOOL applySuccess = applyCapeAtPath(initialCapePath);
        MMLog("Initial apply result: %s", applySuccess ? "SUCCESS" : "FAILED");
    } else {
        MMLog("No cape configured - running in standby mode");
    }
    // Restore scale according to the active mode
    if (customScaleMode()) {
        float maxScale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
        if (maxScale <= 0.0f) maxScale = 1.0f;
        setCursorScale(maxScale);
    } else {
        float globalScale = [MCDefault(@"MCGlobalCursorScale") floatValue];
        if (globalScale < 0.5f || globalScale > 16.0f) globalScale = 1.0f;
        setCursorScale(globalScale);
    }

    // Periodic scale nudge timer — keeps cursor registrations fresh while Helper is running
    static CFRunLoopTimerRef periodicNudgeTimer = NULL;
    CFRunLoopTimerContext timerCtx = {0, NULL, NULL, NULL, NULL};
    periodicNudgeTimer = CFRunLoopTimerCreate(
        NULL,                                                // allocator
        CFAbsoluteTimeGetCurrent() + PERIODIC_NUDGE_INTERVAL_SEC,  // first fire (60s from now)
        PERIODIC_NUDGE_INTERVAL_SEC,                         // interval (every 60s)
        0,                                                   // flags
        0,                                                   // order
        periodicNudgeCallback,                                // callback
        &timerCtx
    );
    if (periodicNudgeTimer) {
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), periodicNudgeTimer, kCFRunLoopDefaultMode);
        MMLog(BOLD CYAN "Periodic nudge timer started (interval: %.0f sec)" RESET, PERIODIC_NUDGE_INTERVAL_SEC);
    } else {
        MMLog(BOLD RED "Failed to create periodic nudge timer" RESET);
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
    MMLog("Entering run loop...");
    CFRunLoopRun();

    // Cleanup
    MMLog("Exiting run loop, cleaning up...");
    CFRunLoopSourceInvalidate(rls);
    CFRelease(rls);
    CFRelease(keys);
    CFRelease(key);
    CFRelease(store);

#ifdef DEBUG
    MCLoggerClose();
#endif
}

void startSessionMonitor(void) {
    MMLog("========================================");
    MMLog("=== SESSION MONITOR STARTED (in-app) ===");
    MMLog("========================================");

    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), UserSpaceChanged, NULL);
    assert(store != NULL);

    CFStringRef key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    assert(key != NULL);

    CFArrayRef keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    assert(keys != NULL);

    Boolean success = SCDynamicStoreSetNotificationKeys(store, keys, NULL);
    assert(success);

    CGDisplayRegisterReconfigurationCallback(reconfigurationCallback, NULL);
    MMLog(BOLD CYAN "Listening for Display changes" RESET);

    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    assert(rls != NULL);
    MMLog(BOLD CYAN "Listening for User changes" RESET);

    // Apply the cape for the user on load (if configured)
    NSString *initialCapePath = appliedCapePathForUser(NSUserName());
    if (initialCapePath) {
        BOOL applySuccess = applyCapeAtPath(initialCapePath);
        MMLog("Initial apply result: %s", applySuccess ? "SUCCESS" : "FAILED");
    } else {
        MMLog("No cape configured - running in standby mode");
    }
    // Restore scale according to the active mode
    if (customScaleMode()) {
        float maxScale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
        if (maxScale <= 0.0f) maxScale = 1.0f;
        MMLog("Session monitor: restoring custom scale %.2f", maxScale);
        setCursorScale(maxScale);
    } else {
        float globalScale = [MCDefault(@"MCGlobalCursorScale") floatValue];
        if (globalScale < 0.5f || globalScale > 16.0f) globalScale = 1.0f;
        MMLog("Session monitor: restoring global scale %.2f", globalScale);
        setCursorScale(globalScale);
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), rls, kCFRunLoopDefaultMode);
    MMLog("Session monitor attached to main run loop (non-blocking)");

    // Intentionally not releasing store/rls — they must stay alive
    // for the lifetime of the app to keep the session monitor active.
    CFRelease(keys);
    CFRelease(key);
}
