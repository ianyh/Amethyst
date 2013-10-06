//
//  AMTallLayoutTest.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/8/13.
//  Copyright 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMTallLayout.h"

#import "NSScreen+FrameAdjustment.h"

#import <Kiwi/Kiwi.h>
#import <OCMock/OCMock.h>

@interface AMTallLayout (AMTallLayoutTest)
@property (nonatomic, assign) CGFloat mainPaneRatio;
@property (nonatomic, assign) NSInteger mainPaneCount;
@end

SPEC_BEGIN(AMTallLayoutTest)

describe(@"Tall Layout Algorithm", ^{
    it(@"Should organize windows according to mainPaneCount", ^{
        AMTallLayout *layout = [[AMTallLayout alloc] init];
        id window1 = [OCMockObject niceMockForClass:[SIWindow class]];
        id window2 = [OCMockObject niceMockForClass:[SIWindow class]];
        id screen = [OCMockObject niceMockForClass:[NSScreen class]];

        CGRect screenFrame = { .origin.x = 0, .origin.y = 0, .size.width = 500, .size.height = 500 };
        [[[screen stub] andReturnValue:OCMOCK_VALUE(screenFrame)] adjustedFrame];
        
        // With one window in the main pane there should be one window on the
        // left and one window on the right.
        layout.mainPaneCount = 1;
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 250, .size.height = 500 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 250, .origin.y = 0, .size.width = 250, .size.height = 500 }];

        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];
        
        [window1 verify];
        [window2 verify];

        // With two windows in the main pane both windows should be on the left.
        layout.mainPaneCount = 2;
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 500, .size.height = 250 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 250, .size.width = 500, .size.height = 250 }];

        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];
        
        [window1 verify];
        [window2 verify];
    });

    it(@"should organize windows according to mainPaneRatio", ^{
        AMTallLayout *layout = [[AMTallLayout alloc] init];
        id window1 = [OCMockObject niceMockForClass:[SIWindow class]];
        id window2 = [OCMockObject niceMockForClass:[SIWindow class]];
        id screen = [OCMockObject niceMockForClass:[NSScreen class]];
        
        CGRect screenFrame = { .origin.x = 0, .origin.y = 0, .size.width = 500, .size.height = 500 };
        [[[screen stub] andReturnValue:OCMOCK_VALUE(screenFrame)] adjustedFrame];
        
        // With a 0.5 mainPaneRatio the horizontal space should be evenly
        // distributed.
        layout.mainPaneRatio = 0.5;
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 250, .size.height = 500 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 250, .origin.y = 0, .size.width = 250, .size.height = 500 }];
        
        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];
        
        [window1 verify];
        [window2 verify];

        // With a 0.75 mainPaneRatio the left window should take up 75% of the
        // horizontal space.
        layout.mainPaneRatio = 0.75;
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 375, .size.height = 500 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 375, .origin.y = 0, .size.width = 125, .size.height = 500 }];
        
        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];
        
        [window1 verify];
        [window2 verify];

        // With a 0.25 mainPaneRatio the left window should take up 25% of the
        // horizontal space.
        layout.mainPaneRatio = 0.25;
        [[window1 expect] setFrame:(CGRect){ .origin.x = 0, .origin.y = 0, .size.width = 125, .size.height = 500 }];
        [[window2 expect] setFrame:(CGRect){ .origin.x = 125, .origin.y = 0, .size.width = 375, .size.height = 500 }];
        
        [layout reflowScreen:screen withWindows:@[ window1, window2 ]];
        
        [window1 verify];
        [window2 verify];
    });
});

SPEC_END
