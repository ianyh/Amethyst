//
//  NSScreen+Amethyst.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/29/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSScreen (Amethyst)

- (NSString *)am_screenIdentifier;
- (BOOL)am_isFullscreen;

@end
