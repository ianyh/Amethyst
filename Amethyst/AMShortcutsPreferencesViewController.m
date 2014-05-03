//
//  AMShortcutsPreferencesViewController.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/26/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMShortcutsPreferencesViewController.h"

#import "AMConfiguration.h"
#import "AMShortcutsPreferencesListItemView.h"

@interface AMShortcutsPreferencesViewController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSArray *hotKeyNameToDefaultsKey;

@property (nonatomic, strong) IBOutlet NSTableView *tableView;
@end

@implementation AMShortcutsPreferencesViewController

- (void)awakeFromNib {
    [super awakeFromNib];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (void)viewWillAppear {
    self.hotKeyNameToDefaultsKey = [[AMConfiguration sharedConfiguration] hotKeyNameToDefaultsKey];
}

#pragma mark MASPreferencesViewController

- (NSString *)identifier {
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameAdvanced];
}

- (NSString *)toolbarItemLabel {
    return @"Shortcuts";
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.hotKeyNameToDefaultsKey.count;
}

#pragma mark NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSRect frame = NSMakeRect(0, 0, tableView.frame.size.width, 30);
    AMShortcutsPreferencesListItemView *shortcutItemView = [[AMShortcutsPreferencesListItemView alloc] initWithFrame:frame];
    NSString *name = self.hotKeyNameToDefaultsKey[row][0];
    NSString *key = self.hotKeyNameToDefaultsKey[row][1];

    shortcutItemView.nameLabel.stringValue = name;
    shortcutItemView.shortcutView.associatedUserDefaultsKey = key;

    return shortcutItemView;
}

@end
