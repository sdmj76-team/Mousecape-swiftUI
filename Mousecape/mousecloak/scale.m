//
//  scale.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "scale.h"
#import "MCPrefs.h"
#import "MCDefs.h"
#import "CGSCursor.h"
#import <math.h>

// Process-local cache of scale mode — initialized lazily from CFPreferences
// on first access to avoid stale defaults across multiple processes.
static BOOL g_customScaleMode = NO;
static BOOL g_scaleModeInitialized = NO;

float cursorScale(void) {
    float value;
    CGSGetCursorScale(CGSMainConnectionID(), &value);
    return value;
}

float defaultCursorScale(void) {
    float scale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
    if (scale < .5 || scale > 16)
        scale = 1;
    return scale;
}

BOOL setCursorScale(float dbl) {
    if (!isfinite(dbl) || dbl <= 0 || dbl > 16) {
        MMLog(BOLD RED "Invalid cursor scale (must be 0 < scale <= 16)" RESET);
        return NO;
    } else if (CGSSetCursorScale(CGSMainConnectionID(), dbl) == noErr) {
        MMLog("Successfully set cursor scale!");
        return YES;
    } else {
        MMLog("Somehow failed to set cursor scale!");
        return NO;
    }
}

BOOL customScaleMode(void) {
    if (!g_scaleModeInitialized) {
        g_scaleModeInitialized = YES;
        NSString *mode = (__bridge_transfer NSString *)CFPreferencesCopyValue(
            CFSTR("MCScaleMode"),
            CFSTR("com.sdmj76.Mousecape"),
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        );
        g_customScaleMode = [mode isEqualToString:@"custom"];
        MMLog("Scale mode initialized from preferences: %s", g_customScaleMode ? "custom" : "global");
    }
    return g_customScaleMode;
}

void setCustomScaleMode(BOOL isCustom) {
    g_customScaleMode = isCustom;
    g_scaleModeInitialized = YES;

    // Persist to CFPreferences so other processes (Helper) pick up the change
    NSString *modeValue = isCustom ? @"custom" : @"global";
    CFPreferencesSetValue(
        CFSTR("MCScaleMode"),
        (__bridge CFPropertyListRef)modeValue,
        CFSTR("com.sdmj76.Mousecape"),
        kCFPreferencesCurrentUser,
        kCFPreferencesCurrentHost
    );
    CFPreferencesSynchronize(
        CFSTR("com.sdmj76.Mousecape"),
        kCFPreferencesCurrentUser,
        kCFPreferencesCurrentHost
    );

    MMLog("Scale mode set to: %s", isCustom ? "custom" : "global");
}
