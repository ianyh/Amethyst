//
//  AMFullscreenLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMFullscreenLayout.h"

#import "AMWindowManager.h"

@implementation AMFullscreenLayout

+ (NSString *)layoutName {
    return @"Fullscreen";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    
    CGFloat padding = [[AMConfiguration sharedConfiguration] windowPadding];
    CGFloat positionOffset = round(padding / 2);
    
    CGRect windowFrame;
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (SIWindow *window in windows) {
        windowFrame.origin.x = screenFrame.origin.x + positionOffset;
        windowFrame.origin.y = screenFrame.origin.y + positionOffset;
        windowFrame.size.width = screenFrame.size.width - padding;
        windowFrame.size.height = screenFrame.size.height - padding;
        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
