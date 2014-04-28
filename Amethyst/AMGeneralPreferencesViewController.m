//
//  AMGeneralPreferencesViewController.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/26/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMGeneralPreferencesViewController.h"

#import "AMConfiguration.h"

@interface AMGeneralPreferencesViewController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSArray *floatingBundleIdentifiers;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;

- (IBAction)addFloatingApplication:(id)sender;
- (IBAction)removeFloatingApplication:(id)sender;
@end

@implementation AMGeneralPreferencesViewController

- (void)awakeFromNib {
    [super awakeFromNib];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (void)viewWillAppear {
    self.floatingBundleIdentifiers = [[AMConfiguration sharedConfiguration] floatingBundleIdentifiers];
    [self.tableView reloadData];
}

#pragma mark IBAction

- (IBAction)addFloatingApplication:(id)sender {
    
}

- (IBAction)removeFloatingApplication:(id)sender {

}

#pragma mark MASPreferencesViewController

- (NSString *)identifier {
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

- (NSString *)toolbarItemLabel {
    return @"General";
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.floatingBundleIdentifiers.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return self.floatingBundleIdentifiers[row];
}

@end
