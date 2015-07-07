//
//  AMPreferencesWindowController.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/26/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMPreferencesWindowController.h"

#import "AMGeneralPreferencesViewController.h"
#import "AMShortcutsPreferencesViewController.h"

#import "AMConfiguration.h"

@interface AMPreferencesWindowController ()
@property (nonatomic, assign) IBOutlet AMGeneralPreferencesViewController *generalController;
@property (nonatomic, assign) IBOutlet AMShortcutsPreferencesViewController *shortcutsController;
@end

@implementation AMPreferencesWindowController

- (id)init {
    self = [super initWithViewControllers:[NSMutableArray array] title:@"Preferences"];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self.class) owner:self topLevelObjects:nil];
        [self loadControllers];
    }
    return self;
}

- (void)loadControllers {
    [self addViewController:self.generalController];
    [self addViewController:self.shortcutsController];
    [self selectControllerAtIndex:0];
}

- (IBAction)showWindow:(id)sender {
    if ([AMConfiguration sharedConfiguration].hasCustomConfiguration) {
        NSRunAlertPanel(@"Warning", @"You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior.", @"OK", nil, nil);
    }
    [NSApp activateIgnoringOtherApps:YES];
    [super showWindow:sender];
}

@end
