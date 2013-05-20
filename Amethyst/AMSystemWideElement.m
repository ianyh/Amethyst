//
//  AMSystemWideElement.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMSystemWideElement.h"

static AMSystemWideElement *sharedElement = nil;

@implementation AMSystemWideElement

+ (AMSystemWideElement *)systemWideElement {
    @synchronized ([AMSystemWideElement class]) {
        if (!sharedElement) {
            AXUIElementRef elementRef = AXUIElementCreateSystemWide();
            sharedElement = [[AMSystemWideElement alloc] initWithAXElementRef:elementRef];
            CFRelease(elementRef);
        }
        return sharedElement;
    }
}

@end
