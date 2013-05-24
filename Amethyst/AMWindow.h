//
//  AMWindow.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

@interface AMWindow : AMAccessibilityElement

+ (AMWindow *)focusedWindow;

- (BOOL)shouldBeManaged;
- (BOOL)isHidden;
- (BOOL)isMinimized;
- (BOOL)isResizable;

- (NSScreen *)screen;
- (void)moveToScreen:(NSScreen *)screen;

- (void)moveToSpace:(NSUInteger)space;

- (void)bringToFocus;

@end
