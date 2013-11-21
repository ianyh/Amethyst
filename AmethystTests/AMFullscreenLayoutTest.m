//
//  AMFullscreenLayoutTest.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/8/13.
//  Copyright 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMFullscreenLayout.h"

#import "NSScreen+Silica.h"

#import <Kiwi/Kiwi.h>
#import <OCMock/OCMock.h>

SPEC_BEGIN(AMFullscreenLayoutTest)

describe(@"Fullscreen Layout Algorithm", ^{
    it(@"should always make all windows fullscreen", ^{
        id window1 = [OCMockObject niceMockForClass:[SIWindow class]];
        id window2 = [OCMockObject niceMockForClass:[SIWindow class]];
        id screen = [OCMockObject niceMockForClass:[NSScreen class]];

        CGRect screenFrame = { .origin.x = 0, .origin.y = 0, .size.width = 500, .size.height = 500 };

        [[[screen stub] andReturnValue:OCMOCK_VALUE(screenFrame)] frameWithoutDockOrMenu];

        [[window1 expect] setFrame:screenFrame];
        [[window2 expect] setFrame:screenFrame];

        AMFullscreenLayout *layout = [[AMFullscreenLayout alloc] init];
        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];

        [window1 verify];
        [window2 verify];
    });
});

SPEC_END
