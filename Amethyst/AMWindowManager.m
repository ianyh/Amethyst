//
//  AMWindowManager.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMWindowManager.h"

#import "AMApplication.h"
#import "AMWindow.h"

@interface AMWindowManager ()
@property (nonatomic, strong) NSMutableArray *applications;
@property (nonatomic, strong) NSMutableArray *activeWindows;
@property (nonatomic, strong) NSMutableArray *inactiveWindows;

@property (nonatomic, strong) NSMutableArray *screensToReflow;

- (void)applicationDidLaunch:(NSNotification *)notification;
- (void)applicationDidTerminate:(NSNotification *)notification;
- (void)applicationDidHide:(NSNotification *)notification;
- (void)applicationDidUnhide:(NSNotification *)notification;

- (AMApplication *)applicationWithProcessIdentifier:(pid_t)processIdentifier;
- (void)addApplication:(AMApplication *)application;
- (void)removeApplication:(AMApplication *)application;
- (void)activateApplication:(AMApplication *)application;
- (void)deactivateApplication:(AMApplication *)application;

- (void)addWindow:(AMWindow *)window;
- (void)removeWindow:(AMWindow *)window;
- (void)activateWindow:(AMWindow *)window;
- (void)deactivateWindow:(AMWindow *)window;

- (void)markScreenToReflow:(NSScreen *)screen;
- (void)reflow;
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
    }
    return self;
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
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
                                [self addWindow:(AMWindow *)accessibilityElement];
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
    [self markScreenToReflow:[window screen]];

    if ([window isHidden] || [window isMinimized]) {
        [self.activeWindows addObject:window];
    } else {
        [self.inactiveWindows addObject:window];
    }

    AMApplication *application = [self applicationWithProcessIdentifier:[window processIdentifier]];
    [application observeNotification:kAXUIElementDestroyedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self removeWindow:window];
                                [self reflow];
                            }];
    [application observeNotification:kAXWindowMiniaturizedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self deactivateWindow:window];
                                [self reflow];
                            }];
    [application observeNotification:kAXWindowDeminiaturizedNotification
                         withElement:window
                            callback:^(AMAccessibilityElement *accessibilityElement) {
                                [self activateWindow:window];
                                [self reflow];
                            }];
}

- (void)removeWindow:(AMWindow *)window {
    [self markScreenToReflow:[window screen]];

    // TODO: leaking memory here in the observation callbacks above.
    [self.activeWindows removeObject:window];
    [self.inactiveWindows removeObject:window];
}

- (void)activateWindow:(AMWindow *)window {
    if ([self.activeWindows containsObject:window]) return;

    [self markScreenToReflow:[window screen]];

    [self.activeWindows addObject:window];
    [self.inactiveWindows removeObject:window];
}

- (void)deactivateWindow:(AMWindow *)window {
    if ([self.inactiveWindows containsObject:window]) return;

    [self markScreenToReflow:[window screen]];

    [self.activeWindows addObject:window];
    [self.inactiveWindows removeObject:window];
}

#pragma mark Layout

- (void)markScreenToReflow:(NSScreen *)screen {
    if ([self.screensToReflow containsObject:screen]) return;

    [self.screensToReflow addObject:screen];
}

- (void)reflow {
    for (NSScreen *screen in self.screensToReflow) {
        // TODO: reflow windows on the screen
    }
    [self.screensToReflow removeAllObjects];
}

@end
