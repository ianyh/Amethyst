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
    if (![self isResizable]) return NO;

    NSString *subrole = [self stringForKey:kAXSubroleAttribute];

    if (!subrole) return YES;
    if ([subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) return YES;

    return NO;
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

- (AMModifierFlags)eventFlagsForSpace:(NSUInteger)space {
    AMModifierFlags eventFlags = kCGEventFlagMaskControl;
    if (space > 10) {
        eventFlags = eventFlags | kCGEventFlagMaskAlternate;
    }
    return eventFlags;
}

- (void)moveToSpace:(NSUInteger)space {
    if (space > 16) return;

    AMAccessibilityElement *zoomButtonElement = [self elementForKey:kAXZoomButtonAttribute];
    CGRect zoomButtonFrame = zoomButtonElement.frame;
    
    CGPoint mouseCursorPoint = { .x = CGRectGetMaxX(zoomButtonFrame) + 5.0, .y = CGRectGetMidY(zoomButtonFrame) };

    CGEventRef mouseMoveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseDownEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, mouseCursorPoint, kCGMouseButtonLeft);
    CGEventRef mouseUpEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, mouseCursorPoint, kCGMouseButtonLeft);

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

    CFRelease(mouseMoveEvent);
    CFRelease(mouseDownEvent);
    CFRelease(mouseUpEvent);
    CFRelease(keyboardEvent);
    CFRelease(keyboardEventUp);
}

- (void)bringToFocus {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:[self processIdentifier]];
    [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

    AXUIElementPerformAction(self.axElementRef, kAXRaiseAction);
}

@end
