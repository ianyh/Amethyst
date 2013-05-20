//
//  AMScreenManager.h
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AMLayout;
@class AMScreenManager;

typedef void (^AMScreenManagerLayoutUpdater)(AMLayout *);

@protocol AMScreenManagerDelegate <NSObject>
- (NSArray *)activeWindowsForScreenManager:(AMScreenManager *)screenManager;
@end

@interface AMScreenManager : NSObject
@property (nonatomic, strong, readonly) NSScreen *screen;
@property (nonatomic, assign) id<AMScreenManagerDelegate> delegate;

- (id)init DEPRECATED_ATTRIBUTE;
- (id)initWithScreen:(NSScreen *)screen delegate:(id<AMScreenManagerDelegate>)delegate;

- (void)setNeedsReflow;

- (void)updateCurrentLayout:(AMScreenManagerLayoutUpdater)updater;
- (void)cycleLayout;

@end
