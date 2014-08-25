//
//  AMWindowManager.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindowManager.h"

#import "AMConfiguration.h"
#import "AMScreenManager.h"
#import "NSRunningApplication+Manageable.h"

@interface AMWindowManager () <AMScreenManagerDelegate>
@property (nonatomic, strong) NSMutableArray *applications;
@property (nonatomic, strong) NSMutableArray *windows;

@property (nonatomic, strong) NSArray *screenManagers;

@property (nonatomic, strong) id mouseMovedEventHandler;

- (void)applicationDidLaunch:(NSNotification *)notification;
- (void)applicationDidTerminate:(NSNotification *)notification;
- (void)applicationDidHide:(NSNotification *)notification;
- (void)applicationDidUnhide:(NSNotification *)notification;
- (void)activeSpaceDidChange:(NSNotification *)notification;
- (void)screenParametersDidChange:(NSNotification *)notification;

- (SIApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier;
- (void)addApplication:(SIApplication *)application;
- (void)removeApplication:(SIApplication *)application;
- (void)activateApplication:(SIApplication *)application;
- (void)deactivateApplication:(SIApplication *)application;

- (void)addWindow:(SIWindow *)window;
- (void)removeWindow:(SIWindow *)window;

- (void)updateScreenManagers;
- (void)markScreenForReflow:(NSScreen *)screen;

- (void)focusWindowWithMouseMovedEvent:(NSEvent *)event;
@end

@implementation AMWindowManager

- (id)init {
    self = [super init];
    if (self) {
        self.applications = [NSMutableArray array];
        self.windows = [NSMutableArray array];

        for (NSRunningApplication *runningApplication in NSWorkspace.sharedWorkspace.runningApplications) {
            if (!runningApplication.isManageable) continue;

            SIApplication *application = [SIApplication applicationWithRunningApplication:runningApplication];
            [self addApplication:application];
        }

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidLaunch:)
                                                                   name:NSWorkspaceDidLaunchApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidTerminate:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidHide:)
                                                                   name:NSWorkspaceDidHideApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, applicationDidUnhide:)
                                                                   name:NSWorkspaceDidUnhideApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@checkselector(self, activeSpaceDidChange:)
                                                                   name:NSWorkspaceActiveSpaceDidChangeNotification
                                                                 object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@checkselector(self, screenParametersDidChange:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];

        self.mouseMovedEventHandler = [NSEvent addGlobalMonitorForEventsMatchingMask:NSMouseMovedMask handler:^(NSEvent *event) {
            [self focusWindowWithMouseMovedEvent:event];
        }];

        [self updateScreenManagers];
    }
    return self;
}

- (void)dealloc {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark Public Methods

- (void)assignCurrentSpaceIdentifiers {
    CFArrayRef screenDictionaries = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    for (NSDictionary *screenDictionary in (__bridge NSArray *)screenDictionaries) {
        NSString *screenIdentifier = screenDictionary[@"Display Identifier"];
        AMScreenManager *screenManager = nil;
        for (AMScreenManager *manager in self.screenManagers) {
            CGSManagedDisplay display = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, NSRectToCGRect(manager.screen.frame));
            if ([screenIdentifier isEqualToString:(__bridge NSString *)display]) {
                screenManager = manager;
                CFRelease(display);
                break;
            }
            CFRelease(display);
        }
        
        screenManager.currentSpaceIdentifier = screenDictionary[@"Current Space"][@"uuid"];
    }
    CFRelease(screenDictionaries);
}

- (AMScreenManager *)screenManagerForCGWindowDescription:(NSDictionary *)description {
    CGRect windowFrame;
    CFDictionaryRef windowFrameDict = (__bridge CFDictionaryRef)description[(__bridge NSString *)kCGWindowBounds];
    CGRectMakeWithDictionaryRepresentation(windowFrameDict, &windowFrame);

    CGFloat lastVolume = 0;
    AMScreenManager *lastScreenManager = nil;

    for (AMScreenManager *screenManager in self.screenManagers) {
        CGRect screenFrame = [screenManager.screen frameIncludingDockAndMenu];
        CGRect intersection = CGRectIntersection(windowFrame, screenFrame);
        CGFloat volume = intersection.size.width * intersection.size.height;

        if (volume > lastVolume) {
            lastVolume = volume;
            lastScreenManager = screenManager;
        }
    }

    return lastScreenManager;
}

