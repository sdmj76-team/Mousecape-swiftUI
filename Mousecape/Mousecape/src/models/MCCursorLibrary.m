//
//  MCCursorLibrary.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCCursorLibrary.h"
#import "MCDefs.h"

NSString *const MCLibraryWillSaveNotificationName = @"MCLibraryWillSave";
NSString *const MCLibraryDidSaveNotificationName = @"MCLibraryDidSave";

@interface MCCursorLibrary ()
@property (nonatomic, readwrite, strong) NSMutableSet *cursors;
@property (nonatomic, assign) NSUInteger changeCount;
@property (nonatomic, assign) NSUInteger lastChangeCount;
@property (nonatomic, copy) NSString *oldIdentifier;

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary;
- (void)addCursorsFromDictionary:(NSDictionary *)cursorDicts ofVersion:(CGFloat)doubleVersion;

- (void)startObservingProperties;
- (void)stopObservingProperties;

- (void)startObservingCursor:(MCCursor *)cursor;
- (void)stopObservingCursor:(MCCursor *)cursor;
@end

@implementation MCCursorLibrary
@dynamic dirty;

+ (MCCursorLibrary *)cursorLibraryWithContentsOfURL:(NSURL *)URL {
    return [[MCCursorLibrary alloc] initWithContentsOfURL:URL];
}

- (instancetype)initWithContentsOfURL:(NSURL *)URL {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:URL];
    if ((self = [self initWithDictionary:dictionary]))
        self.fileURL = URL;
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [self init])) {
        if (![self _readFromDictionary:dictionary]) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithCursors:(NSSet *)cursors {
    if ((self = [self init])) {
        self.cursors = cursors.mutableCopy;
    }
    
    return self;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.name           = NSLocalizedString(@"cape.default.unnamed", "Default New Cape Name");
        self.author         = NSUserName();
        self.hiDPI          = YES;
        self.inCloud        = NO;
        self.identifier     = [NSString stringWithFormat:@"local.%@.Unnamed.%f", self.author, [NSDate timeIntervalSinceReferenceDate]];
        self.version        = @1.0;
        self.cursors        = [NSMutableSet set];
        self.changeCount    = 0;
        self.lastChangeCount = 0;
        [self startObservingProperties];
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    MCCursorLibrary *lib = [[MCCursorLibrary allocWithZone:zone] initWithCursors:self.cursors];

    lib.name             = self.name;
    lib.author           = self.author;
    lib.hiDPI            = self.hiDPI;
    lib.inCloud          = self.inCloud;
    lib.version          = self.version;
    lib.identifier       = [self.identifier stringByAppendingFormat:@".%f", [NSDate timeIntervalSinceReferenceDate]];

    return lib;
}

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || !dictionary.count) {
        NSLog(@"cannot make library from empty dicitonary");
        return NO;
    }
    for (MCCursor *cursor in self.cursors) {
        [self stopObservingCursor:cursor];
    }

    self.cursors = [NSMutableSet set];

    NSNumber *minimumVersion  = dictionary[MCCursorDictionaryMinimumVersionKey];
    NSNumber *version         = dictionary[MCCursorDictionaryVersionKey];
    NSDictionary *cursorDicts = dictionary[MCCursorDictionaryCursorsKey];
    NSNumber *cloud           = dictionary[MCCursorDictionaryCloudKey];
    NSString *author          = dictionary[MCCursorDictionaryAuthorKey];
    NSNumber *hiDPI           = dictionary[MCCursorDictionaryHiDPIKey];
    NSString *identifier      = dictionary[MCCursorDictionaryIdentifierKey];
    NSString *capeName        = dictionary[MCCursorDictionaryCapeNameKey];
    NSNumber *capeVersion     = dictionary[MCCursorDictionaryCapeVersionKey];

    self.name       = capeName;
    self.version    = capeVersion;
    self.author     = author;
    self.identifier = identifier;
    self.hiDPI      = hiDPI.boolValue;
    self.inCloud    = cloud.boolValue;

    if (!self.identifier) {
        NSLog(@"cannot make library from dictionary with no identifier");
        return NO;
    }

    CGFloat doubleVersion = version.doubleValue;

    if (minimumVersion.doubleValue > MCCursorParserVersion) {
        return NO;
    }

    [self.cursors removeAllObjects];
    [self addCursorsFromDictionary:cursorDicts ofVersion:doubleVersion];

    return YES;
}

- (void)dealloc {
    [self stopObservingProperties];
    for (MCCursor *cursor in self.cursors) {
        [self stopObservingCursor:cursor];
    }
}

const char MCCursorLibraryPropertiesContext;
- (void)startObservingProperties {
    NSArray *properties = @[@"identifier", @"name", @"author", @"hiDPI", @"version"];
    for (NSString *key in properties) {
        [self addObserver:self forKeyPath:key options:NSKeyValueObservingOptionOld context:(void*)&MCCursorLibraryPropertiesContext];
    }
}

- (void)stopObservingProperties {
    NSArray *properties = @[@"identifier", @"name", @"author", @"hiDPI", @"version"];
    for (NSString *key in properties) {
        [self removeObserver:self forKeyPath:key context:(void *)&MCCursorLibraryPropertiesContext];
    }
}

