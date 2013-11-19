//
//  AMLayoutNameWindow.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/20/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMLayoutNameWindow.h"

#import <QuartzCore/QuartzCore.h>

@interface AMLayoutNameWindow ()
@property (nonatomic, weak) IBOutlet NSView *containerView;
@property (nonatomic, weak) IBOutlet NSTextField *layoutNameField;
@end

@implementation AMLayoutNameWindow

- (void)awakeFromNib {
    [super awakeFromNib];

    [self setOpaque:NO];
    [self setIgnoresMouseEvents:YES];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setLevel:NSFloatingWindowLevel];
}

- (void)setContentView:(NSView *)aView {
    aView.wantsLayer = YES;
    aView.layer.frame = aView.frame;
    aView.layer.cornerRadius = 20.0;
    aView.layer.masksToBounds = YES;
    aView.layer.backgroundColor = [[NSColor blackColor] colorWithAlphaComponent:0.75].CGColor;

    [super setContentView:aView];
}

@end
