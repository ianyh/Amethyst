//
//  AMWindowManager.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AMWindowManager : NSObject

- (NSArray *)activeWindowsForScreen:(NSScreen *)screen;

@end
