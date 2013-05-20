//
//  AMWindowManager.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindowManager.h"

#import "AMApplication.h"
#import "AMFullscreenLayout.h"
#import "AMScreenManager.h"
#import "AMTallLayout.h"
#import "AMWindow.h"
#import "NSScreen+FrameFlipping.h"

@interface AMWindowManager () <AMScreenManagerDelegate>
@property (nonatomic, strong) NSMutableArray *applications;
@property (nonatomic, strong) NSMutableArray *activeWindows;
@property (nonatomic, strong) NSMutableArray *inactiveWindows;

@property (nonatomic, strong) NSArray *screenManagers;
@property (nonatomic, strong) NSMutableArray *screensToReflow;

- (void)applicationDidLaunch:(NSNotification *)notification;
- (void)applicationDidTerminate:(NSNotification *)notification;
- (void)applicationDidHide:(NSNotification *)notification;
- (void)applicationDidUnhide:(NSNotification *)notification;
- (void)screenParametersDidChange:(NSNotification *)notification;

- (AMApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier;
- (void)addApplication:(AMApplication *)application;
- (void)removeApplication:(AMApplication *)application;
- (void)activateApplication:(AMApplication *)application;
- (void)deactivateApplication:(AMApplication *)application;

- (void)addWindow:(AMWindow *)window;
- (void)removeWindow:(AMWindow *)window;
- (void)activateWindow:(AMWindow *)window;
- (void)deactivateWindow:(AMWindow *)window;

- (void)updateScreenManagers;
- (void)markAllScreensForReflow;
- (void)markScreenForReflow:(NSScreen *)screen;
@end

@implementation AMWindowManager

- (id)init {
    self = [super init];
    if (self) {
        self.applications = [NSMutableArray array];
        self.activeWindows = [NSMutableArray array];
        self.inactiveWindows = [NSMutableArray array];

        self.screensToReflow = [NSMutableArray array];

        for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
            AMApplication *application = [AMApplication applicationWithRunningApplication:runningApplication];
            [self addApplication:application];
        }

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(applicationDidLaunch:)
                                                                   name:NSWorkspaceDidLaunchApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(applicationDidTerminate:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(applicationDidHide:)
                                                                   name:NSWorkspaceDidHideApplicationNotification
                                                                 object:nil];
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(applicationDidUnhide:)
                                                                   name:NSWorkspaceDidUnhideApplicationNotification
                                                                 object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenParametersDidChange:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];


        [self updateScreenManagers];
    }
    return self;
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Public Methods

- (void)cycleLayout {
    AMWindow *focusedWindow = [AMWindow focusedWindow];
    for (AMScreenManager *screenManager in self.screenManagers) {
        if ([screenManager.screen isEqual:[focusedWindow screen]]) {
            [screenManager cycleLayout];
        }
    }
}

- (void)throwToScreenAtIndex:(NSUInteger)screenIndex {
    screenIndex = screenIndex - 1;

    if (screenIndex >= [[NSScreen screens] count]) return;

    AMScreenManager *screenManager = self.screenManagers[screenIndex];
    AMWindow *focusedWindow = [AMWindow focusedWindow];

    // Have to find the managed window object so that we can clear it's screen cache.
    for (AMWindow *window in self.activeWindows) {
	if ([window isEqual:focusedWindow]) {
	    focusedWindow = window;
	}
    }

    // If the window is already on the screen do nothing.
    if ([[focusedWindow screen] isEqual:screenManager.screen]) return;

    [self markScreenForReflow:[focusedWindow screen]];
    [focusedWindow moveToScreen:screenManager.screen];
    [self markScreenForReflow:screenManager.screen];
}

#pragma mark Notification Handlers

- (void)applicationDidLaunch:(NSNotification *)notification {
    NSRunningApplication *launchedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    AMApplication *application = [AMApplication applicationWithRunningApplication:launchedApplication];
    [self addApplication:application];
}

- (void)applicationDidTerminate:(NSNotification *)notification {
    NSRunningApplication *terminatedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    AMApplication *application = [self applicationWithProcessIdentifier:[terminatedApplication processIdentifier]];
    [self removeApplication:application];
}

- (void)applicationDidHide:(NSNotification *)notification {
    NSRunningApplication *hiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    AMApplication *application = [self applicationWithProcessIdentifier:[hiddenApplication processIdentifier]];
    [self deactivateApplication:application];
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    NSRunningApplication *unhiddenApplication = notification.userInfo[NSWorkspaceApplicationKey];
    AMApplication *application = [self applicationWithProcessIdentifier:[unhiddenApplication processIdentifier]];
    [self activateApplication:application];
}

