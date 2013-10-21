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

#pragma mark AMLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    CGRect screenFrame = [self adjustedFrameForLayout:screen];

    for (SIWindow *window in windows) {
        window.frame = screenFrame;
    }
}

@end
