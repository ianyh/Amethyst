//
//  NSRunningApplication+Manageable.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/24/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSRunningApplication (Manageable)

// Returns YES is the application's windows can be managed by Amethyst, and NO
// otherwise.
- (BOOL)isManageable;

@end
