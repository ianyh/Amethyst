//
//  AMConfiguration.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMConfiguration.h"

#import "AMHotKeyManager.h"
#import "AMWindowManager.h"

@implementation AMConfiguration

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    [hotKeyManager registerHotKeyWithKey:@" " modifiers:NSCommandKeyMask | NSShiftKeyMask handler:^{
        [windowManager cycleLayout];
    }];
}

@end
