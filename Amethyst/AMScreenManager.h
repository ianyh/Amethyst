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

// Block for updating the screen manager's current layout.
//
// layout - The screen's current layout object.
typedef void (^AMScreenManagerLayoutUpdater)(AMLayout *layout);

// Delegate protocol for the screen manager. Used to determine the screen's
// contained windows.
@protocol AMScreenManagerDelegate <NSObject>

// Should return array of SIWindow objects contained on the screen manager's
// screen.
//
// screenManager - The screen manager whose screen contains the returned
//                 windows.
- (NSArray *)activeWindowsForScreenManager:(AMScreenManager *)screenManager;

@end

// Object for managing the layout of windows on a screen.
@interface AMScreenManager : NSObject

// The screen being managed.
//
// This property must never be nil.
@property (nonatomic, strong, readonly) NSScreen *screen;

// Delegate for obtaining windows on a screen.
@property (nonatomic, assign) id<AMScreenManagerDelegate> delegate;

// The identifier of the currently active space.
@property (nonatomic, copy) NSString *currentSpaceIdentifier;

// Default init is deprecated for compile-time checking.
- (id)init DEPRECATED_ATTRIBUTE;

// Initialize the receiver with a screen and a delegate.
//
// screen   - The screen to be managed. Should not be nil.
// delegate - The delegate to be used for obtaining windows. Should not be nil.
- (id)initWithScreen:(NSScreen *)screen delegate:(id<AMScreenManagerDelegate>)delegate;

// Marks the screen as needing reflowing.
//
// Does not immediately reflow. Reflow is delayed such that multiple calls to
// this method do not cause extraneous reflows.
- (void)setNeedsReflow;

// Updates the current layout and then marks the screen as needing reflow.
//
// updater - Block that will be called to update the current layout being used
//           on the screen. Should not be nil.
- (void)updateCurrentLayout:(AMScreenManagerLayoutUpdater)updater;

// Changes the layout to the next layout in the chain.
- (void)cycleLayout;

// Changes the layout to a specific layout
//
// layoutIndex - The index of the desired layout. Should not be nil.
- (void)selectLayout: (NSUInteger) layoutIndex;

@end
