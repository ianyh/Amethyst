//
//  AMWidescreenTallLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/6/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWidescreenTallLayout.h"

#import "AMReflowOperation.h"

@interface AMWidescreenReflowOperation : AMReflowOperation
- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMWidescreenTallLayout *)layout;
@property (nonatomic, strong) AMWidescreenTallLayout *layout;
@end

@interface AMWidescreenTallLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
// The number of windows that should be displayed in the main pane.
@property (nonatomic, assign) NSInteger mainPaneCount;
@end

@implementation AMWidescreenTallLayout

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
    return @"Widescreen Tall";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMWidescreenReflowOperation alloc] initWithScreen:screen windows:windows layout:self];
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

@implementation AMWidescreenReflowOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMWidescreenTallLayout *)layout {
    self = [super initWithScreen:screen windows:windows];
    if (self) {
        self.layout = layout;
    }
    return self;
}

- (void)main {
    if (self.windows.count == 0) return;

    NSMutableArray *frameAssignments = [NSMutableArray array];
    NSUInteger mainPaneCount = MIN(self.windows.count, self.layout.mainPaneCount);
    
    NSInteger secondaryPaneCount = self.windows.count - mainPaneCount;
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    
    CGFloat mainPaneWindowHeight = screenFrame.size.height;
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);
    
    CGFloat mainPaneWindowWidth = round((screenFrame.size.width * (hasSecondaryPane ? self.layout.mainPaneRatio : 1)) / mainPaneCount);
    CGFloat secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth * mainPaneCount;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < self.windows.count; ++windowIndex) {
        SIWindow *window = self.windows[windowIndex];
        CGRect windowFrame;
        
        if (windowIndex < mainPaneCount) {
            windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * windowIndex;
            windowFrame.origin.y = screenFrame.origin.y;
            windowFrame.size.width = mainPaneWindowWidth;
            windowFrame.size.height = mainPaneWindowHeight;
        } else {
            windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * mainPaneCount;
            windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * (windowIndex - mainPaneCount));
            windowFrame.size.width = secondaryPaneWindowWidth;
            windowFrame.size.height = secondaryPaneWindowHeight;
        }
        
        AMFrameAssignment *frameAssignment = [[AMFrameAssignment alloc] initWithFrame:windowFrame window:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
        [frameAssignments addObject:frameAssignment];
    }

    [self performFrameAssignments:frameAssignments];
}

@end
