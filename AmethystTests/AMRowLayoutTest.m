//
//  AMColumnLayoutTest.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/12/13.
//  Copyright 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMRowLayout.h"

#import "NSScreen+Silica.h"

#import <Kiwi/Kiwi.h>
#import <OCMock/OCMock.h>

SPEC_BEGIN(AMRowLayoutTest)

describe(@"Row Layout Algorithm", ^{
    it(@"should always make all windows full width and with a height that's equal to the screen height divided by the number of windows", ^{
        id window1 = [OCMockObject niceMockForClass:[SIWindow class]];
        id window2 = [OCMockObject niceMockForClass:[SIWindow class]];
        id window3 = [OCMockObject niceMockForClass:[SIWindow class]];
        id screen = [OCMockObject niceMockForClass:[NSScreen class]];
        
        CGRect screenFrame = { .origin.x = 0, .origin.y = 0, .size.width = 300, .size.height = 600 };
        
        [[[screen stub] andReturnValue:OCMOCK_VALUE(screenFrame)] frameWithoutDockOrMenu];
        
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 300, .size.height = 200 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 200, .size.width = 300, .size.height = 200 }];
        [[window3 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 400, .size.width = 300, .size.height = 200 }];
        
        AMRowLayout *layout = [[AMRowLayout alloc] init];
        [layout reflowScreen:screen withWindows:@[ window1, window2, window3 ]];
        
        [window1 verify];
        [window2 verify];
        [window3 verify];
    });
});

SPEC_END