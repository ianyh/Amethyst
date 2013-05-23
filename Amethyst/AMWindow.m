//
//  AMWindow.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindow.h"

#import "AMSystemWideElement.h"
#import "NSScreen+FrameAdjustment.h"

@interface AMWindow ()
@property (nonatomic, strong) NSScreen *cachedScreen;
@end

@implementation AMWindow

+ (AMWindow *)focusedWindow {
    AXUIElementRef applicationRef;
    AXUIElementRef windowRef;
    AXError error;
    
    error = AXUIElementCopyAttributeValue([AMSystemWideElement systemWideElement].axElementRef, kAXFocusedApplicationAttribute, (CFTypeRef *)&applicationRef);
    if (error != kAXErrorSuccess || !applicationRef) return nil;
    
    error = AXUIElementCopyAttributeValue(applicationRef, kAXFocusedWindowAttribute, (CFTypeRef *)&windowRef);
    if (error != kAXErrorSuccess || !windowRef) return nil;
    
    AMWindow *window = [[AMWindow alloc] initWithAXElementRef:windowRef];
    
    CFRelease(applicationRef);
    CFRelease(windowRef);
    
    return window;
}

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
    if (CGRectEqualToRect([self frame], frame)) return;

    // For some reason the accessibility frameworks seem to have issues with changing size in different directions.
    // e.g., increasing width while decreasing height doesn't seem to work correctly.
    // Therefore we collapse the window to zero and then expand out to meet the new frame.
    // This means that the first operation is always a contraction, and the second operation is always an expansion.
    [self setPosition:CGPointZero];
    [self setSize:CGSizeZero];
    [self setPosition:frame.origin];
    [self setSize:frame.size];
}

- (void)setPosition:(CGPoint)position {
    AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &position);
    AXError error;
    
    if (!CGPointEqualToPoint(position, [self frame].origin)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXPositionAttribute, positionRef);
        if (error != kAXErrorSuccess) {
            NSLog(@"Position Error: %d", error);
            return;
        }
    }
}

- (void)setSize:(CGSize)size {
    AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &size);
    AXError error;
    
    if (!CGSizeEqualToSize(size, [self frame].size)) {
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
                CGRect screenFrame = [screen adjustedFrame];
                if (CGRectContainsPoint(screenFrame, center)) {
                    self.cachedScreen = screen;
                }
            }
        }
        
        self.cachedScreen = self.cachedScreen ?: [NSScreen mainScreen];
    }
    
    return self.cachedScreen;
}

- (void)moveToScreen:(NSScreen *)screen {
    self.cachedScreen = nil;
    [self setPosition:[screen adjustedFrame].origin];
}

- (void)bringToFocus {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:[self processIdentifier]];
    [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

    AXUIElementPerformAction(self.axElementRef, kAXRaiseAction);
}

@end
