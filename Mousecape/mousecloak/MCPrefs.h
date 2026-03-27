//
//  MCPrefs.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_MCPreferences_h
#define Mousecape_MCPreferences_h

#import <Foundation/Foundation.h>

#define kMCDomain @"com.sdmj76.Mousecape"

NS_ASSUME_NONNULL_BEGIN

extern NSString *MCPreferencesAppliedCursorKey;
extern NSString *MCPreferencesCursorScaleKey;
extern NSString *MCPreferencesHandednessKey;
extern id _Nullable MCDefaultFor(NSString *key, NSString *user, NSString *host);
extern id _Nullable MCDefault(NSString *key);
#define MCFlag(key) [MCDefault(key) boolValue]

extern void MCSetDefaultFor(id _Nullable value, NSString *key, NSString *user, NSString *host);

NS_ASSUME_NONNULL_END

#define MCSetDefault(value, key) MCSetDefaultFor(value, key, (__bridge NSString *)kCFPreferencesCurrentUser, (__bridge NSString *)kCFPreferencesAnyHost)
#endif