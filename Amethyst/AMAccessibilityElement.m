//
//  AMAccessibilityElement.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMAccessibilityElement.h"

@interface AMAccessibilityElement ()
@property (nonatomic, assign) AXUIElementRef axElementRef;
@end

@implementation AMAccessibilityElement

#pragma mark Lifecycle

- (id)init { return nil; }

- (id)initWithAXElementRef:(AXUIElementRef)axElementRef {
    self = [super init];
    if (self) {
        self.axElementRef = CFRetain(axElementRef);
    }
    return self;
}

- (void)dealloc {
    CFRelease(_axElementRef);
}

#pragma mark NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <Title: %@> <pid: %d>", [super description], [self stringForKey:kAXTitleAttribute], [self processIdentifier]];
}

- (BOOL)isEqual:(id)object {
    if (!object)
        return NO;

    if (![object isKindOfClass:[self class]])
        return NO;

    AMAccessibilityElement *otherElement = object;
    if (CFEqual(self.axElementRef, otherElement.axElementRef))
        return YES;

    return NO;
}

- (NSUInteger)hash {
    return CFHash(self.axElementRef);
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithAXElementRef:self.axElementRef];
}

#pragma mark Public Accessors

- (NSString *)stringForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

    if (error != kAXErrorSuccess || !valueRef) return nil;
    if (CFGetTypeID(valueRef) != CFStringGetTypeID()) return nil;

    return CFBridgingRelease(valueRef);
}

- (NSNumber *)numberForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

    if (error != kAXErrorSuccess || !valueRef) return nil;
    if (CFGetTypeID(valueRef) != CFNumberGetTypeID() && CFGetTypeID(valueRef) != CFBooleanGetTypeID()) return nil;
    
    return CFBridgingRelease(valueRef);
}

- (NSArray *)arrayForKey:(CFStringRef)accessibilityValueKey {
    CFArrayRef arrayRef;
    AXError error;

    error = AXUIElementCopyAttributeValues(self.axElementRef, accessibilityValueKey, 0, 100, &arrayRef);

    if (error != kAXErrorSuccess || !arrayRef) return nil;

    return CFBridgingRelease(arrayRef);
}

- (AMAccessibilityElement *)elementForKey:(CFStringRef)accessibilityValueKey {
    CFTypeRef valueRef;
    AXError error;

    error = AXUIElementCopyAttributeValue(self.axElementRef, accessibilityValueKey, &valueRef);

    if (error != kAXErrorSuccess || !valueRef) return nil;
    if (CFGetTypeID(valueRef) != AXUIElementGetTypeID()) return nil;

    AMAccessibilityElement *element = [[AMAccessibilityElement alloc] initWithAXElementRef:(AXUIElementRef)valueRef];

    CFRelease(valueRef);

    return element;
}

- (CGRect)frame {
    CFTypeRef pointRef;
    CFTypeRef sizeRef;
    AXError error;
    
    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXPositionAttribute, &pointRef);
    if (error != kAXErrorSuccess || !pointRef) return CGRectNull;
    
    error = AXUIElementCopyAttributeValue(self.axElementRef, kAXSizeAttribute, &sizeRef);
    if (error != kAXErrorSuccess || !sizeRef) return CGRectNull;
    
    CGPoint point;
    CGSize size;
    bool success;
    
    success = AXValueGetValue(pointRef, kAXValueCGPointType, &point);
    if (!success) return CGRectNull;
    
    success = AXValueGetValue(sizeRef, kAXValueCGSizeType, &size);
    if (!success) return CGRectNull;
    
    CGRect frame = { .origin.x = point.x, .origin.y = point.y, .size.width = size.width, .size.height = size.height };
    
    return frame;
}

- (void)setFrame:(CGRect)frame {
    CGRect currentFrame = self.frame;
    if (CGPointEqualToPoint(currentFrame.origin, frame.origin)) {
        if (abs(currentFrame.size.width - frame.size.width) < 5) {
            if (abs(currentFrame.size.height - frame.size.height) < 5) {
                return;
            }
        }
    }
    
    // For some reason the accessibility frameworks seem to have issues with changing size in different directions.
    // e.g., increasing width while decreasing height doesn't seem to work correctly.
    // Therefore we collapse the window to zero and then expand out to meet the new frame.
    // This means that the first operation is always a contraction, and the second operation is always an expansion.
    [self setPosition:CGPointZero];
    [self setSize:CGSizeZero];
    [self setPosition:frame.origin];
    [self setSize:frame.size];
}

- (void)setPosition:(CGPoint)position {
    AXValueRef positionRef = AXValueCreate(kAXValueCGPointType, &position);
    AXError error;
    
    if (!CGPointEqualToPoint(position, [self frame].origin)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXPositionAttribute, positionRef);
        if (error != kAXErrorSuccess) {
            NSLog(@"Position Error: %d", error);
            return;
        }
    }
}

- (void)setSize:(CGSize)size {
    AXValueRef sizeRef = AXValueCreate(kAXValueCGSizeType, &size);
    AXError error;
    
    if (!CGSizeEqualToSize(size, [self frame].size)) {
        error = AXUIElementSetAttributeValue(self.axElementRef, kAXSizeAttribute, sizeRef);
        if (error != kAXErrorSuccess) {
            NSLog(@"Size Error: %d", error);
            return;
        }
    }
}

- (pid_t)processIdentifier {
    pid_t processIdentifier;
    AXError error;
    
    error = AXUIElementGetPid(self.axElementRef, &processIdentifier);
    
    if (error != kAXErrorSuccess) return -1;
    
    return processIdentifier;
}

@end
