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

@implementation AMFullscreenLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    CGRect screenFrame = screen.frameWithoutDockOrMenu;

    for (AMWindow *window in windows) {
        window.frame = screenFrame;
    }
}

@end
