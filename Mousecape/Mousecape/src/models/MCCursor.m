//
//  MCCursor.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCCursor.h"
#import "NSBitmapImageRep+ColorSpace.h"
static MCCursorScale cursorScaleForScale(CGFloat scale) {
    if (scale < 0.0)
        return MCCursorScaleNone;
    
    return (MCCursorScale)((NSInteger)scale * 100);
}

@interface MCCursor ()
@property (readwrite, strong) NSMutableDictionary<NSString *, NSBitmapImageRep *> *representations;
- (NSInteger)framesForScale:(MCCursorScale)scale;
- (BOOL)_readFromDictionary:(NSDictionary *)dictionary ofVersion:(CGFloat)version;
@end

@implementation MCCursor
@dynamic name;

+ (MCCursor *)cursorWithDictionary:(NSDictionary *)dict ofVersion:(CGFloat)version {
    return [[self alloc] initWithCursorDictionary:dict ofVersion:version];
}

- (id)init {
    if ((self = [super init])) {
        self.frameCount      = 1;
        self.frameDuration   = 1.0;
        self.size            = NSZeroSize;
        self.hotSpot         = NSZeroPoint;
        self.identifier      = [UUID() stringByReplacingOccurrencesOfString:@"-" withString:@""];
        self.representations = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithCursorDictionary:(NSDictionary *)dict ofVersion:(CGFloat)version {
    if ((self = [self init])) {
        
        if (![self _readFromDictionary:dict ofVersion:version])
            return nil;
        
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    MCCursor *cursor = [[MCCursor allocWithZone:zone] init];
    
    cursor.frameCount      = self.frameCount;
    cursor.frameDuration   = self.frameDuration;
    cursor.size            = self.size;
    cursor.representations = self.representations.mutableCopy;
    cursor.hotSpot         = self.hotSpot;
    cursor.identifier      = self.identifier;
    
    return cursor;
}

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary ofVersion:(CGFloat)version {
    if (!dictionary || !dictionary.count)
        return NO;
    
    NSNumber *frameCount    = [dictionary objectForKey:MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = [dictionary objectForKey:MCCursorDictionaryFrameDuratiomKey];
    //    NSNumber *repeatCount   = dictionary[MCCursorDictionaryRepeatCountKey];
    NSNumber *hotSpotX      = [dictionary objectForKey:MCCursorDictionaryHotSpotXKey];
    NSNumber *hotSpotY      = [dictionary objectForKey:MCCursorDictionaryHotSpotYKey];
    NSNumber *pointsWide    = [dictionary objectForKey:MCCursorDictionaryPointsWideKey];
    NSNumber *pointsHigh    = [dictionary objectForKey:MCCursorDictionaryPointsHighKey];
    NSArray *reps           = [dictionary objectForKey:MCCursorDictionaryRepresentationsKey];
    
    // we only take version 2.0 documents.
    if (version >=  2.0) {
        if (frameCount && frameDuration && hotSpotX && hotSpotY && pointsWide && pointsHigh) {

            self.frameCount    = frameCount.unsignedIntegerValue;
            self.frameDuration = frameDuration.doubleValue;
            self.hotSpot       = NSMakePoint(hotSpotX.doubleValue, hotSpotY.doubleValue);
            //            self.repeatCount   = repeatCount.unsignedIntegerValue;
            self.size          = NSMakeSize(pointsWide.doubleValue, pointsHigh.doubleValue);

            for (NSData *data in reps) {
                // data in v2.0 documents are saved as PNGs
                NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:data];
                rep.size = NSMakeSize(self.size.width, self.size.height * self.frameCount);

                [self setRepresentation:rep.retaggedSRGBSpace forScale:cursorScaleForScale(rep.pixelsWide / pointsWide.doubleValue)];
            }

            return YES;
        }
    }

    return NO;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *drep = [NSMutableDictionary dictionary];
    drep[MCCursorDictionaryFrameCountKey]    = @(self.frameCount);
    drep[MCCursorDictionaryFrameDuratiomKey] = @(self.frameDuration);
    drep[MCCursorDictionaryHotSpotXKey]      = @(self.hotSpot.x);
    drep[MCCursorDictionaryHotSpotYKey]      = @(self.hotSpot.y);
    drep[MCCursorDictionaryPointsWideKey]    = @(self.size.width);
    drep[MCCursorDictionaryPointsHighKey]    = @(self.size.height);
    
    NSMutableArray *pngs = [NSMutableArray array];
    for (NSString *key in self.representations) {
        NSBitmapImageRep *rep = self.representations[key];
        pngs[pngs.count] = [rep.ensuredSRGBSpace TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
    }
    
    drep[MCCursorDictionaryRepresentationsKey] = pngs;
    
    return drep;
}

- (void)setRepresentation:(NSBitmapImageRep *)imageRep forScale:(MCCursorScale)scale {
    [self willChangeValueForKey:@"representations"];

    if (imageRep)
        [self.representations setObject:imageRep forKey:[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];
    else
        [self.representations removeObjectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];

    if (self.representations.count == 1) {
        // This is the first object, set the image size to this
        NSSize size = NSMakeSize((double)imageRep.pixelsWide / (scale / 100.0), (double)imageRep.pixelsHigh / self.frameCount / (scale / 100.0));
        if (!NSEqualSizes(size, NSZeroSize)) {
            self.size = size;
        }
    }

    [self didChangeValueForKey:@"representations"];
}

- (NSInteger)framesForScale:(MCCursorScale)scale {
    return [self representationForScale:scale].pixelsHigh / self.size.height;
}

- (void)removeRepresentationForScale:(MCCursorScale)scale {
    [self setRepresentation:nil forScale:scale];
}

- (NSImageRep *)representationForScale:(MCCursorScale)scale {
    return self.representations[[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];
}

- (NSImage *)imageWithAllReps {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(self.size.width, self.size.height * self.frameCount)];
    [image addRepresentations:self.representations.allValues];
    return image;
}

- (NSString *)name {
    return nameForCursorIdentifier(self.identifier);
}

- (BOOL)isEqualTo:(MCCursor *)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    
    BOOL props =  (object.frameCount == self.frameCount &&
                   object.frameDuration == self.frameDuration &&
                   NSEqualSizes(object.size, self.size) &&
                   NSEqualPoints(object.hotSpot, self.hotSpot) &&
                   [object.identifier isEqualToString:self.identifier]);

//    props = (props && [self.representations isEqualToDictionary:object.representations]);
    
    return props;
}

- (BOOL)isEqual:(id)object {
    return [self isEqualTo:object];
}

@end
