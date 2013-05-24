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

- (void)bringToFocus {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:[self processIdentifier]];
    [runningApplication activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];

    AXUIElementPerformAction(self.axElementRef, kAXRaiseAction);
}

@end
