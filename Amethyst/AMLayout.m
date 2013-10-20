//
//  AMLayout.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMLayout.h"
#import "AMConfiguration.h"

@implementation AMLayout

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    @throw [NSException exceptionWithName:NSGenericException reason:@"Method should be implemented by subclasses." userInfo:nil];
}

- (void)shrinkMainPane {}
- (void)expandMainPane {}

- (void)increaseMainPaneCount {}
- (void)decreaseMainPaneCount {}

- (CGRect)adjustedFrameForLayout:(NSScreen *)screen {
  return [[AMConfiguration sharedConfiguration] ignoreMenuBar] ? screen.frameWithDockAndMenu : screen.frameWithoutDockOrMenu;
}

@end
