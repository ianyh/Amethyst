//
//  AMConfiguration.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMConfiguration.h"

#import "AMHotKeyManager.h"
#import "AMLayout.h"
#import "AMScreenManager.h"
#import "AMWindowManager.h"

@implementation AMConfiguration

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    AMModifierFlags modifier = NSAlternateKeyMask | NSShiftKeyMask;
    AMModifierFlags modifier2 = modifier | NSControlKeyMask;
    AMModifierFlags modifier3 = NSAlternateKeyMask | NSControlKeyMask;

    [hotKeyManager registerHotKeyWithKeyCode:kVK_Space modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] cycleLayout];
    }];

    for (NSUInteger screenIndex = 1; screenIndex <= 3; ++screenIndex) {
        AMKeyCode keyCode = [AMHotKeyManager keyCodeForNumber:@( screenIndex )];
        [hotKeyManager registerHotKeyWithKeyCode:keyCode modifiers:modifier handler:^{
            [windowManager focusScreenAtIndex:screenIndex];
        }];

        [hotKeyManager registerHotKeyWithKeyCode:keyCode modifiers:modifier2 handler:^{
            [windowManager throwToScreenAtIndex:screenIndex];
        }];
    }

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_H modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout shrinkMainPane];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_L modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout expandMainPane];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_Comma modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout increaseMainPaneCount];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_Period modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout decreaseMainPaneCount];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_J modifiers:modifier handler:^{
        [windowManager moveFocusCounterClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_K modifiers:modifier handler:^{
        [windowManager moveFocusClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_Return modifiers:modifier handler:^{
        [windowManager swapFocusedWindowToMain];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_J modifiers:modifier2 handler:^{
        [windowManager swapFocusedWindowCounterClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyCode:kVK_ANSI_K modifiers:modifier2 handler:^{
        [windowManager swapFocusedWindowClockwise];
    }];

    for (NSUInteger space = 1; space <= 10; ++space) {
        AMKeyCode keyCode = [AMHotKeyManager keyCodeForNumber:@( space )];
        [hotKeyManager registerHotKeyWithKeyCode:keyCode modifiers:modifier3 handler:^{
            [windowManager pushFocusedWindowToSpace:space];
        }];
    }
}

@end
