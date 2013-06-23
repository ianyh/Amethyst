//
//  AMConfigurationTest.m
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 6/23/13.
//  Copyright 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMConfiguration.h"
#import "AMConfiguration+Private.h"

#import "AMTallLayout.h"
#import "AMWideLayout.h"

#import <Kiwi/Kiwi.h>
#import <Expecta/Expecta.h>

@interface AMConfiguration ()
@property (nonatomic, copy) NSDictionary *configuration;
@property (nonatomic, copy) NSDictionary *defaultConfiguration;
@end

SPEC_BEGIN(AMConfigurationTest)

describe(@"AMConfiguration Layouts", ^{
    it(@"should take default values if there is no user configuration", ^{
        AMConfiguration *configuration = [[AMConfiguration alloc] init];
        configuration.configuration = nil;
        configuration.defaultConfiguration = @{ @"layouts": @[ @"tall" ] };

        EXP_expect(configuration.layouts).to.equal(@[ AMTallLayout.class ]);
    });

    it(@"should take default value is user configuration doesn't specify", ^{
        AMConfiguration *configuration = [[AMConfiguration alloc] init];
        configuration.configuration = @{ @"foo": @"bar" };
        configuration.defaultConfiguration = @{ @"layouts": @[ @"tall" ] };

        EXP_expect(configuration.layouts).to.equal(@[ AMTallLayout.class ]);
    });

    it(@"should take user value over default", ^{
        AMConfiguration *configuration = [[AMConfiguration alloc] init];
        configuration.configuration = @{ @"layouts": @[ @"wide" ] };
        configuration.defaultConfiguration = @{ @"layouts": @[ @"tall" ] };

        EXP_expect(configuration.layouts).to.equal(@[ AMWideLayout.class ]);
    });
});

SPEC_END
