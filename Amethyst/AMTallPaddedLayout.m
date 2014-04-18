//
//  AMTallPaddedLayout.m
//  Amethyst
//
//  Created by Leonard Truong on 4/17/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMTallPaddedLayout.h"
#import "AMConfiguration.h"

@interface AMTallPaddedLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
// The number of windows that should be displayed in the main pane.
@property (nonatomic, assign) NSInteger mainPaneCount;
@property (nonatomic, assign) NSInteger windowPadding;
@end

@implementation AMTallPaddedLayout

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.mainPaneCount = 1;
        self.mainPaneRatio = 0.5;
        self.windowPadding = [[AMConfiguration sharedConfiguration] windowPadding];
    }
    return self;
}

#pragma mark AMLayout

+ (NSString *)layoutName {
    return @"TallPadded";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;
    
    NSUInteger mainPaneCount = MIN(windows.count, self.mainPaneCount);
    
    NSInteger secondaryPaneCount = windows.count - mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    
    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    screenFrame.origin.x += self.windowPadding;
    screenFrame.origin.y += self.windowPadding;
    screenFrame.size.width -= self.windowPadding * 2;
    screenFrame.size.height -= self.windowPadding * 2;
    
    CGFloat mainPaneWindowHeight = round(screenFrame.size.height / mainPaneCount);
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round((screenFrame.size.height + self.windowPadding) / secondaryPaneCount) : 0.0);
    
    CGFloat mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? self.mainPaneRatio : 1)) ;
    CGFloat secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame;
        
        if (windowIndex < mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x;
            windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * windowIndex);
            windowFrame.size.width = mainPaneWindowWidth - (self.windowPadding / 2);
            windowFrame.size.height = mainPaneWindowHeight;
            if (mainPaneCount > 1) windowFrame.size.height -= self.windowPadding;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth + (self.windowPadding / 2);
            windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * (windowIndex - mainPaneCount));
            windowFrame.size.width = secondaryPaneWindowWidth - (self.windowPadding / 2);
            windowFrame.size.height = secondaryPaneWindowHeight - self.windowPadding;
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
