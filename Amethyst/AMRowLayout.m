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
    
    CGFloat padding = [[AMConfiguration sharedConfiguration] windowPadding];
    CGFloat positionOffset = round(padding / 2);
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = screen.frameWithoutDockOrMenu.origin.x + positionOffset,
            .origin.y = screen.frameWithoutDockOrMenu.origin.y + positionOffset + windowIndex * windowHeight,
            .size.width = screenFrame.size.width - padding,
            .size.height = windowHeight - padding
        };

        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
