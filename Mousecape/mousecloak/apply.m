//
//  apply.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "create.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"
#import "NSBitmapImageRep+ColorSpace.h"
#import "MCDefs.h"

// Helper function to check if cursor type should be mirrored in left-hand mode
static BOOL shouldMirrorCursorType(NSString *identifier) {
    static NSSet *noMirrorTypes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        noMirrorTypes = [NSSet setWithArray:@[
            @"com.apple.cursor.29",  // windowNE
            @"com.apple.cursor.33",  // windowNW
            @"com.apple.cursor.35",  // windowSE
            @"com.apple.cursor.37",  // windowSW
            @"com.apple.cursor.30",  // windowNESW
            @"com.apple.cursor.34"   // windowNWSE
        ]];
    });
    return ![noMirrorTypes containsObject:identifier];
}

static BOOL MCRegisterImagesForCursorName(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *name) {
    char *cursorName = (char *)name.UTF8String;
    int seed = 0;
    CGSConnectionID cid = CGSMainConnectionID();

    MMLog("--- Registering cursor ---");
    MMLog("  Name: %s", cursorName);
    MMLog("  CGSConnectionID: %d", cid);
    MMLog("  Size: %.1fx%.1f points", size.width, size.height);
    MMLog("  HotSpot: (%.1f, %.1f)", hotSpot.x, hotSpot.y);
    MMLog("  Frames: %lu, Duration: %.4f sec", (unsigned long)frameCount, frameDuration);
    MMLog("  Images array count: %lu", (unsigned long)[images count]);

#ifdef DEBUG
    // Log detailed image info in DEBUG mode
    for (NSUInteger i = 0; i < images.count; i++) {
        CGImageRef img = (__bridge CGImageRef)images[i];
        if (img) {
            MMLog("    Image[%lu]: %zux%zu pixels, %zu bpc, %zu bpp",
                  (unsigned long)i,
                  CGImageGetWidth(img),
                  CGImageGetHeight(img),
                  CGImageGetBitsPerComponent(img),
                  CGImageGetBitsPerPixel(img));
        }
    }
#endif

    // Validate and clamp hot spot to valid range to prevent CGError=1000
    // The hot spot coordinates must be within cursor dimensions (0 <= hotSpot < MCMaxHotspotValue)
    BOOL clamped = NO;
    if (hotSpot.x < 0) {
        hotSpot.x = 0;
        clamped = YES;
    } else if (hotSpot.x > MCMaxHotspotValue) {
        hotSpot.x = MCMaxHotspotValue;
        clamped = YES;
    }
    if (hotSpot.y < 0) {
        hotSpot.y = 0;
        clamped = YES;
    } else if (hotSpot.y > MCMaxHotspotValue) {
        hotSpot.y = MCMaxHotspotValue;
        clamped = YES;
    }

    if (clamped) {
        MMLog(YELLOW "  Hot spot was out of bounds, clamped to (%.1f, %.1f)" RESET, hotSpot.x, hotSpot.y);
    }

    MMLog("  Calling CGSRegisterCursorWithImages...");

    CGError err = CGSRegisterCursorWithImages(cid,
                                              cursorName,
                                              true,
                                              true,
                                              size,
                                              hotSpot,
                                              frameCount,
                                              frameDuration,
                                              (__bridge CFArrayRef)images,
                                              &seed);

    MMLog("  Result: %s (CGError=%d, seed=%d)",
          (err == kCGErrorSuccess) ? "SUCCESS" : "FAILED", err, seed);

    return (err == kCGErrorSuccess);
}

