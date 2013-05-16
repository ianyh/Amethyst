//
//  AMApplication.m
//  Amethyst
//
//  Created by Ian on 5/16/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMApplication.h"

@interface AMApplication ()
@end

@implementation AMApplication

#pragma mark Lifecycle

+ (instancetype)applicationWithRunningApplication:(NSRunningApplication *)runningApplication {
    AXUIElementRef axElementRef = AXUIElementCreateApplication([runningApplication processIdentifier]);
    AMApplication *application = [[AMApplication alloc] initWithAXElementRef:axElementRef];
    CFRelease(axElementRef);

    return application;
}

@end