- (AMScreenManager *)focusedScreenManager {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    for (AMScreenManager *screenManager in self.screenManagers) {
        if ([screenManager.screen isEqual:focusedWindow.screen]) {
            return screenManager;
        }
    }
    return nil;
}

- (void)throwToScreenAtIndex:(NSUInteger)screenIndex {
    screenIndex = screenIndex - 1;

    if (screenIndex >= NSScreen.screens.count) return;

    AMScreenManager *screenManager = self.screenManagers[screenIndex];
    SIWindow *focusedWindow = [SIWindow focusedWindow];

    // Have to find the managed window object so that we can clear it's screen cache.
    for (SIWindow *window in self.windows) {
        if ([window isEqual:focusedWindow]) {
            focusedWindow = window;
        }
    }

    // If the window is already on the screen do nothing.
    if ([focusedWindow.screen isEqual:screenManager.screen]) return;

    [self markScreenForReflow:focusedWindow.screen];
    [focusedWindow moveToScreen:screenManager.screen];
    [self markScreenForReflow:screenManager.screen];
    [focusedWindow am_focusWindow];
}

- (void)focusScreenAtIndex:(NSUInteger)screenIndex {
    screenIndex = screenIndex - 1;

    if (screenIndex >= NSScreen.screens.count) return;

    AMScreenManager *screenManager = self.screenManagers[screenIndex];
    NSArray *windows = [self windowsForScreen:screenManager.screen];

    if (windows.count == 0) return;

    [windows[0] am_focusWindow];
}

- (void)moveFocusCounterClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSArray *windows = [self windowsForScreen:screen];

    // If there are no windows there is nothing to change focus to.
    if (windows.count == 0) return;

    NSUInteger windowIndex = [windows indexOfObject:focusedWindow];
    if (windowIndex == NSNotFound) {
        windowIndex = 0;
    }

    NSUInteger windowToFocusIndex = (windowIndex == 0 ? windows.count - 1 : windowIndex - 1);
    SIWindow *windowToFocus = windows[windowToFocusIndex];

    [windowToFocus am_focusWindow];
}

- (void)moveFocusClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSArray *windows = [self windowsForScreen:screen];

    // If there are no windows there is nothing to change focus to.
    if (windows.count == 0) return;

    NSUInteger windowIndex = [windows indexOfObject:focusedWindow];
    if (windowIndex == NSNotFound) {
        windowIndex = windows.count - 1;
    }

    SIWindow *windowToFocus = windows[(windowIndex + 1) % windows.count];

    [windowToFocus am_focusWindow];
}

- (void)swapFocusedWindowToMain {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow || focusedWindow.floating) return;

    NSScreen *screen = focusedWindow.screen;
    NSArray *windows = [self activeWindowsForScreen:screen];

    if (windows.count == 0) return;

    NSUInteger mainWindowIndex = [self.windows indexOfObject:windows[0]];
    NSUInteger focusedWindowIndex = [self.windows indexOfObject:focusedWindow];
    if (focusedWindowIndex == NSNotFound) {
        return;
    }

    [self.windows exchangeObjectAtIndex:focusedWindowIndex withObjectAtIndex:mainWindowIndex];
    [self markScreenForReflow:focusedWindow.screen];
    [focusedWindow am_focusWindow];
}

- (void)swapFocusedWindowCounterClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow || focusedWindow.floating) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSArray *windows = [self activeWindowsForScreen:screen];

    NSUInteger focusedWindowIndex = [windows indexOfObject:focusedWindow];
    if (focusedWindowIndex == NSNotFound) return;

    SIWindow *windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)];

    NSUInteger focusedWindowActiveIndex = [self.windows indexOfObject:focusedWindow];
    NSUInteger windowToSwapWithActiveIndex = [self.windows indexOfObject:windowToSwapWith];

    [self.windows exchangeObjectAtIndex:focusedWindowActiveIndex withObjectAtIndex:windowToSwapWithActiveIndex];
    [self markScreenForReflow:focusedWindow.screen];
    [focusedWindow am_focusWindow];
}

- (void)swapFocusedWindowClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow || focusedWindow.floating) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSArray *windows = [self activeWindowsForScreen:screen];

    NSUInteger focusedWindowIndex = [windows indexOfObject:focusedWindow];
    if (focusedWindowIndex == NSNotFound) return;

    SIWindow *windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count];

    NSUInteger focusedWindowActiveIndex = [self.windows indexOfObject:focusedWindow];
    NSUInteger windowToSwapWithActiveIndex = [self.windows indexOfObject:windowToSwapWith];

    [self.windows exchangeObjectAtIndex:focusedWindowActiveIndex withObjectAtIndex:windowToSwapWithActiveIndex];
    [self markScreenForReflow:focusedWindow.screen];
    [focusedWindow am_focusWindow];
}

- (void)swapFocusedWindowScreenClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow || focusedWindow.floating) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSUInteger screenIndex = [self.screenManagers indexOfObjectPassingTest:^BOOL(AMScreenManager *screenManager, NSUInteger idx, BOOL *stop) {
        if ([screenManager.screen isEqual:screen]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];

    screenIndex = screenIndex + 1 % self.screenManagers.count;

    NSScreen *screenToMoveTo = [self.screenManagers[screenIndex] screen];
    [focusedWindow moveToScreen:screenToMoveTo];

    [self markScreenForReflow:screen];
    [self markScreenForReflow:screenToMoveTo];
}

- (void)swapFocusedWindowScreenCounterClockwise {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow || focusedWindow.floating) {
        [self focusScreenAtIndex:1];
        return;
    }

    NSScreen *screen = focusedWindow.screen;
    NSUInteger screenIndex = [self.screenManagers indexOfObjectPassingTest:^BOOL(AMScreenManager *screenManager, NSUInteger idx, BOOL *stop) {
        if ([screenManager.screen isEqual:screen]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];

    screenIndex = (screenIndex == 0 ? self.screenManagers.count - 1 : screenIndex - 1);

    NSScreen *screenToMoveTo = [self.screenManagers[screenIndex] screen];
    [focusedWindow moveToScreen:screenToMoveTo];

    [self markScreenForReflow:screen];
    [self markScreenForReflow:screenToMoveTo];
}

- (void)pushFocusedWindowToSpace:(NSUInteger)space {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow) return;

    [focusedWindow moveToSpace:space];
    [focusedWindow am_focusWindow];
}

#pragma mark Notification Handlers

- (void)applicationDidLaunch:(NSNotification *)notification {
    NSRunningApplication *launchedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [SIApplication applicationWithRunningApplication:launchedApplication];
    [self addApplication:application];
}

- (void)applicationDidTerminate:(NSNotification *)notification {
    NSRunningApplication *terminatedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[terminatedApplication processIdentifier]];
    [self removeApplication:application];
}

- (void)applicationDidHide:(NSNotification *)notification {
    NSRunningApplication *hiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[hiddenApplication processIdentifier]];
    [self deactivateApplication:application];
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    NSRunningApplication *unhiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    SIApplication *application = [self applicationWithProcessIdentifier:[unhiddenApplication processIdentifier]];
    [self activateApplication:application];
}