BOOL applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount) {
    MMLog("=== applyCursorForIdentifier ===");
    MMLog("  Identifier: %s", ident.UTF8String);

    if (frameCount > MCMaxFrameCount || frameCount < 1) {
        MMLog(BOLD RED "Frame count of %s out of range [1...%lu]", ident.UTF8String, (unsigned long)MCMaxFrameCount);
        return NO;
    }

    // Special handling for Arrow on newer macOS where the underlying name may have changed.
    BOOL isArrow = ([ident isEqualToString:@"com.apple.coregraphics.Arrow"] || [ident isEqualToString:@"com.apple.coregraphics.ArrowCtx"]);
    BOOL isIBeam = ([ident isEqualToString:@"com.apple.coregraphics.IBeam"] || [ident isEqualToString:@"com.apple.coregraphics.IBeamXOR"]);

    MMLog("  Is Arrow: %s, Is IBeam: %s", isArrow ? "YES" : "NO", isIBeam ? "YES" : "NO");

    if (isArrow) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCArrowSynonyms();
        MMLog("  Arrow synonyms to register: %lu", (unsigned long)synonyms.count);
        for (NSString *syn in synonyms) {
            MMLog("    - %s", syn.UTF8String);
        }

        // Register for all discovered Arrow-related names.
        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        // Also try the legacy identifier if it wasn't in the discovered set.
        if (![synonyms containsObject:ident]) {
            MMLog("  Trying legacy identifier: %s", ident.UTF8String);
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }

        // Reduce the chance of the Dock overriding the cursor immediately after registration.
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        MMLog("  Arrow registration result: %s", anySuccess ? "SUCCESS" : "FAILED");
        return anySuccess;
    }

    // Special handling for I-beam (text cursor) on newer macOS
    if (isIBeam) {
        BOOL anySuccess = NO;
        NSArray *synonyms = MCIBeamSynonyms();
        MMLog("  IBeam synonyms to register: %lu", (unsigned long)synonyms.count);
        for (NSString *syn in synonyms) {
            MMLog("    - %s", syn.UTF8String);
        }

        for (NSString *name in synonyms) {
            if (name.length == 0) {
                continue;
            }
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, name)) {
                anySuccess = YES;
            }
        }
        if (![synonyms containsObject:ident]) {
            MMLog("  Trying legacy identifier: %s", ident.UTF8String);
            if (MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident)) {
                anySuccess = YES;
            }
        }
        CGSSetDockCursorOverride(CGSMainConnectionID(), false);
        MMLog("  IBeam registration result: %s", anySuccess ? "SUCCESS" : "FAILED");
        return anySuccess;
    }

    // Default behavior for all other cursors.
    MMLog("  Using default registration");
    return MCRegisterImagesForCursorName(frameCount, frameDuration, hotSpot, size, images, ident);
}

BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore) {
    MMLog("=== applyCapeForIdentifier ===");
    MMLog("  Identifier: %s", identifier.UTF8String);
    MMLog("  Restore mode: %s", restore ? "YES" : "NO");

    if (!cursor || !identifier) {
        MMLog(BOLD RED "  Invalid cursor or identifier (bad seed)" RESET);
        return NO;
    }

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL pointer = MCCursorIsPointer(identifier);
    NSNumber *frameCount    = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = cursor[MCCursorDictionaryFrameDuratiomKey];

    MMLog("  Lefty mode: %s", lefty ? "YES" : "NO");
    MMLog("  Is pointer: %s", pointer ? "YES" : "NO");
    MMLog("  FrameCount: %s", frameCount.description.UTF8String);
    MMLog("  FrameDuration: %s", frameDuration.description.UTF8String);
    //    NSNumber *repeatCount   = cursor[MCCursorDictionaryRepeatCountKey];
    
    CGPoint hotSpot         = CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]);
    CGSize size             = CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]);
    NSArray *reps           = cursor[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *images  = [NSMutableArray array];

    MMLog("  HotSpot: (%.1f, %.1f)", hotSpot.x, hotSpot.y);
    MMLog("  Size: %.1fx%.1f", size.width, size.height);
    MMLog("  Representations count: %lu", (unsigned long)[reps count]);

    BOOL shouldMirror = lefty && !restore && shouldMirrorCursorType(identifier);
    if (shouldMirror) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object];
        } else {
            rep = [[NSBitmapImageRep alloc] initWithData:object];
        }
        rep = rep.retaggedSRGBSpace;

        if (!shouldMirror) {
            // special case if array has a type of CGImage already there is no need to convert it
            if (type == CGImageGetTypeID()) {
                images[images.count] = object;
                continue;
            }

            images[images.count] = (__bridge id)[rep CGImage];

        } else {
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:rep.pixelsWide
                                                                               pixelsHigh:rep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * rep.pixelsWide
                                                                             bitsPerPixel:32];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:rep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh)
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:1.0
             respectFlipped:NO
                      hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }
    
    return applyCursorForIdentifier(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier, 0);
}

