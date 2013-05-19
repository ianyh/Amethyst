//
//  NSEvent+Identifier.h
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSEvent (Identifier)

+ (NSString *)hotKeyIdentifierWithCharacters:(NSString *)characters modifiers:(NSUInteger)modifiers;
- (NSString *)hotKeyIdentifier;

@end
