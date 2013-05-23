//
//  NSScreen+FrameAdjustment.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "NSScreen+FrameAdjustment.h"

@implementation NSScreen (FrameAdjustment)

- (BOOL)hasMenuBar {
    NSArray *screens = [NSScreen screens];
    
    if (screens.count == 0) return NO;
    
    // The screen that contains the menu bar is defined to the first in the array.
    return [self isEqual:screens[0]];
}

- (CGRect)adjustedFrame {
    CGRect frame = NSRectToCGRect([self frame]);
    CGRect mainFrame = NSRectToCGRect([[NSScreen mainScreen] frame]);
    BOOL isMainScreen = [self isEqual:[NSScreen mainScreen]];

    // If the screen has the menu bar adjust the frame accordingly.
    // Don't use visibleFrame as it doesn't actually work correctly for our purposes.
    if ([self hasMenuBar]) {
        frame.origin.y += 22.0;
        frame.size.height -= 22.0;
    }

    if (!isMainScreen) {
        // Flip the frame to be relative to the mainFrame.
        frame.origin.y = -frame.origin.y + (mainFrame.size.height - frame.size.height);
    }

    return frame;
}

@end
