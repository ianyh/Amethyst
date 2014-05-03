//
//  AMShortcutsPreferencesListItemView.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/27/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "AMShortcutsPreferencesListItemView.h"

@interface AMShortcutsPreferencesListItemView ()
@property (nonatomic, strong) NSTextField *nameLabel;
@property (nonatomic, strong) MASShortcutView *shortcutView;
@end

@implementation AMShortcutsPreferencesListItemView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSTextField *label = [[NSTextField alloc] init];
        MASShortcutView *shortcutView = [[MASShortcutView alloc] initWithFrame:NSMakeRect(0, 0, 120, 19)];

        label.bezeled = NO;
        label.editable = NO;
        label.stringValue = @"";
        label.backgroundColor = [NSColor clearColor];
        [label sizeToFit];

        [self addSubview:label];
        [self addSubview:shortcutView];

        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.mas_centerY);
            make.left.equalTo(self.mas_left).with.offset(8);
//            make.right.lessThanOrEqualTo(shortcutView.mas_left);
        }];

        [shortcutView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.mas_centerY);
            make.right.equalTo(self.mas_right).with.offset(-16);
            make.width.equalTo(@120);
            make.height.equalTo(@19);
        }];

        self.nameLabel = label;
        self.shortcutView = shortcutView;
    }
    return self;
}

- (void)dealloc {
    _shortcutView.associatedUserDefaultsKey = nil;
}

@end
