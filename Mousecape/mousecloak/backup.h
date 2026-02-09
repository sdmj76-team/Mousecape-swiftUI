//
//  backup.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_backup_h
#define Mousecape_backup_h

NS_ASSUME_NONNULL_BEGIN

extern NSString *backupStringForIdentifier(NSString *identifier);
extern void backupCursorForIdentifier(NSString *ident);
extern void backupAllCursors(void);

NS_ASSUME_NONNULL_END

#endif
