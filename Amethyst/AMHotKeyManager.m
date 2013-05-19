//
//  AMHotKeyManager.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMHotKeyManager.h"

#import <Carbon/Carbon.h>

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
@property (nonatomic, strong) NSMutableDictionary *stringToKeyCode;

- (void)constructStringToKeyCodeMap;
@end

@implementation AMHotKeyManager

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.hotKeys = [NSMutableArray array];
        self.stringToKeyCode = [NSMutableDictionary dictionary];

        [self installEventHandler];
        [self constructStringToKeyCodeMap];
    }
    return self;
}

- (void)constructStringToKeyCodeMap {
    TISInputSourceRef inputSourceRef = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
    CFDataRef keyboardLayoutDataRef = TISGetInputSourceProperty(inputSourceRef, kTISPropertyUnicodeKeyLayoutData);
    
    for (UInt16 keyCode = 0; keyCode < 128; ++keyCode) {
        @autoreleasepool {
            UInt32 deadKeyState;
            UniCharCount actualStringLength;
            UniChar unicodeString;
            NSString *keyCodeString;
            
            UCKeyTranslate((UCKeyboardLayout *)CFDataGetBytePtr(keyboardLayoutDataRef),
                           keyCode,
                           kUCKeyActionDisplay,
                           0, // Options
                           LMGetKbdType(),
                           kUCKeyTranslateNoDeadKeysMask,
                           &deadKeyState,
                           4, // Max length
                           &actualStringLength,
                           &unicodeString);
            
            keyCodeString = [NSString stringWithCharacters:&unicodeString length:actualStringLength];
            
            self.stringToKeyCode[keyCodeString] = @( keyCode );
        }
    }
    
    CFRelease(inputSourceRef);
}

- (void)dealloc {
    for (AMHotKey *hotKey in self.hotKeys) {
        UnregisterEventHotKey(hotKey.hotKeyRef);
    }

    if (_eventHandlerRef) {
        RemoveEventHandler(_eventHandlerRef);
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
    EventTypeSpec eventTypeSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
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

- (void)registerHotKeyWithKey:(NSString *)key modifiers:(NSUInteger)modifiers handler:(AMHotKeyHandler)handler {
    UInt16 keyCode = [self.stringToKeyCode[key] unsignedShortValue];
    UInt32 carbonModifiers = [self carbonModifiersFromModifiers:modifiers];
    EventHotKeyID eventHotKeyID = { .signature = 'amyt', .id = (UInt32)[self.hotKeys count] };
    EventHotKeyRef hotKeyRef;

    RegisterEventHotKey(keyCode, carbonModifiers, eventHotKeyID, GetEventDispatcherTarget(), kEventHotKeyNoOptions, &hotKeyRef);

    [self.hotKeys addObject:[[AMHotKey alloc] initWithHotKeyRef:hotKeyRef handler:handler]];
}

@end

