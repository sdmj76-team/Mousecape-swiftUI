//
//  create.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "create.h"
#import "NSCursor_Private.h"
#import "NSBitmapImageRep+ColorSpace.h"
#import "MCDefs.h"
#import "MCPrefs.h"
#import "restore.h"

NSError *createCape(NSString *input, NSString *output, BOOL convert) {
    NSDictionary *cape;
    if (convert)
        cape = createCapeFromMightyMouse([NSDictionary dictionaryWithContentsOfFile:input], nil);
    else
        cape = createCapeFromDirectory(input);
    
    if (!cape) {
        if (convert)
            return [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode userInfo:@{
                                                                                                 NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to create cape file", nil),
                                                                                                 NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Unable to create a cape from the file specified.", nil) }];
        else
            return [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidCapeCode userInfo:@{
                                                                                                 NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to create cape file", nil),
                                                                                                 NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Unable to create a cape from the directory specified.", nil) }];
    }
    
    if (![cape writeToFile:output atomically:NO]) {
        return [NSError errorWithDomain:MCErrorDomain code:MCErrorWriteFailCode userInfo:@{
                                                                                           NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to create cape file", nil),
                                                                                           NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: NSLocalizedString(@"The destination, %@, is not writable.", nil), output] }];
    }

    return nil;
}

NSDictionary *createCapeFromDirectory(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    
    BOOL isDir;
    BOOL exists = [manager fileExistsAtPath:path isDirectory:&isDir];
    
    if (!exists || !isDir)
        return nil;
    
    NSArray *contents = [manager contentsOfDirectoryAtPath:path error:nil];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@(MCCursorCreatorVersion) forKey:MCCursorDictionaryVersionKey];
    [dictionary setObject:@(MCCursorParserVersion) forKey:MCCursorDictionaryMinimumVersionKey];
    
    CGFloat version = 0.0;

    MMLog(BOLD "Enter metadata for cape:" RESET);
    NSString *author = MMGet(@"Author");
    NSString *identifier = MMGet(@"Identifier");
    NSString *name = MMGet(@"Cape Name");
    MMLog("Cape Version: ");
    if (scanf("%lf", &version) != 1 || version < 0 || version > 1000) {
        MMLog(BOLD RED "Invalid version number" RESET);
        return nil;
    }
    // Clear input buffer
    int c; while ((c = getchar()) != '\n' && c != EOF);
    NSString *hidpi = MMGet(@"HiDPI? (y/n)");
    
    MMLog("");
    
    BOOL HiDPI = [hidpi isEqualToString:@"y"];
    
    [dictionary setObject:author forKey:MCCursorDictionaryAuthorKey];
    [dictionary setObject:identifier forKey:MCCursorDictionaryIdentifierKey];
    [dictionary setObject:name forKey:MCCursorDictionaryCapeNameKey];
    [dictionary setObject:@(version) forKey:MCCursorDictionaryCapeVersionKey];
    [dictionary setObject:@NO forKey:MCCursorDictionaryCloudKey];
    [dictionary setObject:@(HiDPI) forKey:MCCursorDictionaryHiDPIKey];
    
    NSMutableDictionary *cursors = [NSMutableDictionary dictionary];
    
    for (NSString *subpath in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:subpath];
        
        [manager fileExistsAtPath:fullPath isDirectory:&isDir];
        
        if (!isDir)
            continue;
        
        NSString *ident = subpath;
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        
        NSUInteger fC;
        CGFloat hotX, hotY, pW, pH, fD;
        printf(BOLD "Need metadata for %s." RESET, [ident cStringUsingEncoding:NSUTF8StringEncoding]);
        printf("X Hotspot: ");
        if (scanf("%lf", &hotX) != 1 || hotX < 0 || hotX > 1024) {
            MMLog(BOLD RED "Invalid X Hotspot (0-1024)" RESET);
            continue;
        }
        printf("Y Hotspot: ");
        if (scanf("%lf", &hotY) != 1 || hotY < 0 || hotY > 1024) {
            MMLog(BOLD RED "Invalid Y Hotspot (0-1024)" RESET);
            continue;
        }
        printf("Points Wide: ");
        if (scanf("%lf", &pW) != 1 || pW <= 0 || pW > 1024) {
            MMLog(BOLD RED "Invalid Points Wide (1-1024)" RESET);
            continue;
        }
        printf("Points High: ");
        if (scanf("%lf", &pH) != 1 || pH <= 0 || pH > 1024) {
            MMLog(BOLD RED "Invalid Points High (1-1024)" RESET);
            continue;
        }
        printf("Frame Count: ");
        if (scanf("%lu", &fC) != 1 || fC < 1 || fC > 24) {
            MMLog(BOLD RED "Invalid Frame Count (1-24)" RESET);
            continue;
        }
        printf("Frame Duration: ");
        if (scanf("%lf", &fD) != 1 || fD < 0 || fD > 60) {
            MMLog(BOLD RED "Invalid Frame Duration (0-60)" RESET);
            continue;
        }
        
        NSMutableArray *representations = [NSMutableArray array];
        NSArray *repNames = [manager contentsOfDirectoryAtPath:fullPath error:nil];
        for (NSString *rep in repNames) {
            NSString *repPath = [fullPath stringByAppendingPathComponent:rep];
            
            [manager fileExistsAtPath:repPath isDirectory:&isDir];
            if (isDir || [rep isEqualToString:@".DS_Store"])
                continue;
            
            NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:repPath]];
            if (image) {
                NSData *pngData = [image.ensuredSRGBSpace TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
                [representations addObject:pngData];
            }
            
        }
        
        [data setObject:@(hotX) forKey:MCCursorDictionaryHotSpotXKey];
        [data setObject:@(hotY) forKey:MCCursorDictionaryHotSpotYKey];
        [data setObject:@(pW) forKey:MCCursorDictionaryPointsWideKey];
        [data setObject:@(pH) forKey:MCCursorDictionaryPointsHighKey];
        [data setObject:@(fC) forKey:MCCursorDictionaryFrameCountKey];
        [data setObject:@(fD) forKey:MCCursorDictionaryFrameDuratiomKey];
        
        [data setObject:representations forKey:MCCursorDictionaryRepresentationsKey];
        [cursors setObject:data forKey:identifier];
    }
    
    if (cursors.count == 0)
        return nil;
    
    [dictionary setObject:cursors forKey:MCCursorDictionaryCursorsKey];
    
    return dictionary;
}

