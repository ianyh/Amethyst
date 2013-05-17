//
//  AMAppDelegate.m
//  Amethyst
//
//  Created by Ian on 5/14/13.
//
//

#import "AMAppDelegate.h"

#import "AMWindowManager.h"

@interface AMAppDelegate ()
@property (nonatomic, strong) AMWindowManager *windowManager;

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) IBOutlet NSMenu *statusItemMenu;
@end

@implementation AMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.windowManager = [[AMWindowManager alloc] init];
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setTitle:@"AM"];
    [self.statusItem setMenu:self.statusItemMenu];
    [self.statusItem setHighlightMode:YES];
}

@end
