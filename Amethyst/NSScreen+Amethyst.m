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
    CGSManagedDisplay managedDisplay = CGSCopyBestManagedDisplayForRect(CGSDefaultConnection, self.frameIncludingDockAndMenu);
    return (NSString *)CFBridgingRelease(managedDisplay);
}

- (BOOL)am_isFullscreen {
    CFArrayRef screenDictionaries = CGSCopyManagedDisplaySpaces(CGSDefaultConnection);
    BOOL isFullscreen = NO;
    for (NSDictionary *screenDictionary in (__bridge NSArray *)screenDictionaries) {
        NSString *screenIdentifier = screenDictionary[@"Display Identifier"];
        if ([screenIdentifier isEqualToString:self.am_screenIdentifier]) {
            CGSSpace currentSpace = [screenDictionary[@"Current Space"][@"id64"] intValue];
            CGSSpaceType currentSpaceType = CGSSpaceGetType(CGSDefaultConnection, currentSpace);

            isFullscreen = (currentSpaceType != kCGSSpaceUser);
            break;
        }
    }
    CFRelease(screenDictionaries);
    return isFullscreen;
}

@end
