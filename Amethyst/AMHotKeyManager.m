//
//  AMHotKeyManager.m
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMHotKeyManager.h"

#import "NSEvent+Identifier.h"

@interface AMHotKeyManager ()
@property (nonatomic, strong) id eventMonitor;
@property (nonatomic, strong) NSMutableDictionary *hotKeyHandlers;
@end

@implementation AMHotKeyManager

#pragma mark Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.hotKeyHandlers = [NSMutableDictionary dictionary];
        [self installEventHandler];
    }
    return self;
}

- (void)dealloc {
    [NSEvent removeMonitor:_eventMonitor];
}

#pragma mark Event Handling

- (void)installEventHandler {
    if (self.eventMonitor) return;

    self.eventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event) {
        AMHotKeyHandler handler = self.hotKeyHandlers[[event hotKeyIdentifier]];
        if (handler) {
            handler();
        }
    }];
}

#pragma mark Hot Key Management

- (void)registerHotKeyWithKey:(NSString *)key modifiers:(NSUInteger)modifiers handler:(AMHotKeyHandler)handler {
    NSString *hotKeyIdentifier = [NSEvent hotKeyIdentifierWithCharacters:key modifiers:modifiers];

    self.hotKeyHandlers[hotKeyIdentifier] = [handler copy];
}

- (void)unregisterHotKeyWithKey:(NSString *)key modifiers:(NSUInteger)modifiers {
    NSString *hotKeyIdentifier = [NSEvent hotKeyIdentifierWithCharacters:key modifiers:modifiers];

    self.hotKeyHandlers[hotKeyIdentifier] = nil;
}

@end

