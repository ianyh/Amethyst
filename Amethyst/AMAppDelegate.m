//
//  AMAppDelegate.m
//  Amethyst
//
//  Created by Ian on 5/14/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAppDelegate.h"

#import "AMConfiguration.h"
#import "AMHotKeyManager.h"
#import "AMPreferencesWindowController.h"
#import "AMWindowManager.h"

#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CoreServices/CoreServices.h>
//#import <Crashlytics/Crashlytics.h>
#import <IYLoginItem/NSBundle+LoginItem.h>

@interface AMAppDelegate ()
@property (nonatomic, assign) IBOutlet AMPreferencesWindowController *preferencesWindowController;

@property (nonatomic, strong) AMWindowManager *windowManager;
@property (nonatomic, strong) AMHotKeyManager *hotKeyManager;

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) IBOutlet NSMenu *statusItemMenu;
@property (nonatomic, strong) IBOutlet NSMenuItem *startAtLoginMenuItem;

- (IBAction)toggleStartAtLogin:(id)sender;
- (IBAction)relaunch:(id)sender;
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

//    NSString *crashlyticsAPIKey = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AMCrashlyticsAPIKey"];
//    if (crashlyticsAPIKey) {
//        [Crashlytics startWithAPIKey:crashlyticsAPIKey];
//    }

    self.windowManager = [[AMWindowManager alloc] init];
    self.hotKeyManager = [[AMHotKeyManager alloc] init];

    [AMConfiguration.sharedConfiguration setUpWithHotKeyManager:self.hotKeyManager windowManager:self.windowManager];
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = [NSImage imageNamed:@"icon-statusitem"];
    self.statusItem.menu = self.statusItemMenu;
    self.statusItem.highlightMode = YES;

    self.startAtLoginMenuItem.state = (NSBundle.mainBundle.isLoginItem ? NSOnState : NSOffState);
}

- (IBAction)toggleStartAtLogin:(id)sender {
    if (self.startAtLoginMenuItem.state == NSOffState) {
        [NSBundle.mainBundle addToLoginItems];
    } else {
        [NSBundle.mainBundle removeFromLoginItems];
    }
    self.startAtLoginMenuItem.state = (NSBundle.mainBundle.isLoginItem ? NSOnState : NSOffState);
}

- (IBAction)relaunch:(id)sender {
    NSString *myPath = [NSString stringWithFormat:@"%s", [[[NSBundle mainBundle] executablePath] fileSystemRepresentation]];
    [NSTask launchedTaskWithLaunchPath:myPath arguments:@[]];
    [NSApp terminate:self];
}

@end
