//
//  AMApplication.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMApplication.h"

#import "AMWindow.h"

typedef void (^AXObserverCallbackBlock)(AXObserverRef, AXUIElementRef, CFStringRef, void *);

@interface AMApplication ()
@property (nonatomic, assign) AXObserverRef observerRef;
@property (nonatomic, copy) AXObserverCallbackBlock observerCallback;
@property (nonatomic, strong) NSMutableArray *notificationCallbacks;

@property (nonatomic, strong) NSMutableArray *cachedWindows;
@end

@implementation AMApplication

#pragma mark Lifecycle

+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication {
    AXUIElementRef axElementRef = AXUIElementCreateApplication([runningApplication processIdentifier]);
    AMApplication *application = [[AMApplication alloc] initWithAXElementRef:axElementRef];
    CFRelease(axElementRef);

    return application;
}

- (void)dealloc {
    CFRelease(_observerRef);
}

#pragma mark AXObserver

- (void)observeNotification:(CFStringRef)notification withElement:(AMAccessibilityElement *)accessibilityElement callback:(AMObserverCallback)callback {
    if (!self.observerRef) {
        AXObserverRef observerRef;
        __unsafe_unretained typeof(self) weakSelf = self;
        self.observerCallback = ^(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon) {
            AMObserverCallback callback = (__bridge AMObserverCallback)refcon;
            if (element == weakSelf.axElementRef) {
                callback(weakSelf);
            } else {
                callback([[AMWindow alloc] initWithAXElementRef:element]);
            }
        };
        self.notificationCallbacks = [NSMutableArray array];

        AXObserverCreate([self processIdentifier], (__bridge void *)self.observerCallback, &observerRef);

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(self.observerRef), kCFRunLoopDefaultMode);

        self.observerRef = observerRef;
    }

    [self.notificationCallbacks addObject:[callback copy]];
    AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, (__bridge void *)callback);
}

#pragma mark Public Accessors

- (NSArray *)windows {
    if (!self.cachedWindows) {
        self.cachedWindows = [NSMutableArray array];
        NSArray *windowRefs = [self arrayForKey:kAXWindowsAttribute];
        for (NSUInteger index = 0; index < windowRefs.count; ++index) {
            AXUIElementRef windowRef = (__bridge AXUIElementRef)windowRefs[index];
            AMWindow *window = [[AMWindow alloc] initWithAXElementRef:windowRef];

            [self.cachedWindows addObject:window];
        }
    }
    return self.cachedWindows;
}

@end
