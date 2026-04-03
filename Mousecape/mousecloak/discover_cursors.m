//
//  discover_cursors.m
//  Mousecape
//
//  Standalone cursor discovery tool.
//  Scans all system cursor IDs (0-127) via CGSCursorNameForSystemCursor,
//  then compares the results against the hardcoded known set to find
//  any new/undiscovered cursor types.
//
//  Build:
//    clang -fobjc-arc -framework Cocoa -o discover_cursors discover_cursors.m
//
//  Run:
//    ./discover_cursors
//

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

typedef int CGSCursorID;
typedef int CGSConnectionID;

// Private API declarations
CG_EXTERN CGSConnectionID CGSMainConnectionID(void);
CG_EXTERN char *CGSCursorNameForSystemCursor(CGSCursorID cursor);
CG_EXTERN CGError CGSGetRegisteredCursorImages(CGSConnectionID cid, char *cursorName, CGSize *imageSize, CGPoint *hotSpot, NSUInteger *frameCount, CGFloat *frameDuration, CFArrayRef *imageArray);
CG_EXTERN CGError CoreCursorCopyImages(CGSConnectionID cid, CGSCursorID cursorID, CFArrayRef *images, CGSize *imageSize, CGPoint *hotSpot, NSUInteger *frameCount, CGFloat *frameDuration);
CG_EXTERN CGError CGSRegisterCursorWithImages(CGSConnectionID cid, char *cursorName, bool setGlobally, bool instantly, CGSize cursorSize, CGPoint hotspot, NSUInteger frameCount, CGFloat frameDuration, CFArrayRef imageArray, int *seed);

