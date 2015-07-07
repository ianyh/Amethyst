//
//  AMFullscreenLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMFullscreenLayout.h"

#import "AMReflowOperation.h"
#import "AMWindowManager.h"

@interface AMFullscreenReflowOperation: AMReflowOperation
@end

@implementation AMFullscreenReflowOperation

- (void)main {
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    NSMutableArray *frameAssignments = [NSMutableArray array];
    for (SIWindow *window in self.windows) {
        if (self.cancelled) {
            return;
        }

        [frameAssignments addObject:[[AMFrameAssignment alloc] initWithFrame:screenFrame window:window focused:NO screenFrame:screenFrame]];
    }

    [self performFrameAssignments:frameAssignments];
}

@end

@implementation AMFullscreenLayout

+ (NSString *)layoutName {
    return @"Fullscreen";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMFullscreenReflowOperation alloc] initWithScreen:screen windows:windows];
}

@end
