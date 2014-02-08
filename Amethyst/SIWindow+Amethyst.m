//
//  SIWindow+Amethyst.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/5/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "SIWindow+Amethyst.h"
#import "AMConfiguration.h"

#import <objc/runtime.h>
#include <ApplicationServices/ApplicationServices.h>

static void *SIWindowFloatingKey = &SIWindowFloatingKey;

@implementation SIWindow (Amethyst)

- (BOOL)shouldBeManaged {
    if (!self.isResizable && !self.isMovable) {
        return NO;
    }

    NSString *subrole = [self stringForKey:kAXSubroleAttribute];

    if (!subrole) return YES;
    if ([subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) return YES;

    return NO;
}

- (BOOL)floating {
    return [objc_getAssociatedObject(self, SIWindowFloatingKey) boolValue];
}

- (void)setFloating:(BOOL)floating {
    objc_setAssociatedObject(self, SIWindowFloatingKey, @(floating), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)am_focusWindow {
    if (![self focusWindow]) return NO;

    if ([[AMConfiguration sharedConfiguration] mouseFollowsFocus]) {
        NSRect windowFrame = [self frame];
        NSPoint mouseCursorPoint = NSMakePoint(NSMidX(windowFrame), NSMidY(windowFrame));
        CGEventRef mouseMoveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, mouseCursorPoint, kCGMouseButtonLeft);
        CGEventSetFlags(mouseMoveEvent, 0);
        CGEventPost(kCGHIDEventTap, mouseMoveEvent);
        CFRelease(mouseMoveEvent);
    }

    return YES;
}

@end
