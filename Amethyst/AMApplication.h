//
//  AMApplication.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

// Type defining blocks used as handlers of accessibility notifications.
//
// accessibilityElement - The accessibility element associated with the
//                        notification. Will either be an element owned by the
//                        application or the application itself.
typedef void (^AMAXNotificationHandler)(AMAccessibilityElement *accessibilityElement);

// Specific accessibility wrapper for application elements.
@interface AMApplication : AMAccessibilityElement

// Attempts to construct an accessibility wrapper from an NSRunningApplication
// instance.
//
// runningApplication - A running application in the shared workspace.
//
// Returns an AMApplication instance if an accessibility element could be
// constructed from the running application instance. Returns nil otherwise.
+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication;

// Registers a notification handler for an accessibility notification.
//
// notification         - The notification to register a handler for.
// accessibilityElement - The accessibility element associated with the
//                        notification. Must be an element owned by the
//                        application or the application itself.
// handler              - A block to be called when the notification is received
//                        for the accessibility element.
//
// Note that a strong reference to the handler is maintained, so any memory
// captured by the block will not be released until the notification handler is
// unregistered by calling unobserveNotification:withElement:
- (void)observeNotification:(CFStringRef)notification withElement:(AMAccessibilityElement *)accessibilityElement handler:(AMAXNotificationHandler)handler;

// Unregisters a notification handler for an accessibility notification.
//
// notification         - The notification to unregister a handler for.
// accessibilityElement - The accessibility element associated with the
//                        notification. Must be an element owned by the
//                        application or the application itself.
//
// If a notification handler was previously registered for the notification and
// accessibility element the application will unregister the notification
// handler and release its reference to the handler block and any captured state
// therein.
- (void)unobserveNotification:(CFStringRef)notification withElement:(AMAccessibilityElement *)accessibilityElement;

// Returns an array of AMWindow objects for all windows in the application.
- (NSArray *)windows;

// Drops any cached windows so that the windows returned by a call to windows
// will be representative of the most up to date state of the application.
- (void)dropWindowsCache;

@end
