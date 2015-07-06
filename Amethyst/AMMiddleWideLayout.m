//
//  AMMiddleWideLayout.m
//  
//
//  Created by Shayne Sweeney on 7/6/15.
//
//

#import "AMMiddleWideLayout.h"

@interface AMMiddleWideLayout ()
// Ratio of screen width taken up by main pane
@property (nonatomic, assign) CGFloat mainPaneRatio;
@end

@implementation AMMiddleWideLayout

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

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    if (windows.count == 0) return;
    
    NSInteger secondaryPaneCount = round((windows.count - 1) / 2.0);
    NSInteger tertiaryPaneCount = windows.count - 1 - secondaryPaneCount;
    
    BOOL hasSecondaryPane = (secondaryPaneCount > 0);
    BOOL hasTertiaryPane = (tertiaryPaneCount > 0);
    
    CGRect screenFrame = [self adjustedFrameForLayout:screen];
    
    CGFloat mainPaneWindowHeight = screenFrame.size.height;
    CGFloat secondaryPaneWindowHeight = (hasSecondaryPane ? round(screenFrame.size.height / secondaryPaneCount) : 0.0);
    CGFloat tertiaryPaneWindowHeight = (hasTertiaryPane ? round(screenFrame.size.height / tertiaryPaneCount) : 0.0);
    
    CGFloat mainPaneWindowWidth;
    CGFloat secondaryPaneWindowWidth = 0;
    if (hasSecondaryPane && hasTertiaryPane) {
        mainPaneWindowWidth = round(screenFrame.size.width * self.mainPaneRatio);
        secondaryPaneWindowWidth = round((screenFrame.size.width - mainPaneWindowWidth) / 2);
    } else if (hasSecondaryPane) {
        secondaryPaneWindowWidth = round(screenFrame.size.width * (self.mainPaneRatio / 2));
        mainPaneWindowWidth = screenFrame.size.width - secondaryPaneWindowWidth;
    } else {
        mainPaneWindowWidth = screenFrame.size.width;
    }
    
    CGFloat tertiaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth - secondaryPaneWindowWidth;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < windows.count; ++windowIndex) {
        SIWindow *window = windows[windowIndex];
        CGRect windowFrame;
        
        if (windowIndex == 0) {
            windowFrame.origin.x = screenFrame.origin.x + hasSecondaryPane ? secondaryPaneWindowWidth : 0;
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
            windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * (windowIndex - 1));
            windowFrame.size.width = secondaryPaneWindowWidth;
            windowFrame.size.height = secondaryPaneWindowHeight;
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

@end
