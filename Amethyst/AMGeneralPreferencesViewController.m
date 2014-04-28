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
@property (nonatomic, copy) NSArray *layouts;
@property (nonatomic, copy) NSArray *floatingBundleIdentifiers;

@property (nonatomic, weak) IBOutlet NSTableView *layoutsTableView;
@property (nonatomic, weak) IBOutlet NSTableView *floatingTableView;

- (IBAction)addLayout:(id)sender;
- (IBAction)removeLayout:(id)sender;
- (IBAction)addFloatingApplication:(id)sender;
- (IBAction)removeFloatingApplication:(id)sender;
@end

@implementation AMGeneralPreferencesViewController

- (void)awakeFromNib {
    [super awakeFromNib];

    self.layoutsTableView.dataSource = self;
    self.layoutsTableView.delegate = self;

    self.floatingTableView.dataSource = self;
    self.floatingTableView.delegate = self;
}

- (void)viewWillAppear {
    self.layouts = [[AMConfiguration sharedConfiguration] layoutStrings];
    self.floatingBundleIdentifiers = [[AMConfiguration sharedConfiguration] floatingBundleIdentifiers];

    [self.layoutsTableView reloadData];
    [self.floatingTableView reloadData];
}

#pragma mark IBAction

- (IBAction)addLayout:(id)sender {

}

- (IBAction)removeLayout:(id)sender {

}

- (IBAction)addFloatingApplication:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSArray *applicationDirectories = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask];

    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = YES;
    openPanel.allowedFileTypes = @[ @"app" ];
    openPanel.prompt = @"Select";
    openPanel.directoryURL = applicationDirectories.firstObject;

    if ([openPanel runModal] == NSFileHandlingPanelCancelButton) {
        return;
    }

    NSMutableArray *floatingBundleIdentifiers = [self.floatingBundleIdentifiers mutableCopy];
    for (NSURL *applicationURL in openPanel.URLs) {
        NSBundle *applicationBundle = [NSBundle bundleWithURL:applicationURL];
        [floatingBundleIdentifiers addObject:applicationBundle.bundleIdentifier];
    }
    self.floatingBundleIdentifiers = floatingBundleIdentifiers;

    [[AMConfiguration sharedConfiguration] setFloatingBundleIdentifiers:self.floatingBundleIdentifiers];

    [self.floatingTableView reloadData];
}

- (IBAction)removeFloatingApplication:(id)sender {
    if (self.floatingTableView.selectedRow >= self.floatingBundleIdentifiers.count) {
        return;
    }

    NSMutableArray *floatingBundleIdentifiers = [self.floatingBundleIdentifiers mutableCopy];
    [floatingBundleIdentifiers removeObjectAtIndex:self.floatingTableView.selectedRow];
    self.floatingBundleIdentifiers = floatingBundleIdentifiers;

    [[AMConfiguration sharedConfiguration] setFloatingBundleIdentifiers:self.floatingBundleIdentifiers];

    [self.floatingTableView reloadData];
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
    if (tableView == self.layoutsTableView) {
        return self.layouts.count;
    }

    return self.floatingBundleIdentifiers.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.layoutsTableView) {
        return self.layouts[row];
    }

    return self.floatingBundleIdentifiers[row];
}

@end
