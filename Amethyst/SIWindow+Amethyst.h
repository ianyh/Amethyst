//
//  SIWindow+Amethyst.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/5/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Silica/SIWindow.h>

@interface SIWindow (Amethyst)

// Returns YES if a window manager should be managing the size and position of
// the window and NO otherwise.
//
// If this method returns NO the window should be entirely ignored by the window
// manager.
- (BOOL)shouldBeManaged;

// If a window is floating it is not actively tiled, but is still in the focus
// loop.
@property (nonatomic, assign) BOOL floating;

// Custom focusWindow function that allows Amethyst to implement mouse follows
// focus.  Calls the original focusWindow function implemented in SIWindow.
// Then checks the user or default configuration as to whether or not to move
// the mouse cursor with changes in focus.
- (BOOL)am_focusWindow;

@end
