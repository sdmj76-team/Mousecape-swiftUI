//
//  HelperBridge.m
//  MousecapeHelper
//
//  Bridge between Swift and ObjC - imports all complex headers
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "../mousecloak/listen.h"
#import "../mousecloak/MCLogger.h"
#import "../mousecloak/MCPrefs.h"
#import "../mousecloak/restore.h"
#import "../mousecloak/CGSInternal/CGSCursor.h"
#import "../mousecloak/CGSInternal/CGSConnection.h"

// These functions are already provided by the .m files added to the target
// This file just ensures proper linking

// Get last applied cape path from preferences
const char* MCPrefsGetLastAppliedCapePath(void) {
    static char buffer[1024]; // Static buffer to persist after function returns

    // Read from current user + current host domain (same as AppState writes to)
    CFPropertyListRef value = CFPreferencesCopyValue(
        CFSTR("MCAppliedCursor"),
        CFSTR("com.sdmj76.Mousecape"),
        kCFPreferencesCurrentUser,
        kCFPreferencesCurrentHost
    );

    if (value) {
        NSString *path = (__bridge_transfer NSString *)value;
        if (path) {
            strncpy(buffer, [path UTF8String], sizeof(buffer) - 1);
            buffer[sizeof(buffer) - 1] = '\0'; // Ensure null termination
            return buffer;
        }
    }

    return NULL;
}

// Reset cursors to system default
void ResetCursorsToDefault(void) {
    // Use the same function as main app
    resetAllCursors();
}

// Simple logging wrapper for Swift (non-variadic)
void HelperLog(const char* message) {
    if (message) {
        MCLoggerWrite("%s\n", message);
    }
}
