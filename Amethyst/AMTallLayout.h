//
//  AMTallLayout.h
//  Amethyst
//
//  Created by Ian on 5/17/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMLayout.h"

@interface AMTallLayout : AMLayout
// The number of windows that should be displayed in the main pane.
// Will never be below 1.
@property (nonatomic, assign) NSInteger mainPaneCount;
@end
