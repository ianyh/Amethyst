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

+ (NSString *)layoutName {
    return @"Columns";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;

    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    CGFloat windowWidth = screenFrame.size.width / windows.count;
    
    CGFloat padding = [[AMConfiguration sharedConfiguration] windowPadding];
    CGFloat positionOffset = round(padding / 2);

    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = screen.frameWithoutDockOrMenu.origin.x + positionOffset + windowIndex * windowWidth,
            .origin.y = screen.frameWithoutDockOrMenu.origin.y + positionOffset,
            .size.width = windowWidth - padding,
            .size.height = screenFrame.size.height - padding
        };

        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
