//
//  AMSystemWideElement.h
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

// Wrapper around the system-wide element.
@interface AMSystemWideElement : AMAccessibilityElement

// Returns a globally shared reference to the system-wide accessibility element.
+ (AMSystemWideElement *)systemWideElement;

@end