// The known cursor set hardcoded in MCDefs.m and AppEnums.swift
static NSSet *knownCursorIdentifiers(void) {
    static NSSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSSet setWithArray:@[
            // defaultCursors[] from MCDefs.m
            @"com.apple.coregraphics.Arrow",
            @"com.apple.coregraphics.IBeam",
            @"com.apple.coregraphics.IBeamXOR",
            @"com.apple.coregraphics.Alias",
            @"com.apple.coregraphics.Copy",
            @"com.apple.coregraphics.Move",
            @"com.apple.coregraphics.ArrowCtx",
            @"com.apple.coregraphics.Wait",
            @"com.apple.coregraphics.Empty",

            // cursorMap() — com.apple.cursor.N format
            @"com.apple.cursor.2",   // Link
            @"com.apple.cursor.3",   // Forbidden
            @"com.apple.cursor.4",   // Busy
            @"com.apple.cursor.5",   // Copy Drag
            @"com.apple.cursor.7",   // Crosshair
            @"com.apple.cursor.8",   // Crosshair 2
            @"com.apple.cursor.9",   // Camera 2
            @"com.apple.cursor.10",  // Camera
            @"com.apple.cursor.11",  // Closed
            @"com.apple.cursor.12",  // Open
            @"com.apple.cursor.13",  // Pointing
            @"com.apple.cursor.14",  // Counting Up
            @"com.apple.cursor.15",  // Counting Down
            @"com.apple.cursor.16",  // Counting Up/Down
            @"com.apple.cursor.17",  // Resize W
            @"com.apple.cursor.18",  // Resize E
            @"com.apple.cursor.19",  // Resize W-E
            @"com.apple.cursor.20",  // Cell XOR
            @"com.apple.cursor.21",  // Resize N
            @"com.apple.cursor.22",  // Resize S
            @"com.apple.cursor.23",  // Resize N-S
            @"com.apple.cursor.24",  // Ctx Menu
            @"com.apple.cursor.25",  // Poof
            @"com.apple.cursor.26",  // IBeam H.
            @"com.apple.cursor.27",  // Window E
            @"com.apple.cursor.28",  // Window E-W
            @"com.apple.cursor.29",  // Window NE
            @"com.apple.cursor.30",  // Window NE-SW
            @"com.apple.cursor.31",  // Window N
            @"com.apple.cursor.32",  // Window N-S
            @"com.apple.cursor.33",  // Window NW
            @"com.apple.cursor.34",  // Window NW-SE
            @"com.apple.cursor.35",  // Window SE
            @"com.apple.cursor.36",  // Window S
            @"com.apple.cursor.37",  // Window SW
            @"com.apple.cursor.38",  // Window W
            @"com.apple.cursor.39",  // Resize Square
            @"com.apple.cursor.40",  // Help
            @"com.apple.cursor.41",  // Cell
            @"com.apple.cursor.42",  // Zoom In
            @"com.apple.cursor.43",  // Zoom Out

            // macOS 26+ synonyms discovered at runtime
            @"com.apple.coregraphics.ArrowS",
            @"com.apple.coregraphics.IBeamS",
        ]];
    });
    return set;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        printf("=== macOS System Cursor Discovery Tool ===\n\n");

        NSSet *known = knownCursorIdentifiers();
        NSMutableOrderedSet *allDiscovered = [NSMutableOrderedSet orderedSet];
        NSMutableDictionary *cursorIDToName = [NSMutableDictionary dictionary];
        NSMutableArray *unknownCursors = [NSMutableArray array];

        // Phase 1: Scan system cursor IDs 0-255 via CGSCursorNameForSystemCursor
        printf("--- Phase 1: Scanning system cursor IDs 0-255 ---\n");
        for (int cursorID = 0; cursorID < 256; cursorID++) {
            char *cname = CGSCursorNameForSystemCursor((CGSCursorID)cursorID);
            if (cname == NULL) continue;

            NSString *name = [NSString stringWithUTF8String:cname];
            if (name.length == 0) continue;

            [allDiscovered addObject:name];
            cursorIDToName[@(cursorID)] = name;

            BOOL isKnown = [known containsObject:name];
            NSString *status = isKnown ? @"KNOWN" : @"*** NEW ***";
            printf("  ID %3d: %-50s %s\n", cursorID, cname, status.UTF8String);

            if (!isKnown) {
                [unknownCursors addObject:@{@"id": @(cursorID), @"name": name}];
            }
        }

        printf("\n  Total system cursors found: %lu\n", (unsigned long)allDiscovered.count);
        NSUInteger knownCount = 0;
        for (NSString *name in allDiscovered) {
            if ([known containsObject:name]) knownCount++;
        }
        printf("  Known cursors: %lu\n", (unsigned long)knownCount);
        printf("  New/unknown cursors: %lu\n\n", (unsigned long)unknownCursors.count);

        // Phase 2: Try to probe cursor IDs beyond what CGSCursorNameForSystemCursor returns
        // Use CoreCursorCopyImages to see if numeric IDs have image data even without names
        printf("--- Phase 2: Probing numeric cursor IDs 0-127 for image data ---\n");
        CGSConnectionID cid = CGSMainConnectionID();
        for (int cursorID = 0; cursorID < 128; cursorID++) {
            CFArrayRef images = NULL;
            CGSize imageSize = CGSizeZero;
            CGPoint hotSpot = CGPointZero;
            NSUInteger frameCount = 0;
            CGFloat frameDuration = 0;

            CGError err = CoreCursorCopyImages(cid, (CGSCursorID)cursorID, &images, &imageSize, &hotSpot, &frameCount, &frameDuration);
            if (err == kCGErrorSuccess && images != NULL) {
                NSString *name = cursorIDToName[@(cursorID)] ?: @"(no name)";
                NSString *idStr = [NSString stringWithFormat:@"com.apple.cursor.%d", cursorID];
                printf("  ID %3d: size=%.0fx%.0f hotspot=(%.0f,%.0f) frames=%lu duration=%.3f name=%s id=%s\n",
                       cursorID, imageSize.width, imageSize.height,
                       hotSpot.x, hotSpot.y,
                       (unsigned long)frameCount, frameDuration,
                       name.UTF8String, idStr.UTF8String);

                // Check if this numeric ID is in our known set
                if (![known containsObject:idStr] && ![known containsObject:name]) {
                    printf("         ^ Image data available but identifier not in known set!\n");
                }

                if (images) CFRelease(images);
            }
        }

        // Phase 3: Summary of new cursors
        printf("\n--- Phase 3: Summary ---\n");
        if (unknownCursors.count == 0) {
            printf("  No new cursor types discovered.\n");
            printf("  All system cursors are already in the known set.\n");
        } else {
            printf("  *** Found %lu NEW cursor type(s)! ***\n\n", (unsigned long)unknownCursors.count);
            for (NSDictionary *info in unknownCursors) {
                int cid = [info[@"id"] intValue];
                NSString *name = info[@"name"];
                printf("  NEW: ID=%d  Name=\"%s\"\n", cid, name.UTF8String);

                // Try to get image info
                CFArrayRef images = NULL;
                CGSize imageSize = CGSizeZero;
                CGPoint hotSpot = CGPointZero;
                NSUInteger frameCount = 0;
                CGFloat frameDuration = 0;
                CGError err = CoreCursorCopyImages(cid, (CGSCursorID)[info[@"id"] intValue], &images, &imageSize, &hotSpot, &frameCount, &frameDuration);
                if (err == kCGErrorSuccess) {
                    printf("       Size=%.0fx%.0f  Hotspot=(%.0f,%.0f)  Frames=%lu  Duration=%.3f\n",
                           imageSize.width, imageSize.height,
                           hotSpot.x, hotSpot.y,
                           (unsigned long)frameCount, frameDuration);
                    if (images) CFRelease(images);
                } else {
                    printf("       (No image data available, CGError=%d)\n", err);
                }
                printf("\n");
            }
        }

        // Phase 4: Print full list for copy-paste into code
        printf("\n--- Phase 4: Complete cursor ID→name mapping ---\n");
        printf("  (Ready to copy into cursorMap / CursorType enum)\n\n");
        NSArray *sortedIDs = [cursorIDToName keysSortedByValueUsingSelector:@selector(compare:)];
        for (NSNumber *idNum in sortedIDs) {
            NSString *name = cursorIDToName[idNum];
            printf("  %3d → %s\n", idNum.intValue, name.UTF8String);
        }

        printf("\n=== Done ===\n");
        return 0;
    }
}
