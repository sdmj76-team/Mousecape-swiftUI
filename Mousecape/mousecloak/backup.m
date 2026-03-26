//
//  backup.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"
#import "MCDefs.h"

NSString *backupStringForIdentifier(NSString *identifier) {
    return [NSString stringWithFormat:@"com.alexzielenski.mousecape.%@", identifier];
}

void backupCursorForIdentifier(NSString *ident) {
    MMLog("  Backing up: %s", ident.UTF8String);
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);

//     dont try to backup a nonexistant cursor
    if (!registered) {
        MMLog("    Skipped - cursor not registered");
        return;
    }

    NSString *backupIdent = backupStringForIdentifier(ident);
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupIdent.UTF8String, &registered);

//     don't re-back it up
    if (registered) {
        MMLog("    Skipped - backup already exists");
        return;
    }

    NSDictionary *cape = capeWithIdentifier(ident);
    BOOL success = applyCapeForIdentifier(cape, backupIdent, YES, NO);
    MMLog("    Backup result: %s", success ? "SUCCESS" : "FAILED");
}

void backupAllCursors(void) {
    MMLog("=== backupAllCursors ===");
    bool arrowRegistered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupStringForIdentifier(@"com.apple.coregraphics.Arrow").UTF8String, &arrowRegistered);

    if (arrowRegistered) {
        MMLog("Skipping backup, backup already exists");
//         we are already backed up
        return;
    }
    // Backup all cursors (default + synonyms)
    MMLog("--- Backing up all cursors ---");
    MCEnumerateAllCursorIdentifiers(^(NSString *name) {
        backupCursorForIdentifier(name);
    });
    // no need to backup core cursors
    MMLog("=== backupAllCursors complete ===");
}
