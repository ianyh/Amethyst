//
//  AMTallLayout.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMTallLayout.h"

#import "AMWindow.h"
#import "AMWindowManager.h"
#import "NSScreen+FrameFlipping.h"

@implementation AMTallLayout

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.mainPaneCount = 1;
    }
    return self;
}

#pragma mark Public Methods

- (void)setMainPaneCount:(NSInteger)mainPaneCount {
    if (_mainPaneCount == mainPaneCount) return;

    _mainPaneCount = MAX(1, mainPaneCount);
}

#pragma mark AMLayout

- (void)reflowScreen:(NSScreen *)screen withWindowManager:(AMWindowManager *)windowManager {
    NSArray *windows = [windowManager activeWindowsForScreen:screen];
    NSInteger secondaryPaneCount = [windows count] - self.mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);

    CGRect screenFrame = [screen flippedFrame];

    CGFloat mainPaneWindowHeight = round(screenFrame.size.height / self.mainPaneCount);
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        AMWindow *window = windows[windowIndex];
        CGRect windowFrame;

        if (windowIndex < self.mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x;
            windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * windowIndex);
            windowFrame.size.width = (hasSecondaryPane ? round(screenFrame.size.width / 2) : screenFrame.size.width);
            windowFrame.size.height = mainPaneWindowHeight;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + round(screenFrame.size.width / 2);
            windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * (windowIndex - self.mainPaneCount));
            windowFrame.size.width = round(screenFrame.size.width / 2);
            windowFrame.size.height = secondaryPaneWindowHeight;
        }

        [window setFrame:windowFrame];
        [window setFrame:windowFrame];
    }
}

@end
