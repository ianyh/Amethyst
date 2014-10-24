//
//  AMTallLayout.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMTallLayout.h"

#import "AMWindowManager.h"

@interface AMTallLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
// The number of windows that should be displayed in the main pane.
@property (nonatomic, assign) NSInteger mainPaneCount;
@end

@implementation AMTallLayout

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.mainPaneCount = 1;
        self.mainPaneRatio = 0.5;
    }
    return self;
}

#pragma mark AMLayout

+ (NSString *)layoutName {
    return @"Tall";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;

    NSUInteger mainPaneCount = MIN(windows.count, self.mainPaneCount);

    NSInteger secondaryPaneCount = windows.count - mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);

    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    CGFloat padding = [[AMConfiguration sharedConfiguration] windowPadding];
    CGFloat positionOffset = round(padding / 2);

    CGFloat mainPaneWindowHeight = round(screenFrame.size.height / mainPaneCount);
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);

    CGFloat mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? self.mainPaneRatio : 1));
    CGFloat secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth;

    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame;

        if (windowIndex < mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x + positionOffset;
            windowFrame.origin.y = screenFrame.origin.y + positionOffset + (mainPaneWindowHeight * windowIndex);
            windowFrame.size.width = mainPaneWindowWidth - padding;
            windowFrame.size.height = mainPaneWindowHeight - padding;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + positionOffset + mainPaneWindowWidth;
            windowFrame.origin.y = screenFrame.origin.y + positionOffset + (secondaryPaneWindowHeight * (windowIndex - mainPaneCount));
            windowFrame.size.width = secondaryPaneWindowWidth - padding;
            windowFrame.size.height = secondaryPaneWindowHeight - padding;
        }

        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

- (void)expandMainPane {
    self.mainPaneRatio = MIN(1, self.mainPaneRatio + 0.05);
}

- (void)shrinkMainPane {
    self.mainPaneRatio = MAX(0, self.mainPaneRatio - 0.05);
}

- (void)increaseMainPaneCount {
    self.mainPaneCount = self.mainPaneCount + 1;
}

- (void)decreaseMainPaneCount {
    self.mainPaneCount = MAX(1, self.mainPaneCount - 1);
}

@end