const char MCCursorPropertiesContext;
- (void)startObservingCursor:(MCCursor *)cursor {
    NSArray *properties = @[@"identifier", @"frameDuration", @"frameCount", @"size", @"hotSpot"];
    for (NSString *key in properties) {
        [cursor addObserver:self forKeyPath:key options:NSKeyValueObservingOptionOld context:(void *)&MCCursorPropertiesContext];
    }
}

- (void)stopObservingCursor:(MCCursor *)cursor {
    NSArray *properties = @[@"identifier", @"frameDuration", @"frameCount", @"size", @"hotSpot"];
    for (NSString *key in properties) {
        [cursor removeObserver:self forKeyPath:key context:(void *)&MCCursorPropertiesContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &MCCursorLibraryPropertiesContext || context == &MCCursorPropertiesContext) {
        [self updateChangeCount:NSChangeDone];

        if ([keyPath isEqualToString:@"identifier"]) {
            id oldValue = change[NSKeyValueChangeOldKey];
            if ([oldValue isKindOfClass:[NSNull class]])
                oldValue = nil;
            self.oldIdentifier = oldValue;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)addCursorsFromDictionary:(NSDictionary *)cursorDicts ofVersion:(CGFloat)doubleVersion {
    for (NSString *key in cursorDicts.allKeys) {
        NSDictionary *cursorDictionary = [cursorDicts objectForKey:key];
        MCCursor *cursor = [MCCursor cursorWithDictionary:cursorDictionary ofVersion:doubleVersion];
        if (!cursor)
            continue;
        cursor.identifier = key;
        [self addCursor: cursor];
    }
}

- (void)addCursor:(MCCursor *)cursor {
    if ([self.cursors containsObject:cursor]) {
        // Don't unnecessarily add a cursor/register observers with it because the
        // observation info will leak when it gets dereferenced since we don't do it here
        // since NSSet just silently skips items it already has
        return;
    }

    NSSet *change = [NSSet setWithObject:cursor];

    [self willChangeValueForKey:@"cursors" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];
    [self.cursors addObject:cursor];
    [self startObservingCursor:cursor];
    [self didChangeValueForKey:@"cursors" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];
}

- (void)removeCursor:(MCCursor *)cursor {
    NSSet *change = [NSSet setWithObject:cursor];

    [self willChangeValueForKey:@"cursors" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
    [self.cursors removeObject:cursor];
    [self stopObservingCursor:cursor];
    [self didChangeValueForKey:@"cursors" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *drep = [NSMutableDictionary dictionary];
    
    drep[MCCursorDictionaryMinimumVersionKey] = @(2.0);
    drep[MCCursorDictionaryVersionKey]        = @(2.0);
    drep[MCCursorDictionaryCapeNameKey]       = self.name;
    drep[MCCursorDictionaryCapeVersionKey]    = self.version;
    drep[MCCursorDictionaryCloudKey]          = @(self.inCloud);
    drep[MCCursorDictionaryAuthorKey]         = self.author;
    drep[MCCursorDictionaryHiDPIKey]          = @(self.isHiDPI);
    drep[MCCursorDictionaryIdentifierKey]     = self.identifier;
    
    NSMutableDictionary *cursors = [NSMutableDictionary dictionary];
    for (MCCursor *cursor in self.cursors) {
        cursors[cursor.identifier] = [cursor dictionaryRepresentation];
    }
    
    drep[MCCursorDictionaryCursorsKey] = cursors;

    return drep;
}

/// Validates the cape for system compatibility
/// Returns nil if valid, or an NSError describing validation failures
/// Rules: frameCount must be <= 24, hotspot must be within cursor size bounds (0 <= hotspot < size)
- (NSError *)validateCape {
    const NSUInteger maxFrameCount = MCMaxFrameCount;
    NSMutableArray *frameCountErrors = [NSMutableArray array];
    NSMutableArray *hotspotErrors = [NSMutableArray array];

    for (MCCursor *cursor in self.cursors) {
        NSString *cursorName = nameForCursorIdentifier(cursor.identifier);

        // Check frame count
        if (cursor.frameCount > maxFrameCount) {
            [frameCountErrors addObject:[NSString stringWithFormat:NSLocalizedString(@"validation.frameCount", nil),
                                        cursorName, (unsigned long)cursor.frameCount, (unsigned long)maxFrameCount]];
        }

        // Check hotspot bounds
        // Hotspot must be: 0 <= hotspot < cursor size
        BOOL hotspotInvalid = NO;
        NSMutableArray *hotspotDetails = [NSMutableArray array];

        if (cursor.hotSpot.x < 0) {
            [hotspotDetails addObject:[NSString stringWithFormat:NSLocalizedString(@"validation.hotspot.xNegative", nil), cursor.hotSpot.x]];
            hotspotInvalid = YES;
        } else if (cursor.hotSpot.x >= cursor.size.width) {
            [hotspotDetails addObject:[NSString stringWithFormat:NSLocalizedString(@"validation.hotspot.xExceedsWidth", nil),
                                        cursor.hotSpot.x, cursor.size.width]];
            hotspotInvalid = YES;
        }

        if (cursor.hotSpot.y < 0) {
            [hotspotDetails addObject:[NSString stringWithFormat:NSLocalizedString(@"validation.hotspot.yNegative", nil), cursor.hotSpot.y]];
            hotspotInvalid = YES;
        } else if (cursor.hotSpot.y >= cursor.size.height) {
            [hotspotDetails addObject:[NSString stringWithFormat:NSLocalizedString(@"validation.hotspot.yExceedsHeight", nil),
                                        cursor.hotSpot.y, cursor.size.height]];
            hotspotInvalid = YES;
        }

        if (hotspotInvalid) {
            [hotspotErrors addObject:[NSString stringWithFormat:@"%@ (%@)",
                                      cursorName, [hotspotDetails componentsJoinedByString: @", "]]];
        }
    }

    // Build error message if any validation failed
    if (frameCountErrors.count > 0 || hotspotErrors.count > 0) {
        NSMutableArray *errorDetails = [NSMutableArray array];

        if (frameCountErrors.count > 0) {
            [errorDetails addObject:NSLocalizedString(@"validation.frameCountIssues", nil)];
            [errorDetails addObjectsFromArray:frameCountErrors];
        }

        if (hotspotErrors.count > 0) {
            if (errorDetails.count > 0) {
                [errorDetails addObject:@""]; // Empty line separator
            }
            [errorDetails addObject:NSLocalizedString(@"validation.hotspotIssues", nil)];
            [errorDetails addObjectsFromArray:hotspotErrors];
        }

        NSString *errorMessage = [errorDetails componentsJoinedByString:@"\n"];

        return [NSError errorWithDomain:MCErrorDomain
                                   code:(frameCountErrors.count > 0) ? MCErrorFrameCountExceededCode : MCErrorHotspotOutOfBoundsCode
                               userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"validation.failed", nil),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"validation.failedDetail", nil),
            NSLocalizedRecoverySuggestionErrorKey: errorMessage
        }];
    }

    return nil; // Valid
}

- (BOOL)writeToFile:(NSString *)file atomically:(BOOL)atomically {
    return [self.dictionaryRepresentation writeToFile:file atomically:atomically];
}

- (NSError *)save {
    // Check for duplicate capes
    NSCountedSet *count  = [[NSCountedSet alloc] initWithArray:[self.cursors.allObjects valueForKey:@"identifier"]];
    NSMutableSet *duplicates = [NSMutableSet set];
    
    for (NSString *identifier in count) {
        if ([duplicates containsObject:identifier])
            continue;
        
        NSUInteger amount = [count countForObject:identifier];
        if (amount > 1)
            [duplicates addObject:nameForCursorIdentifier(identifier)];
    }
        
    if (duplicates.count > 0) {
        return [NSError errorWithDomain:MCErrorDomain code:MCErrorMultipleCursorIdentifiersCode userInfo:@{
                                                                                                           NSLocalizedDescriptionKey: NSLocalizedString(@"error.save.failed", @"New Cape Failure Title"),
                                                                                                           NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"error.save.duplicateNames", @"New Cape Failure Duplicate cursor name error"), duplicates] }];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:MCLibraryWillSaveNotificationName object:self];

    BOOL success = [self writeToFile:self.fileURL.path atomically:NO];
    if (success) {
        [self updateChangeCount:NSChangeCleared];
        [[NSNotificationCenter defaultCenter] postNotificationName:MCLibraryDidSaveNotificationName object:self];
        return nil;
    }
    return [NSError errorWithDomain:MCErrorDomain code:MCErrorWriteFailCode userInfo:@{
                                                                                       NSLocalizedDescriptionKey: NSLocalizedString(@"error.save.failed", @"New Cape Failure Title"),
                                                                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"error.save.writeFailed", @"New Cape Filure Filesystem Error") }];
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    if (change == NSChangeDone || change == NSChangeRedone) {
        self.changeCount = self.changeCount + 1;
    } else if (change == NSChangeUndone && self.changeCount > 0) {
        self.changeCount = self.changeCount - 1;
    } else if (change == NSChangeCleared || change == NSChangeAutosaved) {
        self.lastChangeCount = self.changeCount;
    }
}

- (void)revertToSaved {
    // Reload from file if available
    if (self.fileURL) {
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:self.fileURL];
        if (dictionary) {
            [self _readFromDictionary:dictionary];
        }
    }

    [self updateChangeCount:NSChangeCleared];
}

- (BOOL)isDirty {
    return (self.changeCount != self.lastChangeCount);
}

- (BOOL)isEqualTo:(MCCursorLibrary *)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    
    return ([object.name isEqualToString:self.name] &&
            [object.author isEqualToString:self.author] &&
            [object.identifier isEqualToString:self.identifier] &&
            [object.version isEqualToNumber:self.version] &&
            object.inCloud == self.inCloud &&
            object.isHiDPI == self.isHiDPI &&
            [object.cursors isEqualToSet:self.cursors]);
}

- (BOOL)isEqual:(id)object {
    return [self isEqualTo:object];
}

@end
