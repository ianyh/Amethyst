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

@interface AMWindow ()
@property (nonatomic, strong) NSScreen *cachedScreen;
@end

@implementation AMWindow

#pragma mark Lifecycle

+ (AMWindow *)focusedWindow {
    AXUIElementRef applicationRef;
    AXUIElementRef windowRef;
    AXError error;

    // Get the focused application from the systemwide element.
    error = AXUIElementCopyAttributeValue([AMSystemWideElement systemWideElement].axElementRef, kAXFocusedApplicationAttribute, (CFTypeRef *)&applicationRef);
    if (error != kAXErrorSuccess || !applicationRef) return nil;

    // Get the focused window from the focused application.
    error = AXUIElementCopyAttributeValue(applicationRef, kAXFocusedWindowAttribute, (CFTypeRef *)&windowRef);
    if (error != kAXErrorSuccess || !windowRef) return nil;

    // Generate the window object for the ax element.
    AMWindow *window = [[AMWindow alloc] initWithAXElementRef:windowRef];

    // The window can actually be a sheet, and if that is the case we actually
    // want to return the sheet's parent window as it contains the sheet and
    // it's what we are actually going to be managing.
    if (window.isSheet) {
        AMAccessibilityElement *parent = [window elementForKey:kAXParentAttribute];

        if (!parent) return nil;

        window = [[AMWindow alloc] initWithAXElementRef:parent.axElementRef];
    }
    
    CFRelease(applicationRef);
    CFRelease(windowRef);
    
    return window;
}

#pragma mark NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <frame: %@>", super.description, CGRectCreateDictionaryRepresentation(self.frame)];
}

- (BOOL)shouldBeManaged {
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

        NSString *windowTitle = dictionary[(__bridge NSString *)kCGWindowName];
        if (![windowTitle isEqualToString:[self stringForKey:kAXTitleAttribute]]) continue;

        return YES;
    }

    DDLogWarn(@"Couldn't find matching window description for window %@", self);

    return NO;
}

- (BOOL)isSheet {
    return [[self stringForKey:kAXRoleAttribute] isEqualToString:(__bridge NSString *)kAXSheetRole];
}

- (NSScreen *)screen {
    // We cache the screen for two reasons:
    //   - Better performance
    //   - Window destruction leaves us with no way to compute the screen but we still need an accurate reference.
    if (!self.cachedScreen) {
        CGRect frame = self.frame;
        
        if (CGRectIsNull(frame)) {
            self.cachedScreen = NSScreen.mainScreen;
        } else {
            CGPoint center = { .x = CGRectGetMidX(frame), .y = CGRectGetMidY(frame) };
            
            for (NSScreen *screen in NSScreen.screens) {
                CGRect screenFrame = screen.frameWithoutDockOrMenu;
                if (CGRectContainsPoint(screenFrame, center)) {
                    self.cachedScreen = screen;
                }
            }
        }
        
        self.cachedScreen = self.cachedScreen ?: NSScreen.mainScreen;
    }
    
    return self.cachedScreen;
}

- (void)moveToScreen:(NSScreen *)screen {
    DDLogInfo(@"Moving window %@ to screen %@", self, screen);
    [self dropScreenCache];
    self.position = screen.frameWithoutDockOrMenu.origin;
}

- (void)dropScreenCache {
    self.cachedScreen = nil;
}

- (void)moveToSpace:(NSUInteger)space {
    if (space > 16) return;

    AMAccessibilityElement *zoomButtonElement = [self elementForKey:kAXZoomButtonAttribute];
    CGRect zoomButtonFrame = zoomButtonElement.frame;
    CGRect windowFrame = self.frame;

    CGEventRef defaultEvent = CGEventCreate(NULL);
    CGPoint startingCursorPoint = CGEventGetLocation(defaultEvent);
    CGPoint mouseCursorPoint = {
        .x = (zoomButtonElement ? CGRectGetMaxX(zoomButtonFrame) + 5.0 : windowFrame.origin.x + 5.0),
        .y = windowFrame.origin.y + 5.0
    };

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

    DDLogInfo(@"Sending window %@ to space %d using anchor point %@",
              self,
              (unsigned int)space,
              CGPointCreateDictionaryRepresentation(mouseCursorPoint));

    // Move the mouse into place at the window's toolbar
    CGEventPost(kCGHIDEventTap, mouseMoveEvent);
    // Mouse down to grab hold of the window
    CGEventPost(kCGHIDEventTap, mouseDownEvent);
    // Send the shortcut command to get Mission Control to switch spaces from under the window.
    CGEventPost(kCGHIDEventTap, keyboardEvent);
    CGEventPost(kCGHIDEventTap, keyboardEventUp);

    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // Let go of the window.
        CGEventPost(kCGHIDEventTap, mouseUpEvent);
        // Move the cursor back to its previous position.
        CGEventPost(kCGHIDEventTap, mouseRestoreEvent);
        CFRelease(mouseUpEvent);
        CFRelease(mouseRestoreEvent);
    });

    CFRelease(defaultEvent);
    CFRelease(mouseMoveEvent);
    CFRelease(mouseDownEvent);
    CFRelease(keyboardEvent);
    CFRelease(keyboardEventUp);
}

- (void)bringToFocus {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier];
    [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

    DDLogInfo(@"Bringing window to focus %@", self);

    AXUIElementPerformAction(self.axElementRef, kAXRaiseAction);
}

@end
