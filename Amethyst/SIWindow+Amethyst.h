//
//  SIWindow+Amethyst.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/5/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "SIWindow.h"

@interface SIWindow (Amethyst)

// Returns YES if a window manager should be managing the size and position of
// the window and NO otherwise.
//
// If this method returns NO the window should be entirely ignored by the window
// manager.
- (BOOL)shouldBeManaged;

// Returns YES if the window is currently visible on the screen and NO
// otherwise.
- (BOOL)isActive;

// If a window is floating it is not actively tiled, but is still in the focus
// loop.
@property (nonatomic, assign) BOOL floating;

@end
