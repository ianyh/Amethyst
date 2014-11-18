//
//  AMReflowOperation.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 11/7/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMReflowOperation.h"

#import "AMConfiguration.h"

@interface AMReflowOperation ()
@property (nonatomic, strong) NSScreen *screen;
@property (nonatomic, strong) NSArray *windows;
@end

@implementation AMReflowOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows {
    self = [super init];
    if (self) {
        self.screen = screen;
        self.windows = windows;
    }
    return self;
}

- (CGRect)adjustedFrameForLayout:(NSScreen *)screen {
    return [[AMConfiguration sharedConfiguration] ignoreMenuBar] ? screen.frameIncludingDockAndMenu : screen.frameWithoutDockOrMenu;
}

- (void)assignFrame:(CGRect)finalFrame toWindow:(SIWindow *)window focused:(BOOL)focused screenFrame:(CGRect)screenFrame {
    if (self.cancelled) {
        return;
    }

    if (CGSManagedDisplayIsAnimating(CGSDefaultConnection, (__bridge CFStringRef)self.screen.am_screenIdentifier)) {
        return;
    }

    CGPoint finalPosition = finalFrame.origin;
    
    // Just resize the window
    finalFrame.origin = window.frame.origin;
    window.frame = finalFrame;
    
    if (focused) {
        finalFrame.size = CGSizeMake(MAX(window.frame.size.width, finalFrame.size.width), MAX(window.frame.size.height, finalFrame.size.height));
        if (!CGRectContainsRect(screenFrame, finalFrame)) {
            finalPosition.x = MIN(finalPosition.x, CGRectGetMaxX(screenFrame) - CGRectGetWidth(finalFrame));
            finalPosition.y = MIN(finalPosition.y, CGRectGetMaxY(screenFrame) - CGRectGetHeight(finalFrame));
        }
    }
    
    // Move the window to its final frame
    finalFrame.origin = finalPosition;
    window.frame = finalFrame;
}

@end
