//
//  AMWindowManager.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AMScreenManager;

// Object for managing the windows across all screens and spaces.
@interface AMWindowManager : NSObject

// Returns the screen manager responsible for the screen containing the
// currently focused window.
- (AMScreenManager *)focusedScreenManager;

// Move the current focused window to the screen at screenIndex.
//
// screenIndex - The index of a screen. Should be in [1, 3], 1 being the
//               left-most screen.
//
// Screens are ordered from left to right along the x-axis. This method is a
// no-op if there is no screen at the supplied index, e.g., screenIndex 3 when
// there are only 2 screens.
- (void)throwToScreenAtIndex:(NSUInteger)screenIndex;

// Move the window focus to the screen at screenIndex.
//
// screenIndex - The index of a screen. Should be in [1, 3], 1 being the
//               left-most screen.
//
// Focuses the main window on the screen at screenIndex.
//
// Screens are ordered from left to right along the x-axis. This method is a
// no-op if there is no screen at the supplied index, e.g., screenIndex 3 when
// there are only 2 screens, or if there are no windows on the screen.
- (void)focusScreenAtIndex:(NSUInteger)screenIndex;

// Move the window focus counter clockwise from the currently focused window.
//
// If there is currently no focused window the main window of the main screen is
// focused.
- (void)moveFocusCounterClockwise;

// Move the window focus clockwise from the currently focused window.
//
// If there is currently no focused window the main window of the main screen is
// focused.
- (void)moveFocusClockwise;

// Swaps the focused window with main window on the focused window's screen.
//
// This method is a no-op if there is no focused window.
- (void)swapFocusedWindowToMain;

// Swaps the focused window with its adjacent window going counter clockwise on
// the focused window's screen.
//
// This method is a no-op if there is no focused window.
- (void)swapFocusedWindowCounterClockwise;

// Swaps the focused window with its adjacent window going clockwise on the
// focused window's screen.
//
// This method is a no-op if there is no focused window.
- (void)swapFocusedWindowClockwise;

// Moves the focused window to the supplied space.
//
// space - The space to move the window to. Should be a number in [1, 10], 1
//         being Desktop 1 and 10 being Desktop 10.
//
// This method is a no-op if there is no focused window.
- (void)pushFocusedWindowToSpace:(NSUInteger)space;

- (void)toggleFloatForFocusedWindow;

- (void)displayCurrentLayout;

@end
