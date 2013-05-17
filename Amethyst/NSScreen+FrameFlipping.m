//
//  NSScreen+FrameFlipping.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "NSScreen+FrameFlipping.h"

@implementation NSScreen (FrameFlipping)

- (CGRect)flippedFrameRelativeToFrame:(CGRect)mainFrame {
    CGRect frame = NSRectToCGRect([self frame]);
    frame.origin.y = -frame.origin.y + (mainFrame.size.height - frame.size.height);
    return frame;
}

- (CGRect)flippedFrame {
    return [self flippedFrameRelativeToFrame:NSRectToCGRect([[NSScreen mainScreen] frame])];
}

@end
