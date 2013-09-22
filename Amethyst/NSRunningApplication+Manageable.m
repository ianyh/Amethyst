//
//  NSRunningApplication+Manageable.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/24/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "NSRunningApplication+Manageable.h"

@interface NSRunningApplication (ManageablePrivate)
- (BOOL)isAgent;
@end

@implementation NSRunningApplication (Manageable)

- (BOOL)isManageable {
    if ([self.bundleIdentifier hasPrefix:@"com.apple.dashboard"]) return NO;
    if ([self.bundleIdentifier hasPrefix:@"com.apple.loginwindow"]) return NO;
    if (self.isAgent) return NO;

    return YES;
}

- (BOOL)isAgent {
    NSURL *bundleInfoPath = [[self.bundleURL URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];
    NSDictionary *applicationBundleInfoDictionary = [NSDictionary dictionaryWithContentsOfURL:bundleInfoPath];
    return [applicationBundleInfoDictionary[@"LSUIElement"] boolValue];
}

@end
