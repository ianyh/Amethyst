//
//  AMScreenManager.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMScreenManager.h"

#import "AMLayout.h"
#import "AMFullscreenLayout.h"
#import "AMTallLayout.h"
#import "AMWindowManager.h"

@interface AMScreenManager ()
@property (nonatomic, strong) NSScreen *screen;

@property (nonatomic, assign) BOOL needsReflow;
@property (nonatomic, strong) NSArray *layouts;
@property (nonatomic, assign) NSUInteger currentLayoutIndex;
@end

@implementation AMScreenManager

#pragma mark Lifecycle

- (id)init { return nil; }

- (id)initWithScreen:(NSScreen *)screen delegate:(id<AMScreenManagerDelegate>)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;

        self.screen = screen;
        self.layouts = @[
                         [[AMTallLayout alloc] init],
                         [[AMFullscreenLayout alloc] init],
                         ];
        self.currentLayoutIndex = 0;
    }
    return self;
}

- (void)setNeedsReflow {
    self.needsReflow = YES;
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self reflow];
    });
}

- (void)reflow {
    if (!self.needsReflow) return;

    self.needsReflow = NO;

    [self.layouts[self.currentLayoutIndex] reflowScreen:self.screen withWindows:[self.delegate activeWindowsForScreenManager:self]];
}

- (void)cycleLayout {
    self.currentLayoutIndex = (self.currentLayoutIndex + 1) % [self.layouts count];
    [self setNeedsReflow];
}

- (void)shrinkMainPane {
    [self.layouts[self.currentLayoutIndex] shrinkMainPane];
    [self setNeedsReflow];
}

- (void)expandMainPane {
    [self.layouts[self.currentLayoutIndex] expandMainPane];
    [self setNeedsReflow];
}

@end
