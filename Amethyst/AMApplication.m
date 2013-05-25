//
//  AMApplication.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMApplication.h"

#import "AMWindow.h"

@interface AMApplicationObservation : NSObject
@property (nonatomic, strong) NSString *notification;
@property (nonatomic, copy) AMAXNotificationHandler handler;
@end

@implementation AMApplicationObservation
@end

@interface AMApplication ()
@property (nonatomic, assign) AXObserverRef observerRef;
@property (nonatomic, strong) NSMutableDictionary *elementToObservations;

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
    if (_observerRef) {
        for (AMAccessibilityElement *element in [self.elementToObservations allKeys]) {
            for (AMApplicationObservation *observation in self.elementToObservations[element]) {
                AXObserverRemoveNotification(_observerRef, element.axElementRef, (__bridge CFStringRef)observation.notification);
            }
        }
        CFRelease(_observerRef);
    }
}

#pragma mark AXObserver

void observerCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon) {
    AMAXNotificationHandler callback = (__bridge AMAXNotificationHandler)refcon;
    callback([[AMWindow alloc] initWithAXElementRef:element]);
}

- (void)observeNotification:(CFStringRef)notification withElement:(AMAccessibilityElement *)accessibilityElement handler:(AMAXNotificationHandler)handler {
    if (!self.observerRef) {
        AXObserverRef observerRef;
        AXError error = AXObserverCreate([self processIdentifier], &observerCallback, &observerRef);

        if (error != kAXErrorSuccess) return;

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observerRef), kCFRunLoopDefaultMode);

        self.observerRef = observerRef;
        self.elementToObservations = [NSMutableDictionary dictionaryWithCapacity:1];
    }

    AMApplicationObservation *observation = [[AMApplicationObservation alloc] init];
    observation.notification = (__bridge NSString *)notification;
    observation.handler = handler;

    if (!self.elementToObservations[accessibilityElement]) {
        self.elementToObservations[accessibilityElement] = [NSMutableArray array];
    }
    [self.elementToObservations[accessibilityElement] addObject:observation];

    AXObserverAddNotification(self.observerRef, accessibilityElement.axElementRef, notification, (__bridge void *)observation.handler);
}

- (void)unobserveNotification:(CFStringRef)notification withElement:(AMAccessibilityElement *)accessibilityElement {
    for (AMApplicationObservation *observation in self.elementToObservations[accessibilityElement]) {
        AXObserverRemoveNotification(self.observerRef, accessibilityElement.axElementRef, (__bridge CFStringRef)observation.notification);
    }
    [self.elementToObservations removeObjectForKey:accessibilityElement];
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
