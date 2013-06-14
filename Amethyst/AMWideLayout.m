//
//  AMWideLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/13/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWideLayout.h"

#import "AMWindow.h"
#import "AMWindowManager.h"
#import "NSScreen+FrameAdjustment.h"

@interface AMWideLayout ()
// Ratio of screen height taken up by main pane.
@property (nonatomic, assign) CGFloat mainPaneRatio;
// The number of windows that should be displayed in the main pane.
@property (nonatomic, assign) NSInteger mainPaneCount;
@end

@implementation AMWideLayout

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

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;
    
    self.mainPaneCount = MIN(windows.count, self.mainPaneCount);
    
    NSInteger secondaryPaneCount = windows.count - self.mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    
    CGRect screenFrame = screen.adjustedFrame;
    
    CGFloat mainPaneWindowWidth = round(screenFrame.size.width / self.mainPaneCount);
    CGFloat secondaryPaneWindowWidth = (hasSecondaryPane ? round(screenFrame.size.width / secondaryPaneCount) : 0.0);

    CGFloat mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? self.mainPaneRatio : 1));
    CGFloat secondaryPaneWindowHeight = screenFrame.size.width - mainPaneWindowHeight;
    
    AMWindow *focusedWindow = [AMWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        AMWindow *window = windows[windowIndex];
        CGRect windowFrame;

        if (windowIndex < self.mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * windowIndex);
            windowFrame.origin.y = screenFrame.origin.y;
            windowFrame.size.width = mainPaneWindowWidth;
            windowFrame.size.height = mainPaneWindowHeight;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + (secondaryPaneWindowWidth * (windowIndex - self.mainPaneCount));
            windowFrame.origin.y = screenFrame.origin.y + mainPaneWindowHeight;
            windowFrame.size.width = secondaryPaneWindowWidth;
            windowFrame.size.height = secondaryPaneWindowHeight;
        }

        window.frame = windowFrame;
        
        if ([window isEqual:focusedWindow]) {
            windowFrame = window.frame;
            if (!CGRectContainsRect(screenFrame, windowFrame)) {
                windowFrame.origin.x = MIN(windowFrame.origin.x, CGRectGetMaxX(screenFrame) - CGRectGetWidth(windowFrame));
                windowFrame.origin.y = MIN(windowFrame.origin.y, CGRectGetMaxY(screenFrame) - CGRectGetHeight(windowFrame));

                window.position = windowFrame.origin;
            }
        }
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
