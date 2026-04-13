//
//  apply.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_apply_h
#define Mousecape_apply_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

extern BOOL applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount);
extern BOOL applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore);
extern BOOL applyCape(NSDictionary *dictionary);
extern BOOL applyCapeAtPath(NSString *path);
// Reapply mode: skip resetAllCursors() + backupAllCursors() to avoid cursor flash.
// Use when re-applying the same cape (Helper startup, session change, display reconfiguration).
extern BOOL applyCapeReapply(NSDictionary *dictionary);
extern BOOL applyCapeAtPathReapply(NSString *path);

NS_ASSUME_NONNULL_END

#endif
