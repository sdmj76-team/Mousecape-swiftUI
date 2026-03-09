//
//  MCCursor.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MCCursorScale) {
    MCCursorScaleNone = 000,
    MCCursorScale100  = 100,
    MCCursorScale200  = 200,
    MCCursorScale500  = 500,
    MCCursorScale1000 = 1000
};

@interface MCCursor : NSObject <NSCopying>
@property (nonatomic, copy)     NSString          *identifier;
@property (nonatomic, readonly) NSString          *name;
@property (nonatomic, assign)   CGFloat           frameDuration;
@property (nonatomic, assign)   NSUInteger        frameCount;
@property (nonatomic, assign)   NSSize            size;
@property (nonatomic, assign)   NSPoint           hotSpot;
//@property (assign) NSUInteger        repeatCount; // v2.01

// creating a cursor from a dictionary
+ (nullable MCCursor *)cursorWithDictionary:(NSDictionary *)dict ofVersion:(CGFloat)version;
- (nullable id)initWithCursorDictionary:(NSDictionary *)dict ofVersion:(CGFloat)version;

- (void)setRepresentation:(nullable NSImageRep *)imageRep forScale:(MCCursorScale)scale;
- (void)removeRepresentationForScale:(MCCursorScale)scale;

- (nullable NSImageRep *)representationForScale:(MCCursorScale)scale;

- (NSDictionary *)dictionaryRepresentation;

// Derived Properties
- (nullable NSImage *)imageWithAllReps;
@end

@interface MCCursor (Properties)
@property (nonatomic, readonly, strong) NSDictionary *representations;
@end

NS_ASSUME_NONNULL_END