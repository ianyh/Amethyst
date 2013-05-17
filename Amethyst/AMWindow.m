//
//  AMWindow.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindow.h"

#import "NSScreen+FrameFlipping.h"

@interface AMWindow ()
@property (nonatomic, strong) NSScreen *cachedScreen;
@end

@implementation AMWindow

- (BOOL)isHidden {
    return [[self numberForKey:kAXHiddenAttribute] boolValue];
}

- (BOOL)isMinimized {
    return [[self numberForKey:kAXHiddenAttribute] boolValue];
}

- (BOOL)isResizable {
    Boolean sizeWriteable = NO;
    AXError error = AXUIElementIsAttributeSettable(self.axElementRef, kAXSizeAttribute, &sizeWriteable);
    if (error != kAXErrorSuccess) return NO;

    return sizeWriteable;
}

- (CGRect)frame {
    CFTypeRef pointRef;
    CFTypeRef sizeRef;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXPositionAttribute, &pointRef);
    if (error != kAXErrorSuccess || !pointRef) return CGRectNull;

    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXSizeAttribute, &sizeRef);
    if (error != kAXErrorSuccess || !sizeRef) return CGRectNull;

    CGPoint point;
    CGSize size;
    bool success;

    success = AXValueGetValue(pointRef, kAXValueCGPointType, &point);
    if (!success) return CGRectNull;

    success = AXValueGetValue(sizeRef, kAXValueCGSizeType, &size);
    if (!success) return CGRectNull;

    CGRect frame = { .origin.x = point.x, .origin.y = point.y, .size.width = size.width, .size.height = size.height };

    return frame;
}

- (void)setFrame:(CGRect)frame {
    CGRect currentFrame = [self frame];
    CGPoint position = frame.origin;
    CGSize size = frame.size;
    AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &position);
    AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &size);
    AXError error;

    if (!CGPointEqualToPoint(frame.origin, currentFrame.origin)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXPositionAttribute, positionRef);
        if (error != kAXErrorSuccess) {
            NSLog(@"Position Error: %d", error);
            return;
        }
    }

    if (!CGSizeEqualToSize(frame.size, currentFrame.size)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXSizeAttribute, sizeRef);
        if (error != kAXErrorSuccess) {
            NSLog(@"Size Error: %d", error);
            return;
        }
    }
}

- (NSScreen *)screen {
    // We cache the screen for two reasons:
    //   - Better performance
    //   - Window destruction leaves us with no way to compute the screen but we still need an accurate reference.
    if (!self.cachedScreen) {
        CGRect frame = [self frame];
        
        if (CGRectIsNull(frame)) {
            self.cachedScreen = [NSScreen mainScreen];
        } else {
            CGPoint center = { .x = CGRectGetMidX(frame), .y = CGRectGetMidY(frame) };
            
            for (NSScreen *screen in [NSScreen screens]) {
                CGRect screenFrame = [screen flippedFrame];
                if (CGRectContainsPoint(screenFrame, center)) {
                    self.cachedScreen = screen;
                }
            }
        }

        self.cachedScreen = self.cachedScreen ?: [NSScreen mainScreen];
    }

    return self.cachedScreen;
}

@end
