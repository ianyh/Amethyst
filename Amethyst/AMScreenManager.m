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
#import "AMLayoutNameWindow.h"
#import "AMWindowManager.h"

@interface AMScreenManager ()
@property (nonatomic, strong) NSScreen *screen;

@property (nonatomic, strong) NSTimer *reflowTimer;

@property (nonatomic, copy) NSArray *layouts;
@property (nonatomic, strong) NSMutableDictionary *currentLayoutIndexBySpaceIdentifier;
@property (nonatomic, strong) NSMutableDictionary *layoutsBySpaceIdentifier;
@property (nonatomic, assign) NSUInteger currentLayoutIndex;
- (AMLayout *)currentLayout;

@property (nonatomic, strong) AMLayoutNameWindow *layoutNameWindow;
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
        self.layoutsBySpaceIdentifier = [NSMutableDictionary dictionary];
        self.currentLayoutIndex = 0;

        NSNib *nib = [[NSNib alloc] initWithNibNamed:@"AMLayoutNameWindow" bundle:nil];
        NSArray *objects;

        [nib instantiateWithOwner:nil topLevelObjects:&objects];

        for (id object in objects) {
            if ([object isKindOfClass:AMLayoutNameWindow.class]) {
                self.layoutNameWindow = object;
            }
        }

        @weakify(self);
        [RACObserve(self, currentLayoutIndex) subscribeNext:^(NSNumber *currentLayoutIndex) {
            @strongify(self);

            [self displayLayoutHUD];
        }];
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
        if (self.layoutsBySpaceIdentifier[_currentSpaceIdentifier]) {
            self.layouts = self.layoutsBySpaceIdentifier[_currentSpaceIdentifier];
        } else {
            NSMutableArray *layouts = [NSMutableArray array];
            for (Class layoutClass in [[AMConfiguration sharedConfiguration] layouts]) {
                [layouts addObject:[[layoutClass alloc] init]];
            }
            self.layouts = layouts;
            self.layoutsBySpaceIdentifier[_currentSpaceIdentifier] = layouts;
        }
    }
}

- (void)displayLayoutHUD {
    CGRect screenFrame = self.screen.frame;
    CGPoint screenCenter = (CGPoint){
        .x = CGRectGetMidX(screenFrame),
        .y = CGRectGetMidY(screenFrame)
    };
    CGPoint windowOrigin = (CGPoint){
        .x = screenCenter.x - self.layoutNameWindow.frame.size.width / 2.0,
        .y = screenCenter.y - self.layoutNameWindow.frame.size.height / 2.0,
    };

    self.layoutNameWindow.layoutNameField.stringValue = [self.currentLayout.class layoutName];
    [self.layoutNameWindow setFrameOrigin:NSPointFromCGPoint(windowOrigin)];
    [self.layoutNameWindow makeKeyAndOrderFront:NSApp];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@checkselector(self, hideLayoutHUD:) object:nil];
    [self performSelector:@checkselector(self, hideLayoutHUD:) withObject:nil afterDelay:0.6];
}

- (void)hideLayoutHUD:(id)sender {
    [self.layoutNameWindow close];
}

- (void)setNeedsReflow {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@checkselector(self, reflow:) object:nil];
    [self performSelector:@checkselector(self, reflow:) withObject:nil afterDelay:0.2];
}

- (void)reflow:(NSTimer *)timer {
    if (!self.currentSpaceIdentifier) return;
    if (self.currentLayoutIndex >= self.layouts.count) return;
    if (![AMConfiguration sharedConfiguration].tilingEnabled) return;

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

- (void)selectLayout:(Class)layoutClass {
    NSInteger layoutIndex = [self.layouts indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
        return [obj isKindOfClass:layoutClass];
    }];
    if (layoutIndex == NSNotFound) return;

    self.currentLayoutIndex = layoutIndex;
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
