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

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    // noop
    return [[NSOperation alloc] init];
}

@end
