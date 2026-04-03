//
//  analyze_cursor_aliases.m
//
//  Analyzes which system cursors share identical image data.
//  Compares actual pixel content to find aliases (e.g. ArrowCtx uses Arrow's image).
//
//  Build:
//    clang -fobjc-arc -framework Cocoa -o /tmp/analyze_cursor_aliases \
//      Mousecape/mousecloak/analyze_cursor_aliases.m
//
//  Run:
//    /tmp/analyze_cursor_aliases
//

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CommonCrypto/CommonDigest.h>

typedef int CGSCursorID;
typedef int CGSConnectionID;

CG_EXTERN CGSConnectionID CGSMainConnectionID(void);
CG_EXTERN char *CGSCursorNameForSystemCursor(CGSCursorID cursor);
CG_EXTERN CGError CoreCursorCopyImages(CGSConnectionID cid, CGSCursorID cursorID,
    CFArrayRef *images, CGSize *imageSize, CGPoint *hotSpot,
    NSUInteger *frameCount, CGFloat *frameDuration);
CG_EXTERN CGError CGSCopyRegisteredCursorImages(CGSConnectionID cid, char *cursorName,
    CGSize *imageSize, CGPoint *hotSpot, NSUInteger *frameCount, CGFloat *frameDuration,
    CFArrayRef *imageArray);

