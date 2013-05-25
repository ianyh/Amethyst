//
//  AMHotKeyManager.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMHotKeyManager.h"

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
@property (nonatomic, assign) EventHandlerRef eventHandlerRef;

@property (nonatomic, strong) NSMutableArray *hotKeys;
@end

@implementation AMHotKeyManager

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.hotKeys = [NSMutableArray array];

        [self installEventHandler];
    }
    return self;
}

- (void)dealloc {
    for (AMHotKey *hotKey in self.hotKeys) {
        UnregisterEventHotKey(hotKey.hotKeyRef);
    }

    if (_eventHandlerRef) {
        RemoveEventHandler(_eventHandlerRef);
    }
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

#pragma mark Event Handling

OSStatus eventHandlerCallback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID hotKeyIdentifier;
    AMHotKey *hotKey;
    OSStatus error;
    AMHotKeyManager *hotKeyManager = (__bridge AMHotKeyManager *)inUserData;

    error = GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyIdentifier), NULL, &hotKeyIdentifier);

    if (error != noErr) return error;

    hotKey = hotKeyManager.hotKeys[hotKeyIdentifier.id];
    if (hotKey) {
        hotKey.handler();
    }

    return noErr;
}

- (void)installEventHandler {
    EventTypeSpec eventTypeSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyReleased };
    EventHandlerRef eventHandlerRef;
    OSStatus error;

    error = InstallEventHandler(GetApplicationEventTarget(), &eventHandlerCallback, 1, &eventTypeSpec, (__bridge void *)self, &eventHandlerRef);

    if (error != noErr) {
        NSLog(@"Error installing event handler");
        return;
    }

    self.eventHandlerRef = eventHandlerRef;
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

- (void)registerHotKeyWithKeyCode:(UInt16)keyCode modifiers:(NSUInteger)modifiers handler:(AMHotKeyHandler)handler {
    UInt32 carbonModifiers = [self carbonModifiersFromModifiers:modifiers];
    EventHotKeyID eventHotKeyID = { .signature = 'amyt', .id = (UInt32)[self.hotKeys count] };
    EventHotKeyRef hotKeyRef;

    OSStatus error = RegisterEventHotKey(keyCode, carbonModifiers, eventHotKeyID, GetEventDispatcherTarget(), kEventHotKeyNoOptions, &hotKeyRef);

    if (error != noErr) {
        NSLog(@"Error encountered when registering hotkey with keyCode %d and mods %lu: %d", keyCode, (unsigned long)modifiers, error);
        return;
    }

    [self.hotKeys addObject:[[AMHotKey alloc] initWithHotKeyRef:hotKeyRef handler:handler]];
}

@end

