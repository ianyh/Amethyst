//
//  AMShortcutsPreferencesViewController.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/26/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMShortcutsPreferencesViewController.h"

@implementation AMShortcutsPreferencesViewController

- (NSString *)identifier {
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

- (NSString *)toolbarItemLabel {
    return @"Shortcuts";
}

@end