// Get a SHA256-like fingerprint of a CGImage's pixel data
static NSString *imageFingerprint(CGImageRef cgImage) {
    if (!cgImage) return @"<nil>";

    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    // Render to a standard RGBA bitmap for consistent comparison
    size_t rowBytes = width * 4;
    size_t dataSize = rowBytes * height;
    void *buffer = malloc(dataSize);
    if (!buffer) return @"<oom>";

    memset(buffer, 0, dataSize);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buffer, width, height, 8, rowBytes, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(cs);
    if (!ctx) { free(buffer); return @"<ctx-error>"; }

    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(ctx);

    // Use a simple but fast hash: sample + total size
    // For reliability, hash the full pixel data
    NSMutableData *hashData = [NSMutableData dataWithLength:32];
    CC_SHA256(buffer, (CC_LONG)dataSize, hashData.mutableBytes);

    free(buffer);

    // Return hex string
    const unsigned char *bytes = hashData.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < 32; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

// Cursor info struct
typedef struct {
    int cursorID;
    NSString *name;
    CGSize imageSize;
    CGPoint hotSpot;
    NSUInteger frameCount;
    CGFloat frameDuration;
    NSString *fingerprint;  // hash of first frame pixel data
} CursorInfo;

static NSString *makeKey(int cursorID) {
    char *cname = CGSCursorNameForSystemCursor((CGSCursorID)cursorID);
    if (cname) {
        NSString *name = [NSString stringWithUTF8String:cname];
        if (name.length > 0) return name;
    }
    return [NSString stringWithFormat:@"com.apple.cursor.%d", cursorID];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        printf("=== Cursor Image Alias Analysis ===\n\n");

        CGSConnectionID cid = CGSMainConnectionID();

        // Collect all cursor info
        NSMutableArray *allCursors = [NSMutableArray array];
        NSMutableOrderedSet *seenFingerprints = [NSMutableOrderedSet orderedSet];
        NSMutableDictionary *fingerprintToCursors = [NSMutableDictionary dictionary];

        for (int cursorID = 0; cursorID < 256; cursorID++) {
            CFArrayRef images = NULL;
            CGSize imageSize = CGSizeZero;
            CGPoint hotSpot = CGPointZero;
            NSUInteger frameCount = 0;
            CGFloat frameDuration = 0;

            CGError err = CoreCursorCopyImages(cid, (CGSCursorID)cursorID,
                &images, &imageSize, &hotSpot, &frameCount, &frameDuration);

            if (err != kCGErrorSuccess || !images) continue;

            // Fingerprint the first frame
            NSString *fp = @"<no-frames>";
            if (CFArrayGetCount(images) > 0) {
                CGImageRef firstFrame = (CGImageRef)CFArrayGetValueAtIndex(images, 0);
                fp = imageFingerprint(firstFrame);
            }

            NSString *name = makeKey(cursorID);

            CursorInfo info;
            info.cursorID = cursorID;
            info.name = name;
            info.imageSize = imageSize;
            info.hotSpot = hotSpot;
            info.frameCount = frameCount;
            info.frameDuration = frameDuration;
            info.fingerprint = fp;

            [allCursors addObject:@{
                @"id": @(cursorID),
                @"name": name,
                @"size": NSStringFromSize(imageSize),
                @"hotspot": NSStringFromPoint(hotSpot),
                @"frames": @(frameCount),
                @"duration": @(frameDuration),
                @"fp": fp,
            }];

            if (![fingerprintToCursors objectForKey:fp]) {
                fingerprintToCursors[fp] = [NSMutableArray array];
            }
            [fingerprintToCursors[fp] addObject:@{
                @"id": @(cursorID),
                @"name": name,
            }];

            CFRelease(images);
        }

        // Phase 2: Also probe named cursors (ArrowCtx, ArrowS, IBeamS, etc.)
        // that are registered by name rather than by numeric ID
        NSArray *namedCursors = @[
            @"com.apple.coregraphics.Arrow",
            @"com.apple.coregraphics.ArrowCtx",
            @"com.apple.coregraphics.ArrowS",
            @"com.apple.coregraphics.IBeam",
            @"com.apple.coregraphics.IBeamXOR",
            @"com.apple.coregraphics.IBeamS",
            @"com.apple.coregraphics.Alias",
            @"com.apple.coregraphics.Copy",
            @"com.apple.coregraphics.Move",
            @"com.apple.coregraphics.Wait",
            @"com.apple.coregraphics.Empty",
        ];

        printf("--- Phase 2: Probing named cursors by string identifier ---\n");
        for (NSString *cursorName in namedCursors) {
            // Skip if already found via numeric ID
            BOOL alreadyFound = NO;
            for (NSDictionary *c in allCursors) {
                if ([c[@"name"] isEqualToString:cursorName]) {
                    alreadyFound = YES;
                    break;
                }
            }
            if (alreadyFound) {
                printf("  %-50s (already in numeric results)\n", cursorName.UTF8String);
                continue;
            }

            CFArrayRef images = NULL;
            CGSize imageSize = CGSizeZero;
            CGPoint hotSpot = CGPointZero;
            NSUInteger frameCount = 0;
            CGFloat frameDuration = 0;

            CGError err = CGSCopyRegisteredCursorImages(cid, (char *)cursorName.UTF8String,
                &imageSize, &hotSpot, &frameCount, &frameDuration, &images);

            if (err != kCGErrorSuccess || !images) {
                printf("  %-50s CGError=%d (no image data)\n", cursorName.UTF8String, err);
                continue;
            }

            NSString *fp = @"<no-frames>";
            if (CFArrayGetCount(images) > 0) {
                CGImageRef firstFrame = (CGImageRef)CFArrayGetValueAtIndex(images, 0);
                fp = imageFingerprint(firstFrame);
            }

            printf("  %-50s size=%s hotspot=%s frames=%lu dur=%.3f\n",
                   cursorName.UTF8String,
                   NSStringFromSize(imageSize).UTF8String,
                   NSStringFromPoint(hotSpot).UTF8String,
                   (unsigned long)frameCount, frameDuration);

            // Check if fingerprint matches any existing cursor
            NSArray *existingAliases = fingerprintToCursors[fp];
            if (existingAliases) {
                printf("    ^ SHARES IMAGE WITH: ");
                for (NSDictionary *ea in existingAliases) {
                    printf("ID %d (%s)  ", [ea[@"id"] intValue], [ea[@"name"] UTF8String]);
                }
                printf("\n");
            } else {
                printf("    ^ UNIQUE IMAGE (not shared with any numeric ID cursor)\n");
            }

            // Add to the global fingerprint map
            int syntheticID = 1000 + (int)[namedCursors indexOfObject:cursorName];
            if (!fingerprintToCursors[fp]) {
                fingerprintToCursors[fp] = [NSMutableArray array];
            }
            [fingerprintToCursors[fp] addObject:@{
                @"id": @(syntheticID),
                @"name": cursorName,
            }];

            [allCursors addObject:@{
                @"id": @(syntheticID),
                @"name": cursorName,
                @"size": NSStringFromSize(imageSize),
                @"hotspot": NSStringFromPoint(hotSpot),
                @"frames": @(frameCount),
                @"duration": @(frameDuration),
                @"fp": fp,
            }];

            CFRelease(images);
        }

        // Print full list
        printf("--- All cursors with image data ---\n");
        printf("%-5s %-50s %-12s %-15s %-7s %-8s\n",
               "ID", "Name", "Size", "Hotspot", "Frames", "Duration");
        printf("%-5s %-50s %-12s %-15s %-7s %-8s\n",
               "-----", "--------------------------------------------------",
               "------------", "---------------", "-------", "--------");

        for (NSDictionary *info in allCursors) {
            printf("%-5d %-50s %-12s %-15s %-7lu %-.3f\n",
                [info[@"id"] intValue],
                [info[@"name"] UTF8String],
                [info[@"size"] UTF8String],
                [info[@"hotspot"] UTF8String],
                (unsigned long)[info[@"frames"] unsignedIntegerValue],
                [info[@"duration"] floatValue]);
        }

        // Find alias groups (cursors sharing the same fingerprint)
        printf("\n--- Alias groups (cursors sharing identical image data) ---\n\n");

        NSMutableArray *aliasGroups = [NSMutableArray array];
        NSMutableArray *uniqueCursors = [NSMutableArray array];

        for (NSString *fp in fingerprintToCursors) {
            NSArray *cursors = fingerprintToCursors[fp];
            if (cursors.count > 1) {
                [aliasGroups addObject:@{@"fp": fp, @"cursors": cursors}];
            } else {
                [uniqueCursors addObject:cursors[0]];
            }
        }

        // Sort alias groups by size (largest first)
        [aliasGroups sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSUInteger countA = ((NSArray *)a[@"cursors"]).count;
            NSUInteger countB = ((NSArray *)b[@"cursors"]).count;
            return countB > countA ? NSOrderedDescending : (countB < countA ? NSOrderedAscending : NSOrderedSame);
        }];

        if (aliasGroups.count == 0) {
            printf("  No alias groups found — all cursors have unique images.\n");
        } else {
            for (NSUInteger gi = 0; gi < aliasGroups.count; gi++) {
                NSDictionary *group = aliasGroups[gi];
                NSArray *cursors = group[@"cursors"];
                printf("Group %lu (%lu cursors share the same image):\n",
                       (unsigned long)(gi + 1), (unsigned long)cursors.count);
                for (NSDictionary *c in cursors) {
                    printf("  ID %3d  %s\n", [c[@"id"] intValue], [c[@"name"] UTF8String]);
                }
                printf("\n");
            }
        }

        printf("--- Unique cursors (no aliases) ---\n");
        for (NSDictionary *c in uniqueCursors) {
            printf("  ID %3d  %s\n", [c[@"id"] intValue], [c[@"name"] UTF8String]);
        }

        // Summary
        printf("\n--- Summary ---\n");
        printf("  Total cursors with image data: %lu\n", (unsigned long)allCursors.count);
        printf("  Unique images: %lu\n", (unsigned long)fingerprintToCursors.count);
        printf("  Alias groups (shared images): %lu\n", (unsigned long)aliasGroups.count);
        printf("  Standalone cursors: %lu\n", (unsigned long)uniqueCursors.count);

        printf("\n=== Done ===\n");
        return 0;
    }
}
