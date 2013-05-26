//
//  NSScreen+FrameAdjustment.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSScreen (FrameAdjustment)

// Returns the frame of the screen relative to the main screen's frame and
// accounting for any presence of a menu bar.
- (CGRect)adjustedFrame;

@end
