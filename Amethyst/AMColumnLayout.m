//
//  AMColumnLayout.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/12/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMColumnLayout.h"

#import "AMReflowOperation.h"

@interface AMColumnReflowOperation : AMReflowOperation
@end

@implementation AMColumnLayout

#pragma mark AMLayout

+ (NSString *)layoutName {
    return @"Columns";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMColumnReflowOperation alloc] initWithScreen:screen windows:windows];
}

@end

@implementation AMColumnReflowOperation

- (void)main {
    if (self.windows.count == 0) return;

    NSMutableArray *frameAssignments = [NSMutableArray array];
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    CGFloat windowWidth = screenFrame.size.width / self.windows.count;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < self.windows.count; ++windowIndex) {
        if (self.cancelled) {
            return;
        }
        SIWindow *window = self.windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = self.screen.frameWithoutDockOrMenu.origin.x + windowIndex * windowWidth,
            .origin.y = self.screen.frameWithoutDockOrMenu.origin.y,
            .size.width = windowWidth,
            .size.height = screenFrame.size.height
        };

        AMFrameAssignment *frameAssignment = [[AMFrameAssignment alloc] initWithFrame:windowFrame window:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
        [frameAssignments addObject:frameAssignment];
    }

    [self performFrameAssignments:frameAssignments];
}

@end
