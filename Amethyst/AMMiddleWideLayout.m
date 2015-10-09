//
//  AMMiddleWideLayout.m
//  
//
//  Created by Shayne Sweeney on 7/6/15.
//
//

#import "AMMiddleWideLayout.h"

#import "AMReflowOperation.h"

@interface AMMiddleWideReflowOperation : AMReflowOperation
- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMMiddleWideLayout *)layout;
@property (nonatomic, strong) AMMiddleWideLayout *layout;
@end

@interface AMMiddleWideLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
@end

@implementation AMMiddleWideLayout

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.mainPaneRatio = 0.5;
    }
    return self;
}

#pragma mark AMLayout

+ (NSString *)layoutName {
    return @"Middle Wide";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMMiddleWideReflowOperation alloc] initWithScreen:screen windows:windows layout:self];
}

- (void)expandMainPane {
    self.mainPaneRatio = MIN(1, self.mainPaneRatio + 0.05);
}

- (void)shrinkMainPane {
    self.mainPaneRatio = MAX(0, self.mainPaneRatio - 0.05);
}

@end

@implementation AMMiddleWideReflowOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows layout:(AMMiddleWideLayout *)layout {
    self = [super initWithScreen:screen windows:windows];
    if (self) {
        self.layout = layout;
    }
    return self;
}

- (void)main {
    if (self.windows.count == 0) return;

    NSMutableArray *frameAssignments = [NSMutableArray array];
    NSInteger secondaryPaneCount = round((self.windows.count - 1) / 2.0);
    NSInteger tertiaryPaneCount = self.windows.count - 1 - secondaryPaneCount;
    
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    BOOL hasTertiaryPane = (tertiaryPaneCount > 0);
    
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    
    CGFloat mainPaneWindowHeight = screenFrame.size.height;
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);
    CGFloat tertiaryPaneWindowHeight = (hasTertiaryPane ? round(screenFrame.size.height / tertiaryPaneCount) : 0.0);
    
    CGFloat mainPaneWindowWidth;
    CGFloat secondaryPaneWindowWidth = 0;
    if (hasSecondaryPane && hasTertiaryPane) {
        mainPaneWindowWidth = round(screenFrame.size.width * self.layout.mainPaneRatio);
        secondaryPaneWindowWidth = round((screenFrame.size.width - mainPaneWindowWidth) / 2);
    } else if (hasSecondaryPane) {
        secondaryPaneWindowWidth = round(screenFrame.size.width * self.layout.mainPaneRatio);
        mainPaneWindowWidth = screenFrame.size.width - secondaryPaneWindowWidth;
    } else {
        mainPaneWindowWidth = screenFrame.size.width;
    }
    
    CGFloat tertiaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth - secondaryPaneWindowWidth;

    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (NSUInteger windowIndex = 0; windowIndex < self.windows.count; ++windowIndex) {
        SIWindow *window = self.windows[windowIndex];
        CGRect windowFrame;
        
        if (windowIndex == 0) {
            windowFrame.origin.x = screenFrame.origin.x + (hasSecondaryPane ? secondaryPaneWindowWidth : 0);
            windowFrame.origin.y = screenFrame.origin.y;
            windowFrame.size.width = mainPaneWindowWidth;
            windowFrame.size.height = mainPaneWindowHeight;
        } else if (windowIndex > secondaryPaneCount) { // tertiary
            windowFrame.origin.x = screenFrame.origin.x + secondaryPaneWindowWidth + mainPaneWindowWidth;
            windowFrame.origin.y = screenFrame.origin.y + (tertiaryPaneWindowHeight * (windowIndex - (1 + secondaryPaneCount)));
            windowFrame.size.width = tertiaryPaneWindowWidth;
            windowFrame.size.height = tertiaryPaneWindowHeight;
        } else { // secondary
            windowFrame.origin.x = screenFrame.origin.x;
            windowFrame.origin.y = CGRectGetMaxY(screenFrame) - (secondaryPaneWindowHeight * windowIndex);
            windowFrame.size.width = secondaryPaneWindowWidth;
            windowFrame.size.height = secondaryPaneWindowHeight;
        }

        AMFrameAssignment *frameAssignment = [[AMFrameAssignment alloc] initWithFrame:windowFrame window:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
        [frameAssignments addObject:frameAssignment];
    }

    [self performFrameAssignments:frameAssignments];
}

@end
