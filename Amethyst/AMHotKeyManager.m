//
//  AMHotKeyManager.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMHotKeyManager.h"

#import <MASShortcut/Shortcut.h>

AMKeyCode AMKeyCodeInvalid = 0xFF;

@interface AMHotKey : NSObject
@property (nonatomic, assign) EventHotKeyRef hotKeyRef;
@property (nonatomic, copy) AMHotKeyHandler handler;

- (id)init DEPRECATED_ATTRIBUTE;
- (id)initWithHotKeyRef:(EventHotKeyRef)hotKeyRef handler:(AMHotKeyHandler)handler;
@end

@implementation AMHotKey

- (id)init { return nil; }

- (id)initWithHotKeyRef:(EventHotKeyRef)hotKeyRef handler:(AMHotKeyHandler)handler {
    self = [super init];
    if (self) {
        self.hotKeyRef = hotKeyRef;
        self.handler = handler;
    }
    return self;
}

@end

@interface AMHotKeyManager ()
@property (nonatomic, copy) NSDictionary *stringToKeyCodes;
@end

@implementation AMHotKeyManager

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        [self constructKeyCodeMap];
        [MASShortcutValidator sharedValidator].allowAnyShortcutWithOptionModifier = YES;
    }
    return self;
}

#pragma mark Public Methods

+ (AMKeyCode)keyCodeForNumber:(NSNumber *)number {
    NSString *string = [NSString stringWithFormat:@"%@", number];

    if (string.length == 0) return AMKeyCodeInvalid;

    switch ([string characterAtIndex:string.length - 1]) {
        case '1':
            return kVK_ANSI_1;
        case '2':
            return kVK_ANSI_2;
        case '3':
            return kVK_ANSI_3;
        case '4':
            return kVK_ANSI_4;
        case '5':
            return kVK_ANSI_5;
        case '6':
            return kVK_ANSI_6;
        case '7':
            return kVK_ANSI_7;
        case '8':
            return kVK_ANSI_8;
        case '9':
            return kVK_ANSI_9;
        case '0':
            return kVK_ANSI_0;
        default:
            return AMKeyCodeInvalid;
    }
}

#pragma mark Key Code Mapping

- (void)constructKeyCodeMap {
    if (self.stringToKeyCodes) return;

    NSMutableDictionary *stringToKeyCodes = [NSMutableDictionary dictionary];

    // Generate unicode character keymapping from keyboard layout data.  We go
    // through all keycodes and create a map of string representations to a list
    // of key codes. It has to map to a list because a string representation
    // canmap to multiple codes (e.g., 1 and numpad 1 both have string
    // representation "1").
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    
    // For non-unicode layouts
    if (!layoutData) {
        CFRelease(currentKeyboard);
        
        currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
        layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    }
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);

    UInt32 keysDown = 0;
    UniChar chars[4];
    UniCharCount realLength;

    for (AMKeyCode keyCode = 0; keyCode < AMKeyCodeInvalid; ++keyCode) {
        switch (keyCode) {
            case kVK_ANSI_Keypad0:
            case kVK_ANSI_Keypad1:
            case kVK_ANSI_Keypad2:
            case kVK_ANSI_Keypad3:
            case kVK_ANSI_Keypad4:
            case kVK_ANSI_Keypad5:
            case kVK_ANSI_Keypad6:
            case kVK_ANSI_Keypad7:
            case kVK_ANSI_Keypad8:
            case kVK_ANSI_Keypad9:
                continue;
            default:
                break;
        }

        UCKeyTranslate(keyboardLayout,
                       keyCode,
                       kUCKeyActionDisplay,
                       0,
                       LMGetKbdType(),
                       kUCKeyTranslateNoDeadKeysBit,
                       &keysDown,
                       sizeof(chars) / sizeof(chars[0]),
                       &realLength,
                       chars);

        NSString *string = (__bridge NSString *)CFStringCreateWithCharacters(kCFAllocatorDefault, chars, realLength);

        if (stringToKeyCodes[string]) {
            stringToKeyCodes[string] = [stringToKeyCodes[string] arrayByAddingObject:@(keyCode)];
        } else {
            stringToKeyCodes[string] = @[ @(keyCode) ];
        }
    }

    CFRelease(currentKeyboard);

    // Add codes for non-printable characters. They are not printable so they
    // are not generated from the keyboard layout data.
    stringToKeyCodes[@"space"] = @[ @(kVK_Space) ];
    stringToKeyCodes[@"enter"] = @[ @(kVK_Return) ];
    stringToKeyCodes[@"up"] = @[ @(kVK_UpArrow) ];
    stringToKeyCodes[@"right"] = @[ @(kVK_RightArrow) ];
    stringToKeyCodes[@"down"] = @[ @(kVK_DownArrow) ];
    stringToKeyCodes[@"left"] = @[ @(kVK_LeftArrow) ];

    self.stringToKeyCodes = stringToKeyCodes;
}

#pragma mark Hot Key Management

- (UInt32)carbonModifiersFromModifiers:(NSUInteger)modifiers {
    UInt32 carbonModifiers = 0;

    if (modifiers & NSShiftKeyMask) {
        carbonModifiers = carbonModifiers | shiftKey;
    }

    if (modifiers & NSCommandKeyMask) {
        carbonModifiers = carbonModifiers | cmdKey;
    }

    if (modifiers & NSAlternateKeyMask) {
        carbonModifiers = carbonModifiers | optionKey;
    }

    if (modifiers & NSControlKeyMask) {
        carbonModifiers = carbonModifiers | controlKey;
    }

    return carbonModifiers;
}

- (void)registerHotKeyWithKeyString:(NSString *)string modifiers:(AMModifierFlags)modifiers handler:(AMHotKeyHandler)handler  defaultsKey:(NSString *)defaultsKey override:(BOOL)override {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey] && !override) {
        [[MASShortcutBinder sharedBinder] bindShortcutWithDefaultsKey:defaultsKey toAction:handler];
        return;
    }

    NSArray *keyCodes = self.stringToKeyCodes[string.lowercaseString];

    if (keyCodes.count == 0) {
        DDLogError(@"String \"%@\" does not map to any keycodes", string);
        return;
    }

    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:[keyCodes[0] unsignedShortValue] modifierFlags:modifiers];
    [[MASShortcutBinder sharedBinder] registerDefaultShortcuts:@{ defaultsKey: shortcut }];
}

@end
