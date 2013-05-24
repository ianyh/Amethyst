//
//  AMAccessibilityElement.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AMAccessibilityElement : NSObject <NSCopying>
@property (nonatomic, assign, readonly) AXUIElementRef axElementRef;

- (id)init DEPRECATED_ATTRIBUTE;
- (id)initWithAXElementRef:(AXUIElementRef)axElementRef;

- (NSString *)stringForKey:(CFStringRef)accessibilityValueKey;
- (NSNumber *)numberForKey:(CFStringRef)accessibilityValueKey;
- (NSArray *)arrayForKey:(CFStringRef)accessibilityValueKey;
- (pid_t)processIdentifier;
@end