- (void)screenParametersDidChange:(NSNotification *)notification {
    [self updateScreenManagers];
}

#pragma mark Applications Management

- (AMApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier {
    for (AMApplication *application in self.applications) {
        if (application.processIdentifier == processIdentifier) {
            return application;
        }
    }

    return nil;
}

- (void)addApplication:(AMApplication *)application {
    if ([self.applications containsObject:application]) return;

    [self.applications addObject:application];

    for (AMWindow *window in [application windows]) {
        [self addWindow:window];
    }

    [application observeNotification:kAXWindowCreatedNotification
                         withElement:application
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                AMWindow *window = (AMWindow *)accessibilityElement;
                                [self addWindow:window];
                                [self markScreenForReflow:[window screen]];
                            }];
}

- (void)removeApplication:(AMApplication *)application {
    for (AMWindow *window in [self.activeWindows copy]) {
        [self removeWindow:window];
    }
    for (AMWindow *window in [self.inactiveWindows copy]) {
        [self removeWindow:window];
    }
    [self.applications removeObject:application];
}

- (void)activateApplication:(AMApplication *)application {
    pid_t processIdentifier = [application processIdentifier];
    for (AMWindow *window in [self.inactiveWindows copy]) {
        if ([window processIdentifier] == processIdentifier) {
            [self activateWindow:window];
        }
    }
}

- (void)deactivateApplication:(AMApplication *)application {
    pid_t processIdentifier = [application processIdentifier];
    for (AMWindow *window in [self.activeWindows copy]) {
        if ([window processIdentifier] == processIdentifier) {
            [self deactivateWindow:window];
        }
    }
}

#pragma mark Windows Management

- (void)addWindow:(AMWindow *)window {
    if (![window isResizable]) return;

    [self markScreenForReflow:[window screen]];

    if ([window isHidden] || [window isMinimized]) {
        [self.inactiveWindows addObject:window];
    } else {
        [self.activeWindows addObject:window];
    }

    AMApplication *application = [self applicationWithProcessIdentifier:[window processIdentifier]];
    [application observeNotification:kAXUIElementDestroyedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self removeWindow:window];
                                [self markScreenForReflow:[window screen]];
                            }];
    [application observeNotification:kAXWindowMiniaturizedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self deactivateWindow:window];
                                [self markScreenForReflow:[window screen]];
                            }];
    [application observeNotification:kAXWindowDeminiaturizedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self activateWindow:window];
                                [self markScreenForReflow:[window screen]];
                            }];
}

- (void)removeWindow:(AMWindow *)window {
    [self markScreenForReflow:[window screen]];

    // TODO: leaking memory here in the observation callbacks above.
    [self.activeWindows removeObject:window];
    [self.inactiveWindows removeObject:window];
}

- (void)activateWindow:(AMWindow *)window {
    if ([self.activeWindows containsObject:window]) return;

    [self markScreenForReflow:[window screen]];

    [self.activeWindows addObject:window];
    [self.inactiveWindows removeObject:window];
}

- (void)deactivateWindow:(AMWindow *)window {
    if ([self.inactiveWindows containsObject:window]) return;

    [self markScreenForReflow:[window screen]];

    [self.activeWindows addObject:window];
    [self.inactiveWindows removeObject:window];
}

#pragma mark Screen Management

- (void)updateScreenManagers {
    NSMutableArray *screenManagers = [NSMutableArray arrayWithCapacity:[[NSScreen screens] count]];
    
    for (NSScreen *screen in [NSScreen screens]) {
        AMScreenManager *screenManager;
        
        for (AMScreenManager *oldScreenManager in self.screenManagers) {
            if ([oldScreenManager.screen isEqual:screen]) {
                screenManager = oldScreenManager;
                break;
            }
        }
        
        if (!screenManager) {
            screenManager = [[AMScreenManager alloc] initWithScreen:screen delegate:self];
        }
        
        [screenManagers addObject:screenManager];
    }
    
    // Window managers are sorted by screen position along the x-axis.
    [screenManagers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSScreen *screen1 = ((AMScreenManager *)obj1).screen;
        NSScreen *screen2 = ((AMScreenManager *)obj2).screen;
        
        CGFloat x1 = [screen1 flippedFrame].origin.x;
        CGFloat x2 = [screen2 flippedFrame].origin.x;
        
        if (x1 > x2) {
            return NSOrderedDescending;
        } else if (x1 < x2) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    self.screenManagers = screenManagers;
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
    return [self.activeWindows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        AMWindow *window = (AMWindow *)evaluatedObject;
        return [[window screen] isEqual:screenManager.screen];
    }]];
}

@end
