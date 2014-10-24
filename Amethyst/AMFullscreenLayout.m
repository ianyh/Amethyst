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
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    for (SIWindow *window in windows) {
        [self assignFrame:screenFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
