//
//  AMFullscreenLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMFullscreenLayout.h"

#import "AMWindow.h"
#import "AMWindowManager.h"
#import "NSScreen+FrameFlipping.h"

@implementation AMFullscreenLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    CGRect screenFrame = [screen flippedFrame];

    for (AMWindow *window in windows) {
        [window setFrame:screenFrame];
    }
}

@end
