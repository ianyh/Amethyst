//
//  AMScreenManager.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMScreenManager.h"

#import "AMConfiguration.h"
#import "AMLayout.h"
#import "AMWindowManager.h"

@interface AMScreenManager ()
@property (nonatomic, strong) NSScreen *screen;

@property (nonatomic, strong) NSTimer *reflowTimer;

@property (nonatomic, copy) NSArray *layouts;
@property (nonatomic, strong) NSMutableDictionary *currentLayoutIndexBySpaceIdentifier;
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

        NSMutableArray *layouts = [NSMutableArray array];
        for (Class layoutClass in [[AMConfiguration sharedConfiguration] layouts]) {
            [layouts addObject:[[layoutClass alloc] init]];
        }
        self.layouts = layouts;
        self.currentLayoutIndexBySpaceIdentifier = [NSMutableDictionary dictionary];
        self.currentLayoutIndex = 0;
    }
    return self;
}

- (void)setCurrentSpaceIdentifier:(NSString *)currentSpaceIdentifier {
    if ([_currentSpaceIdentifier isEqualToString:currentSpaceIdentifier]) return;

    if (_currentSpaceIdentifier) {
        self.currentLayoutIndexBySpaceIdentifier[_currentSpaceIdentifier] = @(self.currentLayoutIndex);
    }

    _currentSpaceIdentifier = currentSpaceIdentifier;

    if (_currentSpaceIdentifier) {
        self.currentLayoutIndex = [self.currentLayoutIndexBySpaceIdentifier[_currentSpaceIdentifier] integerValue];
    }
}

- (void)setNeedsReflow {
    [self.reflowTimer invalidate];
    self.reflowTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@checkselector(self, reflow:)
                                                      userInfo:nil
                                                       repeats:NO];
}

- (void)reflow:(NSTimer *)timer {
    [self.reflowTimer invalidate];
    self.reflowTimer = nil;

    [self.layouts[self.currentLayoutIndex] reflowScreen:self.screen withWindows:[self.delegate activeWindowsForScreenManager:self]];
}

- (void)updateCurrentLayout:(AMScreenManagerLayoutUpdater)updater {
    updater(self.currentLayout);
    [self setNeedsReflow];
}

- (AMLayout *)currentLayout {
    return self.layouts[self.currentLayoutIndex];
}

- (void)cycleLayout {
    self.currentLayoutIndex = (self.currentLayoutIndex + 1) % self.layouts.count;
    [self setNeedsReflow];
}

- (void)shrinkMainPane {
    [self.currentLayout shrinkMainPane];
    [self setNeedsReflow];
}

- (void)expandMainPane {
    [self.currentLayout expandMainPane];
    [self setNeedsReflow];
}

@end
