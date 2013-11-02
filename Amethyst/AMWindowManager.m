//
//  AMWindowManager.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindowManager.h"

#import "AMFullscreenLayout.h"
#import "AMScreenManager.h"
#import "AMTallLayout.h"
#import "NSRunningApplication+Manageable.h"

@interface AMWindowManager () <AMScreenManagerDelegate>
@property (nonatomic, strong) NSMutableArray *applications;
@property (nonatomic, strong) NSMutableArray *windows;
@property (nonatomic, strong) NSString *currentSpaceIdentifier;

@property (nonatomic, strong) NSArray *screenManagers;

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
- (void)markAllScreensForReflow;
- (void)markScreenForReflow:(NSScreen *)screen;
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
        

        self.currentSpaceIdentifier = [self activeSpaceIdentifier];

        [self updateScreenManagers];
    }
    return self;
}

- (void)dealloc {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark Public Methods

- (NSString *)activeSpaceIdentifier {
    [[NSUserDefaults standardUserDefaults] removeSuiteNamed:@"com.apple.spaces"];
    [[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.apple.spaces"];

    NSArray *spaceProperties = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"SpacesDisplayConfiguration"][@"Space Properties"];
    NSMutableDictionary *spaceIdentifiersByWindowNumber = [NSMutableDictionary dictionary];
    for (NSDictionary *spaceDictionary in spaceProperties) {
        NSArray *windows = spaceDictionary[@"windows"];
        for (NSNumber *window in windows) {
            if (spaceIdentifiersByWindowNumber[window]) {
                spaceIdentifiersByWindowNumber[window] = [spaceIdentifiersByWindowNumber[window] arrayByAddingObject:spaceDictionary[@"name"]];
            } else {
                spaceIdentifiersByWindowNumber[window] = @[ spaceDictionary[@"name"] ];
            }
        }
    }

    CFArrayRef windowDescriptions = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    NSString *activeSpaceIdentifier = nil;

    for (NSDictionary *dictionary in (__bridge NSArray *)windowDescriptions) {
        NSNumber *windowNumber = dictionary[(__bridge NSString *)kCGWindowNumber];
        NSArray *spaceIdentifiers = spaceIdentifiersByWindowNumber[windowNumber];

        if (spaceIdentifiers.count == 1) {
            activeSpaceIdentifier = spaceIdentifiers[0];
            break;
        }
    }

    CFRelease(windowDescriptions);

    return activeSpaceIdentifier;
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
}

- (void)focusScreenAtIndex:(NSUInteger)screenIndex {
    screenIndex = screenIndex - 1;
    
    if (screenIndex >= NSScreen.screens.count) return;
    
    AMScreenManager *screenManager = self.screenManagers[screenIndex];
    NSArray *windows = [self windowsForScreen:screenManager.screen];

    if (windows.count == 0) return;

    [windows[0] focusWindow];
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

    [windowToFocus focusWindow];
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
    
    [windowToFocus focusWindow];
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
}

- (void)pushFocusedWindowToSpace:(NSUInteger)space {
    SIWindow *focusedWindow = [SIWindow focusedWindow];
    if (!focusedWindow) return;

    [focusedWindow moveToSpace:space];
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
    self.currentSpaceIdentifier = nil;
    self.currentSpaceIdentifier = [self activeSpaceIdentifier];

    [self markAllScreensForReflow];

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
    [self markScreenForReflow:focusedWindow.screen];
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
            focusedWindow = window;
        }
    }

    focusedWindow.floating = !focusedWindow.floating;
    [self markScreenForReflow:focusedWindow.screen];
}

#pragma mark Screen Management

- (void)updateScreenManagers {
    NSMutableArray *screenManagers = [NSMutableArray arrayWithCapacity:NSScreen.screens.count];
    
    for (NSScreen *screen in NSScreen.screens) {
        AMScreenManager *screenManager;
        
        for (AMScreenManager *oldScreenManager in self.screenManagers) {
            if ([oldScreenManager.screen isEqual:screen]) {
                screenManager = oldScreenManager;
                break;
            }
        }
        
        if (!screenManager) {
            screenManager = [[AMScreenManager alloc] initWithScreen:screen delegate:self];
            RAC(screenManager, currentSpaceIdentifier) = RACObserve(self, currentSpaceIdentifier);
        }
        
        [screenManagers addObject:screenManager];
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

#pragma mark AMScreenManagerDelegate

- (NSArray *)activeWindowsForScreenManager:(AMScreenManager *)screenManager {
    return [self activeWindowsForScreen:screenManager.screen];
}

@end