- (void)activeSpaceDidChange:(NSNotification *)notification {
    [self assignCurrentSpaceIdentifiers];

    for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if (!runningApplication.isManageable) continue;

        pid_t processIdentifier = runningApplication.processIdentifier;
        SIApplication *application = [self applicationWithProcessIdentifier:processIdentifier];
        if (application) {
            [application dropWindowsCache];

            for (SIWindow *window in application.windows) {
                [self addWindow:window];
            }
        }
    }

    CFArrayRef screenDictionaries = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    for (NSDictionary *screenDictionary in (__bridge NSArray *)screenDictionaries) {
        NSString *screenIdentifier = screenDictionary[@"Display Identifier"];
        AMScreenManager *screenManager = nil;
        for (AMScreenManager *manager in self.screenManagers) {
            CGSManagedDisplay display = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, NSRectToCGRect(manager.screen.frame));
            if ([screenIdentifier isEqualToString:(__bridge NSString *)display]) {
                screenManager = manager;
                CFRelease(display);
                break;
            }
            CFRelease(display);
        }

        CGSSpace currentSpace = [screenDictionary[@"Current Space"][@"id64"] intValue];
        CGSSpaceType currentSpaceType = CGSSpaceGetType(CGSDefaultConnection, currentSpace);
        
        screenManager.isFullScreen = (currentSpaceType == kCGSSpaceFullscreen);
    }

    [self markAllScreensForReflow];
}

- (void)screenParametersDidChange:(NSNotification *)notification {
    [self updateScreenManagers];
}

#pragma mark Applications Management

- (SIApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier {
    for (SIApplication *application in self.applications) {
        if (application.processIdentifier == processIdentifier) {
            return application;
        }
    }

    return nil;
}

- (void)addApplication:(SIApplication *)application {
    if ([self.applications containsObject:application]) return;

    [self.applications addObject:application];

    for (SIWindow *window in application.windows) {
        [self addWindow:window];
    }

    BOOL floating = application.floating;

    [application observeNotification:kAXWindowCreatedNotification
                         withElement:application
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];
                                SIWindow *window = (SIWindow *)accessibilityElement;
                                window.floating = floating;
                                [self addWindow:window];
                            }];
    [application observeNotification:kAXFocusedWindowChangedNotification
                         withElement:application
                             handler:^(SIAccessibilityElement *accessibilityElement) {
                                 SIWindow *focusedWindow = [SIWindow focusedWindow];
                                 [self markScreenForReflow:focusedWindow.screen];
                             }];
    [application observeNotification:kAXApplicationActivatedNotification
                         withElement:application
                             handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                                          selector:@checkselector(self, applicationActivated:)
                                                                            object:nil];
                                 [self performSelector:@checkselector(self, applicationActivated:) withObject:nil afterDelay:0.2];
                             }];
}

- (void)applicationActivated:(id)sender {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow.isFullScreen) {
        [self markScreenForReflow:focusedWindow.screen];
    }
}

- (void)removeApplication:(SIApplication *)application {
    for (SIWindow *window in application.windows) {
        [self removeWindow:window];
    }
    [self.applications removeObject:application];
}

- (void)activateApplication:(SIApplication *)application {
    pid_t processIdentifier = application.processIdentifier;
    for (SIWindow *window in [self.windows copy]) {
        if (window.processIdentifier == processIdentifier) {
            [self markScreenForReflow:window.screen];
        }
    }
}

- (void)deactivateApplication:(SIApplication *)application {
    pid_t processIdentifier = application.processIdentifier;
    for (SIWindow *window in [self.windows copy]) {
        if (window.processIdentifier == processIdentifier) {
            [self markScreenForReflow:window.screen];
        }
    }
}

#pragma mark Windows Management

