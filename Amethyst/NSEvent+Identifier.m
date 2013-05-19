//
//  NSEvent+Identifier.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "NSEvent+Identifier.h"

@implementation NSEvent (Identifier)

+ (NSString *)hotKeyIdentifierWithCharacters:(NSString *)characters modifiers:(NSUInteger)modifiers {
    return [NSString stringWithFormat:@"%@%lu", characters, (unsigned long)modifiers];
}

- (NSString *)hotKeyIdentifier {
    return [NSEvent hotKeyIdentifierWithCharacters:[self charactersIgnoringModifiers] modifiers:[self modifierFlags]];
}

@end