BOOL applyCape(NSDictionary *dictionary) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];

        MMLog("========================================");
        MMLog("=== APPLYING CAPE ===");
        MMLog("========================================");
        MMLog("Cape name: %s", name.UTF8String);
        MMLog("Cape identifier: %s", [dictionary[MCCursorDictionaryIdentifierKey] UTF8String]);
        MMLog("Cape version: %.2f", version.floatValue);
        MMLog("Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("Cursor identifiers:");
        for (NSString *key in cursors) {
            MMLog("  - %s", key.UTF8String);
        }

        MMLog("--- Calling resetAllCursors ---");
        resetAllCursors();
        MMLog("--- Calling backupAllCursors ---");
        backupAllCursors();

        MMLog("--- Applying cursors ---");

        NSUInteger successCount = 0;
        NSUInteger skippedCount = 0;
        NSUInteger failedCount = 0;

        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);

            // Check if cursor has valid image data before attempting to apply
            NSArray *reps = cape[MCCursorDictionaryRepresentationsKey];
            if (!reps || reps.count == 0) {
                MMLog(YELLOW "  Skipping cursor %s - no image data (Representations count: 0)" RESET, key.UTF8String);
                skippedCount++;
                continue;
            }

            BOOL success = applyCapeForIdentifier(cape, key, NO);
            if (!success) {
                MMLog(YELLOW "  Failed to apply cursor %s - continuing with remaining cursors..." RESET, key.UTF8String);
                failedCount++;
            } else {
                successCount++;
            }
        }

        MMLog("--- Application Summary ---");
        MMLog("  Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("  Successfully applied: %lu", (unsigned long)successCount);
        MMLog("  Skipped (no images): %lu", (unsigned long)skippedCount);
        MMLog("  Failed: %lu", (unsigned long)failedCount);

        // Consider the cape application successful if at least one cursor was applied
        if (successCount == 0) {
            MMLog(BOLD RED "No cursors were successfully applied!" RESET);
            return NO;
        }

        MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);

        if (skippedCount > 0 || failedCount > 0) {
            MMLog(BOLD GREEN "Applied %s with warnings (success: %lu, skipped: %lu, failed: %lu)" RESET,
                  name.UTF8String, (unsigned long)successCount, (unsigned long)skippedCount, (unsigned long)failedCount);
        } else {
            MMLog(BOLD GREEN "Applied %s successfully! (all %lu cursors)" RESET, name.UTF8String, (unsigned long)successCount);
        }
        MMLog("========================================");

        return YES;
    }
}

BOOL applyCapeAtPath(NSString *path) {
    MMLog("========================================");
    MMLog("=== applyCapeAtPath ===");
    MMLog("========================================");
    MMLog("Input path: %s", path ? path.UTF8String : "(null)");

    // Validate path
    if (!path || path.length == 0) {
        MMLog(BOLD RED "Invalid path" RESET);
        return NO;
    }

    // Resolve symlinks and check for path traversal
    NSString *realPath = [path stringByResolvingSymlinksInPath];
    NSString *standardPath = [realPath stringByStandardizingPath];

    MMLog("Real path: %s", realPath.UTF8String);
    MMLog("Standard path: %s", standardPath.UTF8String);
    MMLog("File exists: %s", [[NSFileManager defaultManager] fileExistsAtPath:standardPath] ? "YES" : "NO");
    MMLog("File readable: %s", [[NSFileManager defaultManager] isReadableFileAtPath:standardPath] ? "YES" : "NO");

    // Validate file extension
    if (![[standardPath pathExtension] isEqualToString:@"cape"]) {
        MMLog(BOLD RED "Invalid file extension - must be .cape" RESET);
        return NO;
    }

    // Check file exists and is readable
    if (![[NSFileManager defaultManager] isReadableFileAtPath:standardPath]) {
        MMLog(BOLD RED "File not readable at path" RESET);
        return NO;
    }

    MMLog("Loading cape file...");
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:standardPath];
    if (cape) {
        MMLog("Cape file loaded successfully, applying...");
        return applyCape(cape);
    }
    MMLog(BOLD RED "Could not parse valid cape file" RESET);
    return NO;
}
