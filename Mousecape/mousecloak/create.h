//
//  create.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_create_h
#define Mousecape_create_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSError * _Nullable createCape(NSString *input, NSString *output, BOOL convert);

extern NSDictionary * _Nullable processedCapeWithIdentifier(NSString *identifier);
extern BOOL dumpCursorsToFile(NSString *path, BOOL (^progress)(NSUInteger current, NSUInteger total));

extern NSDictionary * _Nullable createCapeFromDirectory(NSString *path);
extern NSDictionary * _Nullable createCapeFromMightyMouse(NSDictionary *mightyMouse, NSDictionary * _Nullable metadata);

extern void exportCape(NSDictionary *cape, NSString *destination);

NS_ASSUME_NONNULL_END

#endif