- (void)addWindow:(SIWindow *)window {
    if ([self.windows containsObject:window]) return;

    if (!window.shouldBeManaged) return;

    [self.windows addObject:window];
    [self markScreenForReflow:window.screen];

    SIApplication *application = [self applicationWithProcessIdentifier:window.processIdentifier];

    window.floating = application.floating;
    if (AMConfiguration.sharedConfiguration.floatSmallWindows && window.frame.size.width < 500 && window.frame.size.height < 500) {
        window.floating = YES;
    }

    [application observeNotification:kAXUIElementDestroyedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [self removeWindow:window];
                            }];
    [application observeNotification:kAXWindowMiniaturizedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [self markScreenForReflow:window.screen];
                            }];
    [application observeNotification:kAXWindowDeminiaturizedNotification
                         withElement:window
                            handler:^(SIAccessibilityElement *accessibilityElement) {
                                [self markScreenForReflow:window.screen];
                            }];
    [application observeNotification:kAXWindowMovedNotification
                         withElement:window
                             handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self assignCurrentSpaceIdentifiers];
                             }];
}

- (void)removeWindow:(SIWindow *)window {
    [self markAllScreensForReflow];

    SIApplication *application = [self applicationWithProcessIdentifier:window.processIdentifier];
    [application unobserveNotification:kAXUIElementDestroyedNotification withElement:window];
    [application unobserveNotification:kAXWindowMiniaturizedNotification withElement:window];
    [application unobserveNotification:kAXWindowDeminiaturizedNotification withElement:window];

    [self.windows removeObject:window];
}

- (NSArray *)windowsForScreen:(NSScreen *)screen {
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SIWindow *window = (SIWindow *)evaluatedObject;
        return [window.screen isEqual:screen] && window.isActive;
    }]];
}

- (NSArray *)activeWindowsForScreen:(NSScreen *)screen {
    return [self.windows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SIWindow *window = (SIWindow *)evaluatedObject;
        return [window.screen isEqual:screen] && window.isActive && window.shouldBeManaged && !window.floating;
    }]];
}

- (void)toggleFloatForFocusedWindow {
    SIWindow *focusedWindow = [SIWindow focusedWindow];

    for (SIWindow *window in self.windows) {
        if ([window isEqual:focusedWindow]) {
            window.floating = !window.floating;
            [self markScreenForReflow:window.screen];
            return;
        }
    }

    [self addWindow:focusedWindow];
    focusedWindow.floating = NO;
    [self markScreenForReflow:focusedWindow.screen];
}

#pragma mark Screen Management

- (void)updateScreenManagers {
    NSMutableArray *screenManagers = [NSMutableArray arrayWithCapacity:NSScreen.screens.count];

    for (NSScreen *screen in NSScreen.screens) {
        AMScreenManager *screenManager;

        CGSManagedDisplay managedDisplay = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, screen.frame);
        for (AMScreenManager *oldScreenManager in self.screenManagers) {
            CGSManagedDisplay oldManagedDisplay = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, oldScreenManager.screen.frame);
            if ([(__bridge NSString *)managedDisplay isEqual:(__bridge NSString *)oldManagedDisplay]) {
                screenManager = oldScreenManager;
                CFRelease(oldManagedDisplay);
                break;
            }
            CFRelease(oldManagedDisplay);
        }

        if (!screenManager) {
            screenManager = [[AMScreenManager alloc] initWithScreen:screen delegate:self];
        }

        [screenManagers addObject:screenManager];

        CFRelease(managedDisplay);
    }

    // Window managers are sorted by screen position along the x-axis.
    [screenManagers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSScreen *screen1 = ((AMScreenManager *)obj1).screen;
        NSScreen *screen2 = ((AMScreenManager *)obj2).screen;

        CGFloat x1 = screen1.frameWithoutDockOrMenu.origin.x;
        CGFloat x2 = screen2.frameWithoutDockOrMenu.origin.x;

        if (x1 > x2) {
            return NSOrderedDescending;
        } else if (x1 < x2) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];

    self.screenManagers = screenManagers;

    [self assignCurrentSpaceIdentifiers];
    [self markAllScreensForReflow];
}

- (void)markAllScreensForReflow {
    for (AMScreenManager *screenManager in self.screenManagers) {
        [screenManager setNeedsReflow];
    }
}

- (void)markScreenForReflow:(NSScreen *)screen {
    for (AMScreenManager *screenManager in self.screenManagers) {
        if ([screenManager.screen isEqual:screen]) {
            [screenManager setNeedsReflow];
        }
    }
}

