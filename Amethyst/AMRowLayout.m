//
//  AMRowLayout.m
//  Amethyst
//
//  Created by Benjamin Loulier on 2/28/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMRowLayout.h"

#import "AMReflowOperation.h"

@interface AMRowReflowOperation : AMReflowOperation
@end

@implementation AMRowLayout

+ (NSString *)layoutName {
    return @"Rows";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMRowReflowOperation alloc] initWithScreen:screen windows:windows];
}

@end

@implementation AMRowReflowOperation

- (void)main {
    if (self.windows.count == 0) return;
    
    CGRect screenFrame = [self adjustedFrameForLayout:self.screen];
    CGFloat windowHeight = screenFrame.size.height / self.windows.count;
    
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    
    for (NSUInteger windowIndex = 0; windowIndex < self.windows.count; ++windowIndex) {
        if (self.cancelled) {
            return;
        }
        SIWindow *window = self.windows[windowIndex];
        CGRect windowFrame = {
            .origin.x = self.screen.frameWithoutDockOrMenu.origin.x,
            .origin.y = self.screen.frameWithoutDockOrMenu.origin.y + windowIndex * windowHeight,
            .size.width = screenFrame.size.width,
            .size.height = windowHeight
        };

        [self assignFrame:windowFrame toWindow:window focused:[window isEqualTo:focusedWindow] screenFrame:screenFrame];
    }
}

@end
