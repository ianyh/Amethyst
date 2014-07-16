//
//  AMLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMLayout.h"

#import "AMConfiguration.h"

@implementation AMLayout

+ (NSString *)layoutName { return nil; }

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    @throw [NSException exceptionWithName:NSGenericException reason:@"Method should be implemented by subclasses." userInfo:nil];
}

- (void)shrinkMainPane {}
- (void)expandMainPane {}

- (void)increaseMainPaneCount {}
- (void)decreaseMainPaneCount {}

- (CGRect)adjustedFrameForLayout:(NSScreen *)screen {
    return [[AMConfiguration sharedConfiguration] ignoreMenuBar] ? screen.frameIncludingDockAndMenu : screen.frameWithoutDockOrMenu;
}

- (void)assignFrame:(CGRect)finalFrame toWindow:(SIWindow *)window focused:(BOOL)focused screenFrame:(CGRect)screenFrame {
    CGPoint finalPosition = finalFrame.origin;
    
    finalFrame.size.height -= 2 * [self windowPadding];
    finalFrame.size.width -= 2 * [self windowPadding];
    
    finalPosition.x += [self windowPadding];
    finalPosition.y += [self windowPadding];
    
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

- (NSUInteger)windowPadding{
    return [[AMConfiguration sharedConfiguration] windowPadding];
}

@end