NSDictionary *createCapeFromMightyMouse(NSDictionary *mightyMouse, NSDictionary *metadata) {
    if (!mightyMouse)
        return nil;
    
    NSDictionary *cursors    = mightyMouse[@"Cursors"];
    NSDictionary *global     = cursors[@"Global"];
    NSDictionary *cursorData = cursors[@"Cursor Data"];
    NSDictionary *identifiers = global[@"Identifiers"];
    
    if (!cursors || !global || !identifiers || !cursorData) {
        MMLog(BOLD RED "Mighty Mouse format either invalid or unrecognized." RESET);
        return nil;
    }
    
    NSMutableDictionary *convertedCursors = [NSMutableDictionary dictionary];
    
    for (NSString *key in identifiers) {
        MMLog("Converting cursor: %s", key.UTF8String);
        
        NSMutableDictionary *currentCursor = [NSMutableDictionary dictionary];
        
        NSDictionary *info = identifiers[key];
        NSString *customKey = info[@"Custom Key"];
        
        NSDictionary *data = cursorData[customKey];
        
        NSNumber *bpp   = data[@"BitsPerPixel"];
        NSNumber *bps   = data[@"BitsPerSample"];
        NSNumber *bpr   = data[@"BytesPerRow"];
        NSData *rawData = data[@"CursorData"];
        NSNumber *spp   = data[@"SamplesPerPixel"];
        
        NSNumber *fc    = data[@"FrameCount"];
        NSNumber *fd    = data[@"FrameDuration"];
        NSNumber *hotX  = data[@"HotspotX"];
        NSNumber *hotY  = data[@"HotspotY"];
        NSNumber *wide  = data[@"PixelsWide"];
        NSNumber *high  = data[@"PixelsHigh"];
        
        unsigned char *bytes = (unsigned char*)rawData.bytes;
        
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bytes
                                                                        pixelsWide:wide.integerValue
                                                                        pixelsHigh:high.integerValue * fc.integerValue
                                                                     bitsPerSample:bps.integerValue
                                                                   samplesPerPixel:spp.integerValue
                                                                          hasAlpha:YES
                                                                          isPlanar:NO
                                                                    colorSpaceName:NSDeviceRGBColorSpace
                                                                      bitmapFormat:NSBitmapFormatAlphaFirst | kCGBitmapByteOrder32Big
                                                                       bytesPerRow:bpr.integerValue
                                                                      bitsPerPixel:bpp.integerValue];
        
        currentCursor[MCCursorDictionaryRepresentationsKey] = @[ [rep.ensuredSRGBSpace TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] ];
        currentCursor[MCCursorDictionaryPointsWideKey]      = wide;
        currentCursor[MCCursorDictionaryPointsHighKey]      = high;
        currentCursor[MCCursorDictionaryHotSpotXKey]        = hotX;
        currentCursor[MCCursorDictionaryHotSpotYKey]        = hotY;
        currentCursor[MCCursorDictionaryFrameCountKey]      = fc;
        currentCursor[MCCursorDictionaryFrameDuratiomKey]   = fd;
        
        convertedCursors[key] = currentCursor;
    }
    
    if (convertedCursors.count == 0) {
        MMLog(BOLD RED "No cursors to convert in file." RESET);
        return nil;
    }
    
    NSMutableDictionary *totalDict = [NSMutableDictionary dictionary];
    
    totalDict[MCCursorDictionaryCursorsKey]        = convertedCursors;
    totalDict[MCCursorDictionaryVersionKey]        = @(MCCursorCreatorVersion);
    totalDict[MCCursorDictionaryMinimumVersionKey] = @(MCCursorParserVersion);
    totalDict[MCCursorDictionaryHiDPIKey]          = @NO;
    totalDict[MCCursorDictionaryCloudKey]          = @NO;
    
    CGFloat version = 0.0;
    
    MMLog(BOLD "Enter metadata for cape:" RESET);
    NSString *author = metadata[@"author"] ?: MMGet(@"Author");
    NSString *identifier = metadata[@"identifier"] ?: MMGet(@"Identifier");
    NSString *name = metadata[@"name"] ?: MMGet(@"Cape Name");
    
    if (metadata[@"version"])
        version = [metadata[@"version"] doubleValue];
    else {
        MMLog("Cape Version: ");
        if (scanf("%lf", &version) != 1 || version < 0 || version > 1000) {
            MMLog(BOLD RED "Invalid version number" RESET);
            return nil;
        }
    }
    
    totalDict[MCCursorDictionaryAuthorKey]      = author;
    totalDict[MCCursorDictionaryCapeNameKey]    = name;
    totalDict[MCCursorDictionaryCapeVersionKey] = @(version);
    totalDict[MCCursorDictionaryIdentifierKey]  = identifier;
    
    return totalDict;
}

