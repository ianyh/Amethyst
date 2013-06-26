//
//  AMWindow.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

// Specific accessibility wrapper for window elements.
@interface AMWindow : AMAccessibilityElement

// Returns the currently focused window.
//
// This method can return nil if there is no currently focused window.
+ (AMWindow *)focusedWindow;

// Returns YES if a window manager should be managing the size and position of
// the window and NO otherwise.
//
// If this method returns NO the window should be entirely ignored by the window
// manager.
- (BOOL)shouldBeManaged;

// Returns YES if the window is currently visible on the screen and NO
// otherwise.
- (BOOL)isActive;

// Returns YES if the window is a sheet contained by another window.
- (BOOL)isSheet;

// Returns the screen that the window's center is currently displayed on.
//
// Only valid if the window is active.
- (NSScreen *)screen;

// Moves the window to the upper-left corner of the supplied screen.
//
// screen - The screen to move the window to. Should not be nil.
//
// Does not resize the window.
- (void)moveToScreen:(NSScreen *)screen;

// Drops any cached screen so that a new screen can be computed.
- (void)dropScreenCache;

// Moves the window to the supplied space.
//
// space - The space to move the window to. Should be a number in [1, 10], 1
//         being Desktop 1 and 10 being Desktop 10.
//
// Does not resize or reposition the window.
- (void)moveToSpace:(NSUInteger)space;

// Brings the window into focus.
- (void)bringToFocus;

@end
