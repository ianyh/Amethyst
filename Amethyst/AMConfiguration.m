//
//  AMConfiguration.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "AMConfiguration.h"

#import "AMHotKeyManager.h"
#import "AMWideLayout.h"
#import "AMTallLayout.h"
#import "AMFullscreenLayout.h"
#import "AMColumnLayout.h"
#import "AMLayout.h"
#import "AMScreenManager.h"
#import "AMWindowManager.h"

// The layouts key should be a list of string identifying layout algorithms.
static NSString *const AMConfigurationLayoutsKey = @"layouts";

// The key to reference the modifier flags intended to be used for a specific
// command. This key is optionally present. If ommitted the default value is
// used.
//
// Valid strings are defined below. Any other values are an assertion error.
static NSString *const AMConfigurationCommandModKey = @"mod";

// The key to reference the keyboard character intended to be used for a
// specific command. This key is optionally present. If ommitted the default
// value is used.
static NSString *const AMConfigurationCommandKeyKey = @"key";

// Valid strings that can be used in configuration for command modifiers.
static NSString *const AMConfigurationMod1String = @"mod1";
static NSString *const AMConfigurationMod2String = @"mod2";

// Command strings that reference possible window management commands. They are
// optionally present in the configuration file. If any is ommitted the default
// is used.
//
// Note: This technically allows for commands having the same key code and
// flags. The behavior in that case is not well defined. We may want this to
// be an assertion error.
static NSString *const AMConfigurationCommandCycleLayoutKey = @"cycle-layout";
static NSString *const AMConfigurationCommandShrinkMainKey = @"shrink-main";
static NSString *const AMConfigurationCommandExpandMainKey = @"expand-main";
static NSString *const AMConfigurationCommandIncreaseMainKey = @"increase-main";
static NSString *const AMConfigurationCommandDecreaseMainKey = @"decrease-main";
static NSString *const AMConfigurationCommandFocusCCWKey = @"focus-ccw";
static NSString *const AMConfigurationCommandFocusCWKey = @"focus-cw";
static NSString *const AMConfigurationCommandSwapCCWKey = @"swap-ccw";
static NSString *const AMConfigurationCommandSwapCWKey = @"swap-cw";
static NSString *const AMConfigurationCommandSwapMainKey = @"swap-main";
static NSString *const AMConfigurationCommandThrowSpacePrefixKey = @"throw-space";
static NSString *const AMConfigurationCommandFocusScreenPrefixKey = @"focus-screen";
static NSString *const AMConfigurationCommandThrowScreenPrefixKey = @"throw-screen";
static NSString *const AMConfigurationCommandToggleFloatKey = @"toggle-float";

@interface AMConfiguration ()
@property (nonatomic, copy) NSDictionary *configuration;
@property (nonatomic, copy) NSDictionary *defaultConfiguration;

@property (nonatomic, assign) AMModifierFlags modifier1;
@property (nonatomic, assign) AMModifierFlags modifier2;
@end

@implementation AMConfiguration

#pragma mark Lifecycle

+ (AMConfiguration *)sharedConfiguration {
    static AMConfiguration *sharedConfiguration;
    @synchronized (AMConfiguration.class) {
        if (!sharedConfiguration) sharedConfiguration = [[AMConfiguration alloc] init];
        return sharedConfiguration;
    }
}

#pragma mark Configuration Loading

- (AMModifierFlags)modifierFlagsForStrings:(NSArray *)modifierStrings {
    AMModifierFlags flags = 0;
    for (NSString *modifierString in modifierStrings) {
        if ([modifierString isEqualToString:@"option"]) flags = flags | NSAlternateKeyMask;
        else if ([modifierString isEqualToString:@"shift"]) flags = flags | NSShiftKeyMask;
        else if ([modifierString isEqualToString:@"control"]) flags = flags | NSControlKeyMask;
        else if ([modifierString isEqualToString:@"command"]) flags = flags | NSCommandKeyMask;
        else DDLogError(@"Unrecognized modifier string: %@", modifierString);
    }
    return flags;
}

+ (Class)layoutClassForString:(NSString *)layoutString {
    if ([layoutString isEqualToString:@"tall"]) return [AMTallLayout class];
    if ([layoutString isEqualToString:@"wide"]) return [AMWideLayout class];
    if ([layoutString isEqualToString:@"fullscreen"]) return [AMFullscreenLayout class];
    if ([layoutString isEqualToString:@"column"]) return [AMColumnLayout class];
    return nil;
}

- (void)loadConfiguration {
    [self loadConfigurationFile];
}

