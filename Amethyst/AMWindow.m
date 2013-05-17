//
//  AMWindow.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindow.h"

#import "NSScreen+FrameFlipping.h"

@implementation AMWindow

- (id)initWithAXElementRef:(AXUIElementRef)axElementRef {
    self = [super initWithAXElementRef:axElementRef];
    [self frame];
    return self;
}

- (BOOL)isHidden {
    return [[self numberForKey:kAXHiddenAttribute] boolValue];
}

- (BOOL)isMinimized {
    return [[self numberForKey:kAXHiddenAttribute] boolValue];
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
    CGRect frame = [self frame];

    if (CGRectIsNull(frame)) return [NSScreen mainScreen];

    for (NSScreen *screen in [NSScreen screens]) {
        CGRect screenFrame = [screen flippedFrame];
        if (CGRectContainsPoint(screenFrame, frame.origin)) {
            return screen;
        }
    }

    return [NSScreen mainScreen];
}

@end
