//
//  AMFullscreenLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMFullscreenLayout.h"

#import "AMWindowManager.h"

@interface AMFullscreenLayout ()
@property (nonatomic, assign) BOOL ignoreMenu;
@end

@implementation AMFullscreenLayout
#pragma mark Lifecycle
- (id)init {
  return [self init: false];
}

- (id)init: (BOOL) ignoreMenu {
    self = [super init];
    if (self) {
        self.ignoreMenu = ignoreMenu;
    }
    return self;
}

#pragma mark AMLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    CGRect screenFrame = self.ignoreMenu ? screen.frame : screen.frameWithoutDockOrMenu;

    for (SIWindow *window in windows) {
        window.frame = screenFrame;
    }
}

@end