// Alias mapping for cursors that share the same image data on newer macOS.
// When dumping, if a cursor returns nil or a placeholder, use the primary cursor's data.
static NSDictionary *cursorAliasMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"com.apple.coregraphics.ArrowCtx": @"com.apple.coregraphics.Arrow",
            @"com.apple.coregraphics.IBeamXOR": @"com.apple.coregraphics.IBeam",
            @"com.apple.coregraphics.ArrowS":   @"com.apple.coregraphics.Arrow",
            @"com.apple.coregraphics.IBeamS":   @"com.apple.coregraphics.IBeam",
        };
    });
    return map;
}

NSDictionary *processedCapeWithIdentifier(NSString *identifier) {
    NSMutableDictionary *dict = capeWithIdentifier(identifier).mutableCopy;
    if (!dict)
        return nil;

    NSUInteger frameCount = [dict[MCCursorDictionaryFrameCountKey] unsignedIntegerValue];
    NSArray *representations = dict[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *reps = [NSMutableArray array];

    // Downsample animated cursors exceeding max frame count (e.g. Wait beach ball)
    if (frameCount > MCMaxFrameCount) {
        MMLog("  Downsampling %s: %lu frames -> %lu frames",
              identifier.UTF8String, (unsigned long)frameCount, (unsigned long)MCMaxFrameCount);

        CGFloat frameDuration = [dict[MCCursorDictionaryFrameDuratiomKey] doubleValue];
        CGFloat adjustedDuration = frameDuration * ((CGFloat)frameCount / (CGFloat)MCMaxFrameCount);
        dict[MCCursorDictionaryFrameCountKey] = @(MCMaxFrameCount);
        dict[MCCursorDictionaryFrameDuratiomKey] = @(adjustedDuration);

        for (id imageObj in representations) {
            CGImageRef spriteSheet = (__bridge CGImageRef)imageObj;
            CGImageRef downsampled = MCDownsampleSpriteSheetImage(spriteSheet, frameCount, MCMaxFrameCount);
            if (downsampled) {
                NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:downsampled];
                [reps addObject:tiffDataForImage(rep.ensuredSRGBSpace)];
                CGImageRelease(downsampled);
            } else {
                NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:spriteSheet];
                [reps addObject:tiffDataForImage(rep.ensuredSRGBSpace)];
            }
        }
    } else {
        for (id imageObj in representations) {
            CGImageRef im = (__bridge CGImageRef)imageObj;
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:im];
            [reps addObject:tiffDataForImage(rep.ensuredSRGBSpace)];
        }
    }

    dict[MCCursorDictionaryRepresentationsKey] = reps;
    return dict;
}

