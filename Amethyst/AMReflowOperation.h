//
//  AMReflowOperation.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 11/7/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AMFrameAssignment : NSObject
- (instancetype)initWithFrame:(CGRect)finalFrame window:(SIWindow *)window focused:(BOOL)focused screenFrame:(CGRect)screenFrame;
@end

@interface AMReflowOperation : NSOperation

- (instancetype)initWithScreen:(NSScreen *)screen windows:(NSArray *)windows;

@property (nonatomic, strong, readonly) NSScreen *screen;
@property (nonatomic, strong, readonly) NSArray *windows;
@property (nonatomic, copy) NSDictionary *activeIDCache;

// Returns the desired frame for the current layout based on the user's
// configuration.
//
// screen - The screen from which the proper frame is desired.
- (CGRect)adjustedFrameForLayout:(NSScreen *)screen;

// Takes instances of AMFrameAssignment and performs the frame assignment.
- (void)performFrameAssignments:(NSArray *)frameAssignments;

@end
