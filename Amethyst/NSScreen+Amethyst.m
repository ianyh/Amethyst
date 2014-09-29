//
//  NSScreen+Amethyst.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/29/14.
//  Copyright (c) 2014 Ian Ynda-Hummel. All rights reserved.
//

#import "NSScreen+Amethyst.h"

@implementation NSScreen (Amethyst)

- (NSString *)am_screenIdentifier {
    CGSManagedDisplay managedDisplay = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, self.frame);
    return (NSString *)CFBridgingRelease(managedDisplay);
}

@end
