//
//  AMLayout.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AMLayout;

// Abstract superclass for defining layout behavior of windows on a screen.
// 
// Layouts are conceptually organized as a main pane of content and a secondary
// pane of content. The main pane of content contains some adjustable, non-zero
// number of windows. The size of the main pane and the number of windows
// contained in it may be adjustable or may be static depending on the layout
// algorithm.
//
// For example the fullscreen layout has a main pane whose size always fills the
// screen and whose count is always 1, but the tall layout has a main pane on
// the left of the screen whose size can be adjusted and the number of windows
// contained there can be increased and decreased.
@interface AMLayout : NSObject

// Organizes the windows within a screen's frame.
//
// screen  - The screen on which windows will be laid out.
// windows - The windows to be laid out on the screen.
//
// Subclasses MUST override this method to layout windows according to their specific algorithm.
// Subclasses MUST NOT call super's implementation.
- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows;

// Shrink the size of the main pane of content.
// Subclasses can optionally implement this method.
- (void)shrinkMainPane;

// Increase the size of the main pane of content.
// Subclasses can optionally implement this method.
- (void)expandMainPane;

// Increase the number of windows in the main pane of content.
// Subclasses can optionally implement this method.
- (void)increaseMainPaneCount;

// Decrease the number of windows in the main pane of content.
// Subclasses can optionally implement this method.
- (void)decreaseMainPaneCount;

- (CGRect)adjustedFrameForLayout:(NSScreen *)screen;

@end
