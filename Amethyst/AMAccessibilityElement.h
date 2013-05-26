//
//  AMAccessibilityElement.h
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Foundation/Foundation.h>

// Objective-C wrapper around a C-level accessibility object.
@interface AMAccessibilityElement : NSObject <NSCopying>
@property (nonatomic, assign, readonly) AXUIElementRef axElementRef;

// Default init method deprecated for compile-time checking of using the correct
// initializer.
- (id)init DEPRECATED_ATTRIBUTE;

// Initializes the receiver as a wrapper around the supplied accessibility
// reference. This is the designated initializer of this class.
//
// axElementRef - A C-level AXUIElementRef object that the receiver is meant to
//                be a wrapper around.
//
// Should always return a valid object unless something particularly horrible
// happens.
- (id)initWithAXElementRef:(AXUIElementRef)axElementRef;

// Returns YES if the accessibility element's size can be modified and NO
// otherwise.
- (BOOL)isResizable;

// Returns YES if the accessibility element's position can be modified and NO
// otherwise.
- (BOOL)isMovable;

// Returns the string value of the attribute for the given key.
//
// accessibilityValueKey - The key of the attribute to be accessed.
//
// Returns the string value of the attribute if the attribute exists and is a
// string. Returns nil otherwise.
- (NSString *)stringForKey:(CFStringRef)accessibilityValueKey;

// Returns the number value of the attribute for the given key.
//
// accessibilityValueKey - The key of the attribute to be accessed.
//
// Returns the number value of the attribute if the attribute exists and is a
// number or boolean. Returns nil otherwise.
- (NSNumber *)numberForKey:(CFStringRef)accessibilityValueKey;

// Returns the array value of the attribute for the given key.
//
// accessibilityValueKey - The key of the attribute to be accessed.
//
// Returns the array value of the attribute if the attribute exists and is an
// array. Returns nil otherwise.
- (NSArray *)arrayForKey:(CFStringRef)accessibilityValueKey;

// Returns the accessibility element for the given key.
//
// accessibilityValueKey - The key of the attribute to be accessed.
//
// Returns the accessibility element for the attribute if the attribute exists
// and is an accessibility element. Returns nil otherwise.
- (AMAccessibilityElement *)elementForKey:(CFStringRef)accessibilityValueKey;

// Returns the frame of the accessibility element if it exists. Returns
// CGRectNull otherwise.
- (CGRect)frame;

// Updates the frame of the accessibility element.
//
// frame - The frame in adjusted screen coordinates to set the accessibility
//         element to.
//
// Updates the frame of the accessibility element to match the input frame as
// closely as possible given known parameters.
//
// If the frame is smaller than the most up to date minimum size the frame is
// expanded to meet the minimum size.
//
// The frame's size may be ignored if the size is not appreciably different from
// the current size.
- (void)setFrame:(CGRect)frame;

// Updates the position of the accessibility element.
//
// position - The point in adjusted screen coordinates to move the accessibility
//            element to.
- (void)setPosition:(CGPoint)position;

// Updates the size of the accessibility element.
//
// size - The size to change the accessibility element to.
//
// There are cases in which this method may fail. Accessibility seems to fail
// under a variety of conditions (e.g., increasing height while decreasing
// width). Callers should generally avoid calling this method and call setFrame:
// instead.
- (void)setSize:(CGSize)size;

// Returns the pid of the process that owns the accessibility element.
- (pid_t)processIdentifier;
@end
