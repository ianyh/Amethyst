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

@property (nonatomic, strong) NSTimer *reflowTimer;

@property (nonatomic, strong) NSArray *layouts;
@property (nonatomic, assign) NSUInteger currentLayoutIndex;
- (AMLayout *)currentLayout;
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
    [self.reflowTimer invalidate];
    self.reflowTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@checkselector0(self, reflow) userInfo:nil repeats:NO];
}

- (void)reflow {
    [self.reflowTimer invalidate];
    self.reflowTimer = nil;

    [self.layouts[self.currentLayoutIndex] reflowScreen:self.screen withWindows:[self.delegate activeWindowsForScreenManager:self]];
}

- (void)updateCurrentLayout:(AMScreenManagerLayoutUpdater)updater {
    updater([self currentLayout]);
    [self setNeedsReflow];
}

- (AMLayout *)currentLayout {
    return self.layouts[self.currentLayoutIndex];
}

- (void)cycleLayout {
    self.currentLayoutIndex = (self.currentLayoutIndex + 1) % [self.layouts count];
    [self setNeedsReflow];
}

- (void)shrinkMainPane {
    [[self currentLayout] shrinkMainPane];
    [self setNeedsReflow];
}

- (void)expandMainPane {
    [[self currentLayout] expandMainPane];
    [self setNeedsReflow];
}

@end
