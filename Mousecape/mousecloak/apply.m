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
#import "innerShadow.h"
#import "outerGlow.h"
#import "scale.h"

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

    if (frameCount > 24 || frameCount < 1) {
        MMLog(BOLD RED "Frame count of %s out of range [1...24]", ident.UTF8String);
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


BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore, BOOL customScaleMode) {
    MMLog("=== applyCapeForIdentifier ===");
    MMLog("  Identifier: %s", identifier.UTF8String);
    MMLog("  Restore mode: %s", restore ? "YES" : "NO");

    if (!cursor || !identifier) {
        MMLog(BOLD RED "  Invalid cursor or identifier (bad seed)" RESET);
        return NO;
    }

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL innerShadow = MCFlag(MCPreferencesInnerShadowKey);
    BOOL outerGlow = MCFlag(MCPreferencesOuterGlowKey);
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

    if (lefty && !restore) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    // Calculate effective scale for representation selection
    // Pick the representation whose pixel size best matches the target render size
    float effectiveScale = 1.0f;
    if (customScaleMode) {
        NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
        float desiredScale = [perCursorScales[identifier] floatValue];
        if (desiredScale > 0.0f) effectiveScale = desiredScale;
    } else {
        effectiveScale = cursorScale();
        if (effectiveScale <= 0.0f) effectiveScale = 1.0f;
    }
    NSUInteger targetPixelCount = (NSUInteger)(size.width * effectiveScale) * (NSUInteger)(size.height * effectiveScale);
    MMLog("  Effective scale: %.2f, target pixel count: %lu", effectiveScale, (unsigned long)targetPixelCount);

    // Select the representation closest to the target pixel size
    // (instead of always picking the highest resolution)
    NSBitmapImageRep *bestRep = nil;
    NSUInteger bestPixelCount = 0;
    NSUInteger bestDistance = UINT_MAX;
    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object];
        } else {
            rep = [[NSBitmapImageRep alloc] initWithData:object];
        }
        rep = rep.retaggedSRGBSpace;

        NSUInteger pixelCount = (NSUInteger)rep.pixelsWide * (NSUInteger)rep.pixelsHigh;
        NSUInteger distance = (pixelCount > targetPixelCount) ?
            (pixelCount - targetPixelCount) : (targetPixelCount - pixelCount);
        // Prefer closest match; tie-break by higher pixel count
        if (distance < bestDistance || (distance == bestDistance && pixelCount > bestPixelCount)) {
            bestDistance = distance;
            bestPixelCount = pixelCount;
            bestRep = rep;
        }
    }
    MMLog("  Selected representation: %lupx (distance: %lu from target %lupx)",
          (unsigned long)bestPixelCount, (unsigned long)bestDistance, (unsigned long)targetPixelCount);

    if (bestRep) {
        if (!lefty || restore) {
            images[images.count] = (__bridge id)[bestRep CGImage];
        } else {
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:bestRep.pixelsWide
                                                                               pixelsHigh:bestRep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * bestRep.pixelsWide
                                                                             bitsPerPixel:32];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:bestRep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [bestRep drawInRect:NSMakeRect(0, 0, bestRep.pixelsWide, bestRep.pixelsHigh)
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                       fraction:1.0
                respectFlipped:NO
                         hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }

    // Apply inner shadow effect if enabled
    if (innerShadow && images.count > 0) {
        float radius = 32.0f;
        float intensity = 0.6f;
        MMLog("Applying inner shadow effect (radius=%.1f, intensity=%.1f)", radius, intensity);
        NSMutableArray *processed = [NSMutableArray arrayWithCapacity:images.count];
        for (id imgObj in images) {
            CGImageRef original = (__bridge CGImageRef)imgObj;
            CGImageRef shadowed = MCApplyInnerShadow(original, radius, intensity);
            [processed addObject:(__bridge id)(shadowed ?: original)];
            if (shadowed) CGImageRelease(shadowed);
        }
        images = processed;
    }

    // Apply outer glow effect if enabled
    if (outerGlow && images.count > 0) {
        float radius = 40.0f;
        float intensity = 0.7f;
        MMLog("Applying outer glow effect (radius=%.1f, intensity=%.1f)", radius, intensity);
        NSMutableArray *processed = [NSMutableArray arrayWithCapacity:images.count];
        for (id imgObj in images) {
            CGImageRef original = (__bridge CGImageRef)imgObj;
            CGImageRef glowing = MCApplyOuterGlow(original, radius, intensity);
            [processed addObject:(__bridge id)(glowing ?: original)];
            if (glowing) CGImageRelease(glowing);
        }
        images = processed;
    }

    // Per-cursor custom scaling
    if (customScaleMode) {
        NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
        MMLog("SCALE DEBUG per-cursor %s: perCursorScales=%@, customMode=YES", identifier.UTF8String, perCursorScales);
        float desiredScale = [perCursorScales[identifier] floatValue];
        if (desiredScale <= 0.0f) desiredScale = 1.0f;

        float maxScale = cursorScale(); // Read current system scale directly from CGS
        if (maxScale <= 0.0f) maxScale = 1.0f;
        float ratio = (maxScale > 0) ? desiredScale / maxScale : 1.0f;
        MMLog("SCALE DEBUG per-cursor %s: desired=%.2f, maxScale=%.2f, ratio=%.3f",
              identifier.UTF8String, desiredScale, maxScale, ratio);

        // Scale when ratio differs from 1.0 (handles both down-scaling AND up-scaling)
        if (ratio < 0.99f || ratio > 1.01f) {
            // Scale the logical size proportionally so the cursor appears at the correct visual size
            size = CGSizeMake(size.width * ratio, size.height * ratio);
            MMLog("Custom scaling %s: desired=%.2f, max=%.2f, ratio=%.3f, newSize=%.1fx%.1f",
                  identifier.UTF8String, desiredScale, maxScale, ratio, size.width, size.height);

            CGColorSpaceRef scaleColorSpace = CGColorSpaceCreateDeviceRGB();
            NSMutableArray *scaledImages = [NSMutableArray arrayWithCapacity:images.count];
            for (id imgObj in images) {
                CGImageRef original = (__bridge CGImageRef)imgObj;
                size_t w = CGImageGetWidth(original);
                size_t h = CGImageGetHeight(original);
                size_t newW = MAX((size_t)(w * ratio + 0.5f), 1);
                size_t newH = MAX((size_t)(h * ratio + 0.5f), 1);

                CGContextRef ctx = CGBitmapContextCreate(
                    nil, newW, newH, 8, newW * 4,
                    scaleColorSpace,
                    kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big
                );
                if (ctx) {
                    CGContextDrawImage(ctx, CGRectMake(0, 0, newW, newH), original);
                    CGImageRef scaledImg = CGBitmapContextCreateImage(ctx);
                    CGContextRelease(ctx);
                    [scaledImages addObject:(__bridge id)(scaledImg ?: original)];
                    if (scaledImg) CGImageRelease(scaledImg);
                } else {
                    MMLog("Failed to create scaling context for %s", identifier.UTF8String);
                    [scaledImages addObject:imgObj];
                }
            }
            CGColorSpaceRelease(scaleColorSpace);
            images = scaledImages;

            // Scale hotspot proportionally with the image to maintain correct position
            hotSpot = CGPointMake(hotSpot.x * ratio, hotSpot.y * ratio);
            MMLog("Hotspot scaled by ratio %.3f: (%.1f, %.1f)", ratio, hotSpot.x, hotSpot.y);
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

        // Save the current system scale BEFORE resetAllCursors() might reset it
        float savedScale = cursorScale();
        MMLog("Saved system scale before reset: %.2f", savedScale);

        MMLog("--- Calling resetAllCursors ---");
        resetAllCursors();
        MMLog("--- Calling backupAllCursors ---");
        backupAllCursors();

        // Read scale mode from direct C variable (not CFPreferences)
        BOOL isCustomMode = customScaleMode();

        if (isCustomMode) {
            float maxScale = 1.0f;
            NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
            if (perCursorScales) {
                for (NSNumber *val in perCursorScales.allValues) {
                    float s = val.floatValue;
                    if (s > maxScale) maxScale = s;
                }
            }
            MMLog("SCALE DEBUG: custom mode, maxScale=%.2f", maxScale);
            setCursorScale(maxScale);
            // Save maxScale as MCCursorScale so listen.m can restore it
            MCSetDefault(@(maxScale), MCPreferencesCursorScaleKey);
        } else {
            // Global mode: restore the exact scale that was active before reset
            MMLog("SCALE DEBUG: global mode, restoring to %.2f", savedScale);
            if (savedScale >= 0.5f && savedScale <= 16.0f) {
                setCursorScale(savedScale);
            } else {
                setCursorScale(defaultCursorScale());
            }
        }

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

            BOOL success = applyCapeForIdentifier(cape, key, NO, isCustomMode);
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

NSDictionary *applyCapeWithResult(NSDictionary *dictionary) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];

        MMLog("========================================");
        MMLog("=== APPLYING CAPE WITH RESULT ===");
        MMLog("========================================");
        MMLog("Cape name: %s", name.UTF8String);
        MMLog("Cape identifier: %s", [dictionary[MCCursorDictionaryIdentifierKey] UTF8String]);
        MMLog("Total cursors: %lu", (unsigned long)cursors.count);

        // Save the current system scale BEFORE resetAllCursors() might reset it
        float savedScale = cursorScale();
        MMLog("Saved system scale before reset: %.2f", savedScale);

        MMLog("--- Calling resetAllCursors ---");
        resetAllCursors();
        MMLog("--- Calling backupAllCursors ---");
        backupAllCursors();

        // Read scale mode from direct C variable (not CFPreferences)
        BOOL isCustomMode = customScaleMode();

        if (isCustomMode) {
            float maxScale = 1.0f;
            NSDictionary *perCursorScales = MCDefault(MCPreferencesPerCursorScalesKey);
            if (perCursorScales) {
                for (NSNumber *val in perCursorScales.allValues) {
                    float s = val.floatValue;
                    if (s > maxScale) maxScale = s;
                }
            }
            MMLog("SCALE DEBUG: custom mode, maxScale=%.2f", maxScale);
            setCursorScale(maxScale);
            // Save maxScale as MCCursorScale so listen.m can restore it
            MCSetDefault(@(maxScale), MCPreferencesCursorScaleKey);
        } else {
            MMLog("SCALE DEBUG: global mode, restoring to %.2f", savedScale);
            if (savedScale >= 0.5f && savedScale <= 16.0f) {
                setCursorScale(savedScale);
            } else {
                setCursorScale(defaultCursorScale());
            }
        }

        MMLog("--- Applying cursors ---");

        NSUInteger successCount = 0;
        NSUInteger skippedCount = 0;
        NSUInteger failedCount = 0;
        NSMutableArray *failedIdentifiers = [NSMutableArray array];
        NSMutableArray *skippedIdentifiers = [NSMutableArray array];

        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);

            // Check if cursor has valid image data before attempting to apply
            NSArray *reps = cape[MCCursorDictionaryRepresentationsKey];
            if (!reps || reps.count == 0) {
                MMLog(YELLOW "  Skipping cursor %s - no image data" RESET, key.UTF8String);
                skippedCount++;
                [skippedIdentifiers addObject:key];
                continue;
            }

            BOOL success = applyCapeForIdentifier(cape, key, NO, isCustomMode);
            if (!success) {
                MMLog(YELLOW "  Failed to apply cursor %s" RESET, key.UTF8String);
                failedCount++;
                [failedIdentifiers addObject:key];
            } else {
                successCount++;
            }
        }

        MMLog("--- Application Summary ---");
        MMLog("  Total cursors: %lu", (unsigned long)cursors.count);
        MMLog("  Successfully applied: %lu", (unsigned long)successCount);
        MMLog("  Skipped (no images): %lu", (unsigned long)skippedCount);
        MMLog("  Failed: %lu", (unsigned long)failedCount);

        // Only save applied cursor preference if at least one cursor succeeded
        if (successCount > 0) {
            MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);
        }

        MMLog("========================================");

        // Return detailed result dictionary
        return @{
            @"success": @(successCount > 0),
            @"successCount": @(successCount),
            @"skippedCount": @(skippedCount),
            @"failedCount": @(failedCount),
            @"failedIdentifiers": [failedIdentifiers copy],
            @"skippedIdentifiers": [skippedIdentifiers copy]
        };
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
