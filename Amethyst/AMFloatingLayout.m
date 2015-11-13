//
//  AMFloatingLayout.m
//  Amethyst
//

#import "AMFloatingLayout.h"

#import "AMWindowManager.h"
#import "AMReflowOperation.h"

@implementation AMFloatingLayout

+ (NSString *)layoutName {
    return @"Floating";
}

- (NSOperation *)reflowOperationForScreen:(NSScreen *)screen withWindows:(NSArray *)windows {
    return [[AMReflowOperation alloc] initWithScreen:screen windows:windows];
}

@end
