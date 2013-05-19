//
//  AMHotKeyManager.h
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^AMHotKeyHandler)(void);

@interface AMHotKeyManager : NSObject
- (void)registerHotKeyWithKey:(NSString *)key modifiers:(NSUInteger)modifiers handler:(AMHotKeyHandler)handler;
@end
