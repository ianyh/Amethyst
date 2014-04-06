//
//  AMRowLayout.m
//  Amethyst
//
//  Created by Benjamin Loulier on 2/28/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMRowLayout.h"

@implementation AMRowLayout

+ (NSString *)layoutName {
    return @"Rows";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;
    
    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    CGFloat windowHeight = screenFrame.size.height / windows.count;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = screen.frameWithoutDockOrMenu.origin.x,
            .origin.y = screen.frameWithoutDockOrMenu.origin.y + windowIndex * windowHeight,
            .size.width = screenFrame.size.width,
            .size.height = windowHeight
        };
        
        window.size = windowFrame.size;
        
        if ([window isEqual:focusedWindow]) {
            windowFrame.size = window.frame.size;
            if (!CGRectContainsRect(screenFrame, windowFrame)) {
                windowFrame.origin.x = MIN(windowFrame.origin.x, CGRectGetMaxX(screenFrame) - CGRectGetWidth(windowFrame));
                windowFrame.origin.y = MIN(windowFrame.origin.y, CGRectGetMaxY(screenFrame) - CGRectGetHeight(windowFrame));
                
                window.position = windowFrame.origin;
            }
        }

        window.position = windowFrame.origin;
    }
}

@end
