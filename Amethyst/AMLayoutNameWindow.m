//
//  AMLayoutNameWindow.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 10/20/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMLayoutNameWindow.h"

@interface AMLayoutNameWindow ()
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

@end
