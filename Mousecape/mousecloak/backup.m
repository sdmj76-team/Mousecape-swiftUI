//
//  backup.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"
#import "MCDefs.h"

NSString *backupStringForIdentifier(NSString *identifier) {
    return [NSString stringWithFormat:@"com.sdmj76.mousecape.backup.%@", identifier];
}

void backupCursorForIdentifier(NSString *ident) {
    MMLog("  Backing up: %s", ident.UTF8String);

//     For named cursors, check if registered; core cursors can be read without registration
    if (![ident hasPrefix:@"com.apple.cursor"]) {
        bool registered = false;
        MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);
        if (!registered) {
            MMLog("    Skipped - cursor not registered");
            return;
        }
    }

    NSString *backupIdent = backupStringForIdentifier(ident);
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupIdent.UTF8String, &registered);

//     don't re-back it up
    if (registered) {
        MMLog("    Skipped - backup already exists");
        return;
    }

    NSDictionary *cape = capeWithIdentifier(ident);
    if (!cape) {
        MMLog("    Skipped - no cursor data available");
        return;
    }

    // System cursors like Wait (beach ball) may have >24 frames,
    // but CGSRegisterCursorWithImages only accepts up to 24.
    // Downsample the sprite sheet before registering the backup.
    NSUInteger frameCount = [cape[MCCursorDictionaryFrameCountKey] unsignedIntegerValue];
    if (frameCount > MCMaxFrameCount) {
        MMLog("    Downsampling backup: %lu frames -> %lu frames",
              (unsigned long)frameCount, (unsigned long)MCMaxFrameCount);

        NSMutableDictionary *processed = cape.mutableCopy;
        CGFloat frameDuration = [cape[MCCursorDictionaryFrameDuratiomKey] doubleValue];
        CGFloat adjustedDuration = frameDuration * ((CGFloat)frameCount / (CGFloat)MCMaxFrameCount);
        processed[MCCursorDictionaryFrameCountKey] = @(MCMaxFrameCount);
        processed[MCCursorDictionaryFrameDuratiomKey] = @(adjustedDuration);

        NSArray *representations = cape[MCCursorDictionaryRepresentationsKey];
        NSMutableArray *newReps = [NSMutableArray array];
        for (id imageObj in representations) {
            CGImageRef spriteSheet = (__bridge CGImageRef)imageObj;
            CGImageRef downsampled = MCDownsampleSpriteSheetImage(spriteSheet, frameCount, MCMaxFrameCount);
            if (downsampled) {
                [newReps addObject:(__bridge_transfer id)downsampled];
            } else {
                [newReps addObject:imageObj];
            }
        }
        processed[MCCursorDictionaryRepresentationsKey] = newReps;
        cape = processed;
    }

    BOOL success = applyCapeForIdentifier(cape, backupIdent, YES);
    MMLog("    Backup result: %s", success ? "SUCCESS" : "FAILED");
}

void backupAllCursors(void) {
    MMLog("=== backupAllCursors ===");
    bool arrowRegistered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupStringForIdentifier(@"com.apple.coregraphics.Arrow").UTF8String, &arrowRegistered);

    if (arrowRegistered) {
        MMLog("Skipping backup, backup already exists");
//         we are already backed up
        return;
    }
    // Backup all cursors (default + synonyms)
    MMLog("--- Backing up all cursors ---");
    MCEnumerateAllCursorIdentifiers(^(NSString *name) {
        backupCursorForIdentifier(name);
    });
    // no need to backup core cursors
    MMLog("=== backupAllCursors complete ===");
}
