//
//  SIWindow+Amethyst.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/5/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "SIWindow+Amethyst.h"

#import <objc/runtime.h>

static void *SIWindowFloatingKey = &SIWindowFloatingKey;

@implementation SIWindow (Amethyst)

- (BOOL)shouldBeManaged {
    NSString *subrole = [self stringForKey:kAXSubroleAttribute];

    if (!subrole) return YES;
    if ([subrole isEqualToString:(__bridge NSString *)kAXStandardWindowSubrole]) return YES;

    return NO;
}

- (BOOL)floating {
    return [objc_getAssociatedObject(self, SIWindowFloatingKey) boolValue];
}

- (void)setFloating:(BOOL)floating {
    objc_setAssociatedObject(self, SIWindowFloatingKey, @(floating), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
