//
//  MCLibraryController.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCCursorLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCLibraryController : NSObject
@property (readonly, weak, nullable) MCCursorLibrary *appliedCape;
@property (readonly, copy) NSURL *libraryURL;

- (instancetype)initWithURL:(NSURL *)url;

- (nullable NSError *)importCapeAtURL:(NSURL *)url;
- (nullable NSError *)importCape:(MCCursorLibrary *)cape;

- (void)addCape:(MCCursorLibrary *)cape;
- (void)removeCape:(MCCursorLibrary *)cape;

- (void)applyCape:(MCCursorLibrary *)cape;
- (void)restoreCape;

- (NSURL *)URLForCape:(MCCursorLibrary *)cape;

@end

@interface MCLibraryController (Capes)
@property (nonatomic, readonly) NSSet *capes;
@end

NS_ASSUME_NONNULL_END