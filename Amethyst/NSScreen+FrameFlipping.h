//
//  NSScreen+FrameFlipping.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSScreen (FrameFlipping)

- (CGRect)flippedFrameRelativeToFrame:(CGRect)mainFrame;
- (CGRect)flippedFrame;

@end
