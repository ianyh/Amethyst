//
//  SIApplication+Amethyst.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/6/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "SIApplication+Amethyst.h"

#import "AMConfiguration.h"

@implementation SIApplication (Amethyst)

- (BOOL)floating {
    NSRunningApplication *runningApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:self.processIdentifier];
    return [[AMConfiguration sharedConfiguration] runningApplicationShouldFloat:runningApplication];
}

@end
