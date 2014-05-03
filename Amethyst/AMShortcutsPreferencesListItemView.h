//
//  AMShortcutsPreferencesListItemView.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/27/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MASShortcut/MASShortcutView.h>
#import <MASShortcut/MASShortcutView+UserDefaults.h>

@interface AMShortcutsPreferencesListItemView : NSView
@property (nonatomic, strong, readonly) NSTextField *nameLabel;
@property (nonatomic, strong, readonly) MASShortcutView *shortcutView;
@end
