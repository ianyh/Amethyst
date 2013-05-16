//
//  AMApplication.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

@interface AMApplication : AMAccessibilityElement

+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication;

@end