BOOL dumpCursorsToFile(NSString *path, BOOL (^progress)(NSUInteger current, NSUInteger total)) {
    MMLog("Dumping current cursors...");

    float originalScale;
    CGSGetCursorScale(CGSMainConnectionID(), &originalScale);

    // Save and reset cursor scale preference to 1.0 so captured data
    // is independent of the user's current cursor scale setting (e.g. 1.5x).
    id originalScalePref = MCDefault(MCPreferencesCursorScaleKey);
    MCSetDefault(@1.0, MCPreferencesCursorScaleKey);
    CGSSetCursorScale(CGSMainConnectionID(), 1.0);
    CGSHideCursor(CGSMainConnectionID());

    // Cleanup block — restores cursor scale preference and CGS scale
    void (^cleanup)(void) = ^{
        CGSSetCursorScale(CGSMainConnectionID(), originalScale);
        CGSShowCursor(CGSMainConnectionID());
        MCSetDefault(originalScalePref, MCPreferencesCursorScaleKey);
    };

    NSInteger total = 11 + 43;
    NSInteger current = 0;

    NSMutableDictionary *cursors = [NSMutableDictionary dictionary];
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        if (progress) {
            current = i;

            if (!progress(current, total)) {
                cleanup();
                return NO;
            }
        }
        MMLog("Gathering data for %s", key.UTF8String);
        NSDictionary *capeData = processedCapeWithIdentifier(key);
        // On newer macOS, some cursors are aliases of others (e.g. ArrowCtx -> Arrow,
        // IBeamXOR -> IBeam). The system may either return nil or a tiny placeholder
        // image (e.g. 8x8 pixels) instead of real cursor data.
        // Use the primary cursor's data in both cases.
        BOOL isPlaceholder = NO;
        if (capeData) {
            CGFloat pw = [capeData[MCCursorDictionaryPointsWideKey] doubleValue];
            CGFloat ph = [capeData[MCCursorDictionaryPointsHighKey] doubleValue];
            // Real cursors are at least 16x16 points; smaller ones are system placeholders
            if (pw <= 8 && ph <= 8) {
                isPlaceholder = YES;
            }
        }
        if (!capeData || isPlaceholder) {
            NSString *primary = cursorAliasMap()[key];
            if (primary && cursors[primary]) {
                if (isPlaceholder) {
                    MMLog("  Replacing placeholder image for %s with %s data", key.UTF8String, primary.UTF8String);
                } else {
                    MMLog("  Using %s data as fallback for alias %s", primary.UTF8String, key.UTF8String);
                }
                capeData = cursors[primary];
            }
        }
        cursors[key] = capeData;
        i++;
    }

    // Start from 2: cursor 0 (Arrow) and 1 (IBeam) are already in defaultCursors[]
    for (int x = 2; x < 45; x++) {
        if (progress) {
            current = i + x;

            if (!progress(current, total)) {
                cleanup();
                return NO;
            }
        }
        NSString *key = [@"com.apple.cursor." stringByAppendingFormat:@"%d", x];
        CoreCursorSet(CGSMainConnectionID(), x);

        NSDictionary *cape = processedCapeWithIdentifier(key);
        if (!cape)
            continue;

        MMLog("Gathering data for %s", key.UTF8String);

        cursors[key] = cape;
    }

    if (progress) {
        progress(total, total);
    }

    NSMutableDictionary *cape = [NSMutableDictionary dictionary];
    cape[MCCursorDictionaryAuthorKey] = @"Apple, Inc.";
    cape[MCCursorDictionaryCapeNameKey] = @"Current Cursor Dump";
    cape[MCCursorDictionaryCapeVersionKey] = @1.0;
    cape[MCCursorDictionaryCloudKey] = @NO;
    cape[MCCursorDictionaryCursorsKey] = cursors;
    cape[MCCursorDictionaryHiDPIKey] = @YES;
    cape[MCCursorDictionaryIdentifierKey] = @"com.sdmj76.mousecape.dump";
    cape[MCCursorDictionaryVersionKey] = @(MCCursorCreatorVersion);
    cape[MCCursorDictionaryMinimumVersionKey] = @(MCCursorParserVersion);

    cleanup();

    return [cape writeToFile:path atomically:NO];
}

extern void exportCape(NSDictionary *cape, NSString *destination) {
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];

    NSDictionary *cursors = cape[MCCursorDictionaryCursorsKey];
    for (NSString *key in cursors) {
        NSArray *reps = cursors[key][MCCursorDictionaryRepresentationsKey];
        for (NSUInteger idx = 0; idx < reps.count; idx++) {
            NSData *data = reps[idx];
            [data writeToFile:[destination stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%lu.png", key, (unsigned long)idx]] atomically:NO];
        }
    }
}