- (void)loadConfigurationFile {
    NSString *amethystConfigPath = [NSHomeDirectory() stringByAppendingPathComponent:@".amethyst"];
    NSString *defaultAmethystConfigPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"amethyst"];

    NSData *data;
    NSError *error;
    NSDictionary *configuration;

    data = [NSData dataWithContentsOfFile:amethystConfigPath];
    if (data) {
        configuration = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            DDLogError(@"error loading configuration: %@", error);
            return;
        }

        self.configuration = configuration;
    }

    data = [NSData dataWithContentsOfFile:defaultAmethystConfigPath];
    configuration = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        DDLogError(@"error loading default configuration: %@", error);
        return;
    }

    self.defaultConfiguration = configuration;

    self.modifier1 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod1String] ?: self.defaultConfiguration[AMConfigurationMod1String]];
    self.modifier2 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod2String] ?: self.defaultConfiguration[AMConfigurationMod2String]];
}

#pragma mark Hot Key Mapping

- (AMModifierFlags)modifierFlagsForModifierString:(NSString *)modifierString {
    if ([modifierString isEqualToString:@"mod1"]) return self.modifier1;
    if ([modifierString isEqualToString:@"mod2"]) return self.modifier2;

    DDLogError(@"Unknown modifier string: %@", modifierString);

    return self.modifier1;
}

- (void)constructCommandWithHotKeyManager:(AMHotKeyManager *)hotKeyManager commandKey:(NSString *)commandKey handler:(AMHotKeyHandler)handler {
    NSString *commandKeyString = self.configuration[commandKey][AMConfigurationCommandKeyKey] ?: self.defaultConfiguration[commandKey][AMConfigurationCommandKeyKey];
    NSString *commandModifierString = self.configuration[commandKey][AMConfigurationCommandModKey] ?: self.defaultConfiguration[commandKey][AMConfigurationCommandModKey];

    AMModifierFlags commandFlags;
    if ([commandModifierString isEqualToString:@"mod1"]) {
        commandFlags = self.modifier1;
    } else if ([commandModifierString isEqualToString:@"mod2"]) {
        commandFlags = self.modifier2;
    } else {
        DDLogError(@"Unknown modifier string: %@", commandModifierString);
        return;
    }

    [hotKeyManager registerHotKeyWithKeyString:commandKeyString modifiers:commandFlags handler:handler];
}

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandCycleLayoutKey handler:^{
        [windowManager.focusedScreenManager cycleLayout];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandShrinkMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout shrinkMainPane];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandExpandMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout expandMainPane];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandIncreaseMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout increaseMainPaneCount];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandDecreaseMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout decreaseMainPaneCount];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandFocusCCWKey handler:^{
        [windowManager moveFocusCounterClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandFocusCWKey handler:^{
        [windowManager moveFocusClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandSwapCCWKey handler:^{
        [windowManager swapFocusedWindowCounterClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandSwapCWKey handler:^{
        [windowManager swapFocusedWindowClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandSwapMainKey handler:^{
        [windowManager swapFocusedWindowToMain];
    }];

    for (NSUInteger screenNumber = 1; screenNumber <= 3; ++screenNumber) {
        NSString *focusCommandKey = [AMConfigurationCommandFocusScreenPrefixKey stringByAppendingFormat:@"-%d", (unsigned int)screenNumber];
        NSString *throwCommandKey = [AMConfigurationCommandThrowScreenPrefixKey stringByAppendingFormat:@"-%d", (unsigned int)screenNumber];

        [self constructCommandWithHotKeyManager:hotKeyManager commandKey:focusCommandKey handler:^{
            [windowManager focusScreenAtIndex:screenNumber];
        }];

        [self constructCommandWithHotKeyManager:hotKeyManager commandKey:throwCommandKey handler:^{
            [windowManager throwToScreenAtIndex:screenNumber];
        }];
    }

    for (NSUInteger spaceNumber = 1; spaceNumber < 10; ++spaceNumber) {
        NSString *commandKey = [AMConfigurationCommandThrowSpacePrefixKey stringByAppendingFormat:@"-%d", (unsigned int)spaceNumber];

        [self constructCommandWithHotKeyManager:hotKeyManager commandKey:commandKey handler:^{
            [windowManager pushFocusedWindowToSpace:spaceNumber];
        }];
    }

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandToggleFloatKey handler:^{
        [windowManager toggleFloatForFocusedWindow];
    }];
}

- (NSArray *)layouts {
    NSArray *layoutStrings = self.configuration[AMConfigurationLayoutsKey] ?: self.defaultConfiguration[AMConfigurationLayoutsKey];
    NSMutableArray *layouts = [NSMutableArray array];
    for (NSString *layoutString in layoutStrings) {
        Class layoutClass = [self.class layoutClassForString:layoutString];
        if (!layoutClass) {
            DDLogError(@"Unrecognized layout string: %@", layoutString);
            continue;
        }
        
        [layouts addObject:layoutClass];
    }
    return layouts;
}

@end
