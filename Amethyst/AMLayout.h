//
//  AMLayout.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AMLayout;

@interface AMLayout : NSObject

// Subclasses should override this method to layout windows according to their specified algorithm.
// Subclasses should NOT call super's implementation.
- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows;

- (void)shrinkMainPane;
- (void)expandMainPane;

- (void)increaseMainPaneCount;
- (void)decreaseMainPaneCount;

@end
