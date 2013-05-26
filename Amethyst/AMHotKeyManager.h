//
//  AMHotKeyManager.h
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

// The block type for handling hot keys events.
typedef void (^AMHotKeyHandler)(void);

// Type for defining key code.
typedef UInt16 AMKeyCode;

// Type for defining modifier flags.
typedef NSUInteger AMModifierFlags;

// Specific key code defined to be invalid.
// Can be used to identify if a returned key code is valid or not.
extern AMKeyCode AMKeyCodeInvalid;

@interface AMHotKeyManager : NSObject

// Translates a number into a key code.
//
// number - The number to be translated into a keycode. Expected to be
//          integral.
//
// Returns a key code corresponding to the least significant digit of the
// number. So 10 is translated to the key code for 0, 9 is translated to the key
// code 9, -112 is translated to the key code 2, etc. Returns AMKeyCodeInvalid
// if a valid key code cannot be determined.
+ (AMKeyCode)keyCodeForNumber:(NSNumber *)number;

// Registers a global hot key handler.
//
// keyCode   - The virtual code representing the key on the keyboard for the hot
//             key.
// modifiers - The modifiers mask representing some combination of modifier keys
//             on the keyboard. Masks should be OR'd together.
// handler   - The block to be called when the hot key is released.
//
// Note: handlers are called on key released, not key pressed. Repeats are not
//       recognized, i.e., holding down a hot key will not send multiple calls
//       to the handler.
- (void)registerHotKeyWithKeyCode:(AMKeyCode)keyCode modifiers:(AMModifierFlags)modifiers handler:(AMHotKeyHandler)handler;

@end
