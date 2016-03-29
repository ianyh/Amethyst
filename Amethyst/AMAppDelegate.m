//
//  AMAppDelegate.m
//  Amethyst
//
//  Created by Ian on 5/14/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAppDelegate.h"

#import "AMConfiguration.h"
#import "AMGeneralPreferencesViewController.h"
#import "AMHotKeyManager.h"
#import "AMShortcutsPreferencesViewController.h"
#import "AMWindowManager.h"

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

#import <CCNLaunchAtLoginItem/CCNLaunchAtLoginItem.h>
#import <CCNPreferencesWindowController/CCNPreferencesWindowController.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CoreServices/CoreServices.h>
//#import <IYLoginItem/NSBundle+LoginItem.h>

@interface AMAppDelegate ()
@property (nonatomic, strong) CCNLaunchAtLoginItem *loginItem;
@property (nonatomic, strong) CCNPreferencesWindowController *preferencesWindowController;

@property (nonatomic, strong) AMWindowManager *windowManager;
@property (nonatomic, strong) AMHotKeyManager *hotKeyManager;

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) IBOutlet NSMenu *statusItemMenu;
@property (nonatomic, strong) IBOutlet NSMenuItem *versionMenuItem;
@property (nonatomic, strong) IBOutlet NSMenuItem *startAtLoginMenuItem;

- (IBAction)toggleStartAtLogin:(id)sender;
- (IBAction)relaunch:(id)sender;
- (IBAction)showPreferencesWindow:(id)sender;
@end

@implementation AMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [DDLog addLogger:DDASLLogger.sharedInstance];
    [DDLog addLogger:DDTTYLogger.sharedInstance];

    [AMConfiguration.sharedConfiguration loadConfiguration];

    NSString *appcastURLString;
    if ([[AMConfiguration sharedConfiguration] useCanaryBuild]) {
        appcastURLString = [[NSBundle mainBundle] infoDictionary][@"SUCanaryFeedURL"];
    } else {
        appcastURLString = [[NSBundle mainBundle] infoDictionary][@"SUFeedURL"];
    }
    [[SUUpdater sharedUpdater] setFeedURL:[NSURL URLWithString:appcastURLString]];

    RAC(self, statusItem.image) = [RACObserve(AMConfiguration.sharedConfiguration, tilingEnabled) map:^id(NSNumber *tilingEnabled) {
        NSImage *statusImage;
        if (tilingEnabled.boolValue) {
            statusImage = [NSImage imageNamed:@"icon-statusitem"];
        } else {
            statusImage = [NSImage imageNamed:@"icon-statusitem-disabled"];
        }
        [statusImage setTemplate:YES];
        return statusImage;
    }];

    NSString *crashlyticsAPIKey = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AMCrashlyticsAPIKey"];
    if (crashlyticsAPIKey) {
        [Fabric with:@[[Crashlytics class]]];
#if DEBUG
        [Crashlytics sharedInstance].debugMode = YES;
#endif
    }

    self.preferencesWindowController = [[CCNPreferencesWindowController alloc] init];
    self.preferencesWindowController.centerToolbarItems = NO;
    self.preferencesWindowController.allowsVibrancy = YES;
    NSArray *preferencesViewControllers = @[
                                            [AMGeneralPreferencesViewController new],
                                            [AMShortcutsPreferencesViewController new]
                                            ];
    [self.preferencesWindowController setPreferencesViewControllers:preferencesViewControllers];

    self.windowManager = [[AMWindowManager alloc] init];
    self.hotKeyManager = [[AMHotKeyManager alloc] init];

    [AMConfiguration.sharedConfiguration setUpWithHotKeyManager:self.hotKeyManager windowManager:self.windowManager];
}

- (void)awakeFromNib {
    [super awakeFromNib];

    NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    NSString *shortVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = [NSImage imageNamed:@"icon-statusitem"];
    self.statusItem.menu = self.statusItemMenu;
    self.statusItem.highlightMode = YES;

    self.versionMenuItem.title = [NSString stringWithFormat:@"Version %@ (%@)", shortVersion, version];

    self.loginItem = [CCNLaunchAtLoginItem itemForBundle:NSBundle.mainBundle];
    self.startAtLoginMenuItem.state = (self.loginItem.isActive ? NSOnState : NSOffState);
}

- (IBAction)toggleStartAtLogin:(id)sender {
    if (self.startAtLoginMenuItem.state == NSOffState) {
        [self.loginItem activate];
    } else {
        [self.loginItem deActivate];
    }
    self.startAtLoginMenuItem.state = (self.loginItem.isActive ? NSOnState : NSOffState);
}

- (IBAction)relaunch:(id)sender {
    NSString *myPath = [NSString stringWithFormat:@"%s", [[[NSBundle mainBundle] executablePath] fileSystemRepresentation]];
    [NSTask launchedTaskWithLaunchPath:myPath arguments:@[]];
    [NSApp terminate:self];
}

- (IBAction)showPreferencesWindow:(id)sender {
    if ([AMConfiguration sharedConfiguration].hasCustomConfiguration) {
        NSRunAlertPanel(@"Warning", @"You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior.", @"OK", nil, nil);
    }

    [self.preferencesWindowController showPreferencesWindow];
}

@end
