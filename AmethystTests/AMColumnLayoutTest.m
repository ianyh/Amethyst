//
//  AMColumnLayoutTest.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/12/13.
//  Copyright 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMColumnLayout.h"
#import "AMWindow.h"
#import "NSScreen+FrameAdjustment.h"

#import <Kiwi/Kiwi.h>
#import <OCMock/OCMock.h>

SPEC_BEGIN(AMColumnLayoutTest)

describe(@"Column Layout Algorithm", ^{
    it(@"should always make all windows fullscreen", ^{
        id window1 = [OCMockObject niceMockForClass:[AMWindow class]];
        id window2 = [OCMockObject niceMockForClass:[AMWindow class]];
        id window3 = [OCMockObject niceMockForClass:[AMWindow class]];
        id screen = [OCMockObject niceMockForClass:[NSScreen class]];

        CGRect screenFrame = { .origin.x = 0, .origin.y = 0, .size.width = 600, .size.height = 500 };

        [[[screen stub] andReturnValue:OCMOCK_VALUE(screenFrame)] adjustedFrame];
        
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 200, .size.height = 500 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 200, .origin.y = 0, .size.width = 200, .size.height = 500 }];
        [[window3 expect] setFrame:(CGRect){ .origin.x = 400, .origin.y = 0, .size.width = 200, .size.height = 500 }];
        
        AMColumnLayout *layout = [[AMColumnLayout alloc] init];
        [layout reflowScreen:screen withWindows:@[ window1, window2, window3 ]];
        
        [window1 verify];
        [window2 verify];
        [window3 verify];
    });
});

SPEC_END
