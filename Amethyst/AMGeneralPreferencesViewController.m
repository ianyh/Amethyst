//
//  AMGeneralPreferencesViewController.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/26/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMGeneralPreferencesViewController.h"

#import "Amethyst-Swift.h"

#import <CCNPreferencesWindowController/CCNPreferencesWindowController.h>

@interface AMGeneralPreferencesViewController () <CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, copy) NSArray *layouts;
@property (nonatomic, copy) NSArray *floatingBundleIdentifiers;

@property (nonatomic, weak) IBOutlet NSTableView *layoutsTableView;
@property (nonatomic, weak) IBOutlet NSTableView *floatingTableView;

- (IBAction)addLayout:(NSButton *)sender;
- (IBAction)addLayoutString:(NSMenuItem *)sender;
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
    self.layouts = [[Configuration sharedConfiguration] layoutStrings];
    self.floatingBundleIdentifiers = [[Configuration sharedConfiguration] floatingBundleIdentifiers];

    [self.layoutsTableView reloadData];
    [self.floatingTableView reloadData];
}

#pragma mark IBAction

- (IBAction)addLayout:(NSButton *)sender {
    NSMenu *layoutMenu = [[NSMenu alloc] initWithTitle:@""];

    for (NSString *layoutString in [[Configuration sharedConfiguration] availableLayoutStrings]) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:layoutString
                                                          action:@selector(addLayoutString:)
                                                   keyEquivalent:@""];
        menuItem.target = self;
        menuItem.action = @selector(addLayoutString:);

        [layoutMenu addItem:menuItem];
    }

    NSRect frame = [sender frame];
    NSPoint menuOrigin = [[sender superview] convertPoint:NSMakePoint(frame.origin.x, frame.origin.y + frame.size.height + 40)
                                                   toView:nil];

    NSEvent *event =  [NSEvent mouseEventWithType:NSLeftMouseDown
                                         location:menuOrigin
                                    modifierFlags:NSLeftMouseDownMask
                                        timestamp:0
                                     windowNumber:[[sender window] windowNumber]
                                          context:[[sender window] graphicsContext]
                                      eventNumber:0
                                       clickCount:1
                                         pressure:1];

    [NSMenu popUpContextMenu:layoutMenu withEvent:event forView:sender];
}

- (IBAction)addLayoutString:(NSMenuItem *)sender {
    NSMutableArray *layouts = [self.layouts mutableCopy];
    [layouts addObject:sender.title];
    self.layouts = layouts;

    [[Configuration sharedConfiguration] setLayoutStrings:self.layouts];

    [self.layoutsTableView reloadData];
}

- (IBAction)removeLayout:(id)sender {
    if (self.layoutsTableView.selectedRow >= self.layouts.count) {
        return;
    }

    NSMutableArray *layouts = [self.layouts mutableCopy];
    [layouts removeObjectAtIndex:self.layoutsTableView.selectedRow];
    self.layouts = layouts;

    [[Configuration sharedConfiguration] setLayoutStrings:self.layouts];

    [self.layoutsTableView reloadData];
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

    [[Configuration sharedConfiguration] setFloatingBundleIdentifiers:self.floatingBundleIdentifiers];

    [self.floatingTableView reloadData];
}

- (IBAction)removeFloatingApplication:(id)sender {
    if (self.floatingTableView.selectedRow >= self.floatingBundleIdentifiers.count) {
        return;
    }

    NSMutableArray *floatingBundleIdentifiers = [self.floatingBundleIdentifiers mutableCopy];
    [floatingBundleIdentifiers removeObjectAtIndex:self.floatingTableView.selectedRow];
    self.floatingBundleIdentifiers = floatingBundleIdentifiers;

    [[Configuration sharedConfiguration] setFloatingBundleIdentifiers:self.floatingBundleIdentifiers];

    [self.floatingTableView reloadData];
}

#pragma mark CCNPreferencesWindowControllerProtocol

- (NSString *)preferenceIdentifier {
    return NSStringFromClass(self.class);
}

- (NSImage *)preferenceIcon {
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

- (NSString *)preferenceTitle {
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
