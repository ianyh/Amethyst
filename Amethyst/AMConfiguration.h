//
//  AMConfiguration.h
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AMHotKeyManager;
@class AMWindowManager;

// Object for managing the mapping of hot keys (managed by the AMHotKeyManager)
// to window management operations (exposed by AMWindowManager)
@interface AMConfiguration : NSObject

// Returns the globally shared configuration.
+ (AMConfiguration *)sharedConfiguration;

// Loads configuration.
- (void)loadConfiguration;

// Contructs the string corresponding to the keybinding entry in the
// configuration file for a specific layout.
//
// layoutString - The name of the layout for which to construct the
//                corresponding string.
//
// Returns "select-" + layoutString + "-layout".
- (NSString *)constructLayoutKeyString:(NSString *)layoutString;

// Establish a hot key to management operation mapping.
//
// hotKeyManager - The AMHotKeyManager responsible for maintaining hot key
//                 handlers.
// windowManager - The AMWindowManager that can be used for performing window
//                 management operations.
- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager;

// Returns an array of AMLayout Class objects to generate layouts from.
- (NSArray *)layouts;

- (BOOL)runningApplicationShouldFloat:(NSRunningApplication *)runningApplication;

- (BOOL)ignoreMenuBar;

- (BOOL)floatSmallWindows;

- (BOOL)mouseFollowsFocus;

- (BOOL)enablesLayoutHUD;

- (BOOL)enablesLayoutHUDOnSpaceChange;

@property (nonatomic, assign) BOOL tilingEnabled;

- (NSArray *)hotKeyNameToDefaultsKey;

@end
