//
//  MCCursorLibrary.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCCursor.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MCLibraryWillSaveNotificationName;
extern NSString *const MCLibraryDidSaveNotificationName;

@class MCLibraryController;
@interface MCCursorLibrary : NSObject <NSCopying>
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *author;
@property (nonatomic, copy)   NSString *identifier;
@property (nonatomic, copy)   NSNumber *version;
@property (nonatomic, copy, nullable)   NSURL    *fileURL;
@property (nonatomic, weak, nullable)   MCLibraryController *library;
@property (nonatomic, readonly, getter=isDirty) BOOL dirty;
@property (nonatomic, assign, getter = isInCloud) BOOL inCloud;
@property (nonatomic, assign, getter = isHiDPI)   BOOL hiDPI;

+ (nullable MCCursorLibrary *)cursorLibraryWithContentsOfURL:(NSURL *)URL;

- (nullable instancetype)initWithContentsOfURL:(NSURL *)URL;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithCursors:(NSSet *)cursors;

- (void)addCursor:(MCCursor *)cursor;
- (void)removeCursor:(MCCursor *)cursor;

- (NSDictionary *)dictionaryRepresentation;
- (BOOL)writeToFile:(NSString *)file atomically:(BOOL)atomically;
- (nullable NSError *)save;

/// Validates the cape for system compatibility
/// Returns nil if valid, or an NSError describing validation failures
/// Rules: frameCount must be <= 24, hotspot must be within cursor size bounds (0 <= hotspot < size)
- (nullable NSError *)validateCape;

- (void)updateChangeCount:(NSDocumentChangeType)change;
- (void)revertToSaved;

@end

@interface MCCursorLibrary (Properties)
@property (nonatomic, readonly, strong) NSSet *cursors;
@end

NS_ASSUME_NONNULL_END