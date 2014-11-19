//
//  AMWideLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/13/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWideLayout.h"

#import "AMReflowOperation.h"
#import "AMWindowManager.h"

@interface AMWideReflowOperation : AMReflowOperation
- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMWideLayout *)layout;
@property (nonatomic, strong) AMWideLayout *layout;
@end

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

+ (NSString *)layoutName {
    return @"Wide";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMWideReflowOperation alloc] initWithScreen:screen windows:windows layout:self];
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

@implementation AMWideReflowOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMWideLayout *)layout {
    self = [super initWithScreen:screen windows:windows];
    if (self) {
        self.layout = layout;
    }
    return self;
}

- (void)main {
    if (self.windows.count == 0) return;
    
    NSUInteger mainPaneCount = MIN(self.windows.count, self.layout.mainPaneCount);
    
    NSInteger secondaryPaneCount = self.windows.count - mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    
    CGFloat mainPaneWindowWidth = round(screenFrame.size.width / mainPaneCount);
    CGFloat secondaryPaneWindowWidth = (hasSecondaryPane ? round(screenFrame.size.width / secondaryPaneCount) : 0.0);
    
    CGFloat mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? self.layout.mainPaneRatio : 1));
    CGFloat secondaryPaneWindowHeight = screenFrame.size.height - mainPaneWindowHeight;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < self.windows.count; ++windowIndex) {
        if (self.cancelled) {
            return;
        }
        SIWindow *window = self.windows[windowIndex];
        CGRect windowFrame;
        
        if (windowIndex < mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * windowIndex);
            windowFrame.origin.y = screenFrame.origin.y;
            windowFrame.size.width = mainPaneWindowWidth;
            windowFrame.size.height = mainPaneWindowHeight;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + (secondaryPaneWindowWidth * (windowIndex - mainPaneCount));
            windowFrame.origin.y = screenFrame.origin.y + mainPaneWindowHeight;
            windowFrame.size.width = secondaryPaneWindowWidth;
            windowFrame.size.height = secondaryPaneWindowHeight;
        }
        
        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
