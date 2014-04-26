//
//  AMFloatingLayout.m
//  Amethyst
//

#import "AMFloatingLayout.h"

#import "AMWindowManager.h"

@implementation AMFloatingLayout

+ (NSString *)layoutName {
    return @"Floating";
}

- (void)reflowScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    // noop
}

@end