- (void)displayCurrentLayout {
    for (AMScreenManager *screenManager in self.screenManagers) {
        [screenManager displayLayoutHUD];
    }
}

#pragma mark AMScreenManagerDelegate

- (NSArray *)activeWindowsForScreenManager:(AMScreenManager *)screenManager {
    return [self activeWindowsForScreen:screenManager.screen];
}

#pragma mark Private

- (void)focusWindowWithMouseMovedEvent:(NSEvent *)event {
    if (![[AMConfiguration sharedConfiguration] focusFollowsMouse]) {
        return;
    }

    CGPoint mousePoint = NSPointToCGPoint([event locationInWindow]);
    mousePoint.y = NSScreen.mainScreen.frame.size.height - mousePoint.y;

    SIWindow *window = [SIWindow focusedWindow];

    // If the point is already in the frame of the focused window do nothing.
    if (CGRectContainsPoint(window.frame, mousePoint)) {
        return;
    }

    CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    CFIndex windowDescriptionsCount = CFArrayGetCount(windowDescriptions);

    // If there are no windows on screen do nothing
    if (windowDescriptionsCount == 0) {
        return;
    }

    NSMutableArray *windowsAtPoint = [NSMutableArray arrayWithCapacity:CFArrayGetCount(windowDescriptions)];
    for (NSDictionary *windowDescription in (__bridge NSArray *)windowDescriptions) {
        CGRect windowFrame;
        CFDictionaryRef windowFrameDictionary = (__bridge CFDictionaryRef)windowDescription[(__bridge NSString *)kCGWindowBounds];
        CGRectMakeWithDictionaryRepresentation(windowFrameDictionary, &windowFrame);

        if (CGRectContainsPoint(windowFrame, mousePoint)) {
            [windowsAtPoint addObject:windowDescription];
        }
    }

    CFRelease(windowDescriptions);

    // If there no windows under the mouse cursor do nothing
    if (windowsAtPoint.count == 0) {
        return;
    }

    // If there is only one window at that point focus it
    if (windowsAtPoint.count == 1) {
        window = [self windowForCGWindowDescription:windowsAtPoint[0]];
        [window focusWindow];
        return;
    }

    // Otherwise find the window that's actually on top
    NSDictionary *windowToFocus = nil;
    NSUInteger minCount = windowDescriptionsCount;
    for (NSDictionary *windowDescription in windowsAtPoint) {
        CGWindowID windowID;
        CFNumberRef windowNumber = (__bridge CFNumberRef)windowDescription[(__bridge NSNumber *)kCGWindowNumber];
        CFNumberGetValue(windowNumber, kCGWindowIDCFNumberType, &windowID);

        CFArrayRef windowsAboveWindow = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenAboveWindow, windowID);

        if (CFArrayGetCount(windowsAboveWindow) < minCount) {
            windowToFocus = windowDescription;
            minCount = CFArrayGetCount(windowsAboveWindow);
        }

        CFRelease(windowsAboveWindow);
    }

    window = [self windowForCGWindowDescription:windowToFocus];
    [window focusWindow];
}

- (SIWindow *)windowForCGWindowDescription:(NSDictionary *)windowDescription {
    for (SIWindow *window in self.windows) {
        pid_t windowOwnerProcessIdentifier = [windowDescription[(__bridge NSString *)kCGWindowOwnerPID] intValue];
        if (windowOwnerProcessIdentifier != window.processIdentifier) continue;

        CGRect windowFrame;
        NSDictionary *boundsDictionary = windowDescription[(__bridge NSString *)kCGWindowBounds];
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &windowFrame);
        if (!CGRectEqualToRect(windowFrame, window.frame)) continue;

        NSString *windowTitle = windowDescription[(__bridge NSString *)kCGWindowName];
        if (![windowTitle isEqualToString:[window stringForKey:kAXTitleAttribute]]) continue;

        return window;
    }

    return nil;
}

@end
