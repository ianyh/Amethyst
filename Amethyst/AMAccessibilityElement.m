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

@property (nonatomic, strong) NSString *cachedTitle;
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
    return [NSString stringWithFormat:@"%@ <Title: %@", [super description], [self title]];
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

#pragma mark - Public Accessors

- (NSString *)title {
    if (!self.cachedTitle) {
        CFStringRef titleRef;
        AXUIElementCopyAttributeValue(self.axElementRef, kAXTitleAttribute, (CFTypeRef *)&titleRef);
        if (titleRef) {
            self.cachedTitle = CFBridgingRelease(titleRef);
        } else {
            self.cachedTitle = @"";
        }
    }
    return self.cachedTitle;
}

@end
