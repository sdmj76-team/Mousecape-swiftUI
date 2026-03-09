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
