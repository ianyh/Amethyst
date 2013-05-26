//
//  AMWindow.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindow.h"

#import "AMHotKeyManager.h"
#import "AMSystemWideElement.h"
#import "NSScreen+FrameAdjustment.h"

@interface AMWindow ()
@property (nonatomic, strong) NSScreen *cachedScreen;
@end

@implementation AMWindow

#pragma mark Lifecycle

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

#pragma mark NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <frame: %@>", [super description], CGRectCreateDictionaryRepresentation([self frame])];
}

- (BOOL)shouldBeManaged {
    if (![self isMovable]) return NO;

    NSString *subrole = [self stringForKey:kAXSubroleAttribute];
    
    if (!subrole) return YES;
    if ([subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) return YES;
    
    return NO;
}

- (BOOL)isActive {
    if ([[self numberForKey:kAXHiddenAttribute] boolValue]) return NO;
    if ([[self numberForKey:kAXMinimizedAttribute] boolValue]) return NO;

    CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    pid_t processIdentifier = self.processIdentifier;
    for (NSDictionary *dictionary in (__bridge NSArray *)windowDescriptions) {
        pid_t windowOwnerProcessIdentifier = [dictionary[(__bridge NSString *)kCGWindowOwnerPID] intValue];
        if (windowOwnerProcessIdentifier != processIdentifier) continue;

        CGRect windowFrame;
        NSDictionary *boundsDictionary = dictionary[(__bridge NSString *)kCGWindowBounds];
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &windowFrame);
        if (!CGRectEqualToRect(windowFrame, self.frame)) continue;

        NSNumber *windowOnScreen = dictionary[(__bridge NSString *)kCGWindowIsOnscreen];
        if ([windowOnScreen boolValue]) return YES;
    }

    return NO;
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

- (void)moveToSpace:(NSUInteger)space {
    if (space > 16) return;

    AMAccessibilityElement *zoomButtonElement = [self elementForKey:kAXZoomButtonAttribute];
    CGRect zoomButtonFrame = zoomButtonElement.frame;
    CGRect windowFrame = [self frame];

    CGEventRef defaultEvent = CGEventCreate(NULL);
    CGPoint startingCursorPoint = CGEventGetLocation(defaultEvent);
    CGPoint mouseCursorPoint = { .x = CGRectGetMaxX(zoomButtonFrame) + 5.0, .y = windowFrame.origin.y + 5.0 };

    CGEventRef mouseMoveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseDownEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseUpEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseRestoreEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, startingCursorPoint, kCGMouseButtonLeft);

    CGKeyCode keyCode = [AMHotKeyManager keyCodeForNumber:@( space )];

    CGEventRef keyboardEvent = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyboardEventUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);

    CGEventSetFlags(mouseMoveEvent, 0);
    CGEventSetFlags(mouseDownEvent, 0);
    CGEventSetFlags(mouseUpEvent, 0);
    CGEventSetFlags(keyboardEvent, kCGEventFlagMaskControl);
    CGEventSetFlags(keyboardEventUp, 0);

    // Move the mouse into place at the window's toolbar
    CGEventPost(kCGHIDEventTap, mouseMoveEvent);
    // Mouse down to grab hold of the window
    CGEventPost(kCGHIDEventTap, mouseDownEvent);
    // Send the shortcut command to get Mission Control to switch spaces from under the window.
    CGEventPost(kCGHIDEventTap, keyboardEvent);
    CGEventPost(kCGHIDEventTap, keyboardEventUp);
    // Let go of the window.
    CGEventPost(kCGHIDEventTap, mouseUpEvent);
    // Move the cursor back to its previous position.
    CGEventPost(kCGHIDEventTap, mouseRestoreEvent);

    CFRelease(defaultEvent);
    CFRelease(mouseMoveEvent);
    CFRelease(mouseDownEvent);
    CFRelease(mouseUpEvent);
    CFRelease(mouseRestoreEvent);
    CFRelease(keyboardEvent);
    CFRelease(keyboardEventUp);
}

- (void)bringToFocus {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:[self processIdentifier]];
    [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

    AXUIElementPerformAction(self.axElementRef, kAXRaiseAction);
}

@end
