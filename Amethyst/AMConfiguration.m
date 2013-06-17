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

static NSString *const AMConfigurationLayoutsKey = @"layouts";
static NSString *const AMConfigurationMod1Key = @"mod1";
static NSString *const AMConfigurationMod2Key = @"mod2";
static NSString *const AMConfigurationMod3Key = @"mod3";

@interface AMConfiguration ()
@property (nonatomic, copy) NSDictionary *configuration;
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

- (void)loadConfiguration {
    [self loadConfigurationFile];
}

- (void)loadConfigurationFile {
    NSString *amethystConfigPath = [NSHomeDirectory() stringByAppendingPathComponent:@".amethyst"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:amethystConfigPath]) {
        amethystConfigPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"amethyst"];
    }

    NSData *data = [NSData dataWithContentsOfFile:amethystConfigPath];
    NSError *error;

    NSDictionary *configuration = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"error loading configuration: %@", error);
        return;
    }

    self.configuration = configuration;
}

#pragma mark Hot Key Mapping

- (AMModifierFlags)modifierFlagsForStrings:(NSArray *)modifierStrings {
    AMModifierFlags flags = 0;
    for (NSString *modifierString in modifierStrings) {
        if ([modifierString isEqualToString:@"option"]) flags = flags | NSAlternateKeyMask;
        else if ([modifierString isEqualToString:@"shift"]) flags = flags | NSShiftKeyMask;
        else if ([modifierString isEqualToString:@"control"]) flags = flags | NSControlKeyMask;
        else if ([modifierString isEqualToString:@"command"]) flags = flags | NSCommandKeyMask;
        else NSLog(@"Unrecognized modifier string: %@", modifierString);
    }
    return flags;
}

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    AMModifierFlags modifier = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod1Key]];
    AMModifierFlags modifier2 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod2Key]];
    AMModifierFlags modifier3 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod3Key]];;

    [hotKeyManager registerHotKeyWithKeyString:@"space" modifiers:modifier handler:^{
        [windowManager.focusedScreenManager cycleLayout];
    }];

    for (NSUInteger screenNumber = 1; screenNumber <= 3; ++screenNumber) {
        NSString *screenNumberString = [NSString stringWithFormat:@"%d", (unsigned int)screenNumber];
        [hotKeyManager registerHotKeyWithKeyString:screenNumberString modifiers:modifier handler:^{
            [windowManager focusScreenAtIndex:screenNumber];
        }];

        [hotKeyManager registerHotKeyWithKeyString:screenNumberString modifiers:modifier2 handler:^{
            [windowManager throwToScreenAtIndex:screenNumber];
        }];
    }

    [hotKeyManager registerHotKeyWithKeyString:@"h" modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout shrinkMainPane];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"l" modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout expandMainPane];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"," modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout increaseMainPaneCount];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"." modifiers:modifier handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(AMLayout *layout) {
            [layout decreaseMainPaneCount];
        }];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"j" modifiers:modifier handler:^{
        [windowManager moveFocusCounterClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"k" modifiers:modifier handler:^{
        [windowManager moveFocusClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"enter" modifiers:modifier handler:^{
        [windowManager swapFocusedWindowToMain];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"j" modifiers:modifier2 handler:^{
        [windowManager swapFocusedWindowCounterClockwise];
    }];

    [hotKeyManager registerHotKeyWithKeyString:@"k" modifiers:modifier2 handler:^{
        [windowManager swapFocusedWindowClockwise];
    }];

    for (NSUInteger spaceNumber = 1; spaceNumber < 10; ++spaceNumber) {
        NSString *spaceNumberString = [NSString stringWithFormat:@"%d", (unsigned int)spaceNumber];
        [hotKeyManager registerHotKeyWithKeyString:spaceNumberString modifiers:modifier3 handler:^{
            [windowManager pushFocusedWindowToSpace:spaceNumber];
        }];
    }
}

+ (Class)layoutClassForString:(NSString *)layoutString {
    if ([layoutString isEqualToString:@"tall"]) return [AMTallLayout class];
    if ([layoutString isEqualToString:@"wide"]) return [AMWideLayout class];
    if ([layoutString isEqualToString:@"fullscreen"]) return [AMFullscreenLayout class];
    if ([layoutString isEqualToString:@"column"]) return [AMColumnLayout class];
    return nil;
}

- (NSArray *)layouts {
    NSMutableArray *layouts = [NSMutableArray array];
    for (NSString *layoutString in self.configuration[AMConfigurationLayoutsKey]) {
        Class layoutClass = [self.class layoutClassForString:layoutString];
        if (!layoutClass) {
            NSLog(@"Unrecognized layout string: %@", layoutString);
            continue;
        }
        
        [layouts addObject:layoutClass];
    }
    return layouts;
}

@end
