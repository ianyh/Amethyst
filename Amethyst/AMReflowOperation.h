//
//  AMReflowOperation.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 11/7/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AMReflowOperation : NSOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows;

@property (nonatomic, strong, readonly) NSScreen *screen;
@property (nonatomic, strong, readonly) NSArray *windows;

// Returns the desired frame for the current layout based on the user's
// configuration.
//
// screen - The screen from which the proper frame is desired.
- (CGRect)adjustedFrameForLayout:(NSScreen *)screen;

// Assigns the desired frame to the window taking into account whether or not the window is focused.
//
// frame    - The frame to set the window to. Frame origin may not be respected if window is focused.
// window   - The window to set frame for.
// focused  - YES if the window is the currently focused window.
- (void)assignFrame:(CGRect)finalFrame toWindow:(SIWindow *)window focused:(BOOL)focused screenFrame:(CGRect)screenFrame;

@end
