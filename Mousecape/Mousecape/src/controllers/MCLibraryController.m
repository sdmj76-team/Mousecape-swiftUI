//
//  MCLibraryController.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCLibraryController.h"
#import "apply.h"
#import "restore.h"
#import "MCLogger.h"
#import "MCPrefs.h"

@interface MCLibraryController ()
@property (nonatomic, retain) NSMutableSet *capes;
@property (readwrite, copy) NSURL *libraryURL;
@property (readwrite, weak) MCCursorLibrary *appliedCape;
- (void)loadLibrary;
- (void)willSaveNotification:(NSNotification *)note;
@end

@implementation MCLibraryController

- (NSURL *)URLForCape:(MCCursorLibrary *)cape {
    return [NSURL fileURLWithPathComponents:@[ self.libraryURL.path, [cape.identifier stringByAppendingPathExtension:@"cape"] ]];;
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [self init])) {
#ifdef DEBUG
        // Initialize ObjC logging system (for MMLog and stderr capture)
        // This ensures CGError and other system errors are logged to file
        MCLoggerInit();
#endif

        self.libraryURL = url;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willSaveNotification:) name:MCLibraryWillSaveNotificationName object:nil];
        [self loadLibrary];
    }

    return self;
}

- (void)dealloc {
    // Remove notification observer to break retain cycle
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Clear capes set to release all MCCursorLibrary objects
    [self.capes removeAllObjects];

#ifdef DEBUG
    MMLog("MCLibraryController deallocated");
#endif
}

- (void)loadLibrary {
    self.capes = [NSMutableSet set];
    NSString *capesPath = self.libraryURL.path;
    NSArray  *contents  = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:capesPath error:NULL];
    NSString *applied   = MCDefault(MCPreferencesAppliedCursorKey);

    for (NSString *filename in contents) {
        // Ignore hidden files like .DS_Store
        if ([filename hasPrefix:@"."])
            continue;

        NSURL *fileURL = [NSURL fileURLWithPathComponents:@[ capesPath, filename ]];
        MCCursorLibrary *library = [MCCursorLibrary cursorLibraryWithContentsOfURL:fileURL];

        if ([library.identifier isEqualToString:applied]) {
            self.appliedCape = library;
        }

        [self addCape:library];
    }
}

- (NSError *)importCapeAtURL:(NSURL *)url {
    return [self importCapeAtURL:url skipValidation:NO];
}

- (NSError *)importCapeAtURL:(NSURL *)url skipValidation:(BOOL)skipValidation {
    MCCursorLibrary *lib = [MCCursorLibrary cursorLibraryWithContentsOfURL:url];
    if (!lib) {
        return [NSError errorWithDomain:MCErrorDomain
                                   code:MCErrorInvalidFormatCode
                               userInfo:@{
            NSLocalizedDescriptionKey: NSLocalizedString(@"error.import.failed", nil),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"error.import.unreadable", nil)
        }];
    }
    return [self importCape:lib skipValidation:skipValidation];
}

- (NSError *)importCape:(MCCursorLibrary *)lib {
    return [self importCape:lib skipValidation:NO];
}

- (NSError *)importCape:(MCCursorLibrary *)lib skipValidation:(BOOL)skipValidation {
    // Validate the cape before importing (unless skipped)
    if (!skipValidation) {
        NSError *validationError = [lib validateCape];
        if (validationError) {
            return validationError; // Return validation error to caller
        }
    }

    // Check for duplicate identifier and auto-rename if needed
    if ([[self.capes valueForKeyPath:@"identifier"] containsObject:lib.identifier]) {
        lib.identifier = [lib.identifier stringByAppendingFormat:@".%@", UUID()];
    }

    // Check for duplicate name and auto-rename if needed
    NSSet *existingNames = [self.capes valueForKeyPath:@"name"];
    if ([existingNames containsObject:lib.name]) {
        NSString *baseName = lib.name;
        NSInteger counter = 1;
        NSString *newName = [NSString stringWithFormat:@"%@ (%ld)", baseName, (long)counter];

        while ([existingNames containsObject:newName]) {
            counter++;
            newName = [NSString stringWithFormat:@"%@ (%ld)", baseName, (long)counter];
        }

        lib.name = newName;
    }

    lib.fileURL = [self URLForCape:lib];
    [lib writeToFile:lib.fileURL.path atomically:NO];

    [self addCape:lib];

    return nil; // Success
}

- (void)addCape:(MCCursorLibrary *)cape {
    if ([self.capes containsObject:cape] || [[self.capes valueForKeyPath:@"identifier"] containsObject:cape.identifier]) {
        NSLog(@"Not adding %@ to the library because an object with that identifier already exists", cape.identifier);
        return;
    }

    if (!cape) {
        NSLog(@"Cannot add nil cape");
        return;
    }

    NSSet *change = [NSSet setWithObject:cape];
    [self willChangeValueForKey:@"capes" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];

    cape.library = self;
    [self.capes addObject:cape];

    [self didChangeValueForKey:@"capes" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];
}


- (void)removeCape:(MCCursorLibrary *)cape {
    NSSet *change = [NSSet setWithObject:cape];

    [self willChangeValueForKey:@"capes" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
    if (cape == self.appliedCape)
        [self restoreCape];

    if (cape.library == self)
        cape.library = nil;

    [self.capes removeObject:cape];

    // Move the file to the trash
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *destinationURL = [NSURL fileURLWithPath:[[@"~/.Trash" stringByExpandingTildeInPath] stringByAppendingPathComponent:cape.fileURL.lastPathComponent] isDirectory:NO];

    [manager removeItemAtURL:destinationURL error:NULL];
    [manager moveItemAtURL:cape.fileURL toURL:destinationURL error:NULL];

    [self didChangeValueForKey:@"capes" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
}

- (void)applyCape:(MCCursorLibrary *)cape {
    if (applyCape([cape dictionaryRepresentation])) {
        self.appliedCape = cape;
    }
}

- (NSDictionary *)applyCapeWithResult:(MCCursorLibrary *)cape {
    NSDictionary *result = applyCapeWithResult([cape dictionaryRepresentation]);
    if ([result[@"success"] boolValue]) {
        self.appliedCape = cape;
    }
    return result;
}

- (void)restoreCape {
    resetAllCursors();
    self.appliedCape = nil;
}

- (void)willSaveNotification:(NSNotification *)note {
    MCCursorLibrary *cape = note.object;
    NSURL *oldURL = cape.fileURL;
    NSURL *newURL = [self URLForCape:cape];
    [cape setFileURL:newURL];

    // Only remove old file if URLs are different and old file exists
    if (oldURL && ![oldURL isEqual:newURL]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:oldURL.path]) {
            NSError *error = nil;
            [fm removeItemAtURL:oldURL error:&error];
            if (error) {
                NSLog(@"error removing cape after rename: %@", error);
            }
        }
    }
}

@end
