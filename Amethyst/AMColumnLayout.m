//
//  AMColumnLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/12/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMColumnLayout.h"

@implementation AMColumnLayout

#pragma mark AMLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;

    CGRect screenFrame = screen.frameWithoutDockOrMenu;
    CGFloat windowWidth = screenFrame.size.width / windows.count;

    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = screen.frameWithoutDockOrMenu.origin.x + windowIndex * windowWidth,
            .origin.y = screen.frameWithoutDockOrMenu.origin.y,
            .size.width = windowWidth,
            .size.height = screenFrame.size.height
        };

        window.frame = windowFrame;

        if ([window isEqual:focusedWindow]) {
            windowFrame = window.frame;
            if (!CGRectContainsRect(screenFrame, windowFrame)) {
                windowFrame.origin.x = MIN(windowFrame.origin.x, CGRectGetMaxX(screenFrame) - CGRectGetWidth(windowFrame));
                windowFrame.origin.y = MIN(windowFrame.origin.y, CGRectGetMaxY(screenFrame) - CGRectGetHeight(windowFrame));

                window.position = windowFrame.origin;
            }
        }
    }
}

@end
