//
//  AMHotKeyManager.h
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^AMHotKeyHandler)(void);
typedef UInt16 AMKeyCode;
typedef NSUInteger AMModifierFlags;

extern AMKeyCode AMKeyCodeInvalid;

@interface AMHotKeyManager : NSObject
+ (AMKeyCode)keyCodeForNumber:(NSNumber *)number;

- (void)registerHotKeyWithKeyCode:(AMKeyCode)keyCode modifiers:(AMModifierFlags)modifiers handler:(AMHotKeyHandler)handler;
@end
