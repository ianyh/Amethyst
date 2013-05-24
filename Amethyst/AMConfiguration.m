//
//  AMConfiguration.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMConfiguration.h"

#import <Carbon/Carbon.h>

#import "AMHotKeyManager.h"
#import "AMLayout.h"
#import "AMScreenManager.h"
#import "AMWindowManager.h"

@implementation AMConfiguration

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    NSUInteger modifier = NSAlternateKeyMask | NSShiftKeyMask;
    NSUInteger modifier2 = modifier | NSControlKeyMask;

    [hotKeyManager registerHotKeyWithKeyCode:kVK_Space modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] cycleLayout];
    }];

    // ANSI 1-3 are consecutive values in the virtual layout.
    // As far as I know Mac systems don't support more than three screens (laptop with 2 monitors) so this is probably fine
    for (NSUInteger screenIndex = 1; screenIndex <= 3; ++screenIndex) {
        UInt16 keyCode = kVK_ANSI_1 + (screenIndex - 1);
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

    [hotKeyManager registerHotKeyWithKeyCode:kVK_RightArrow modifiers:modifier handler:^{
        [windowManager pushToDesktopRight];
    }];
}

@end
