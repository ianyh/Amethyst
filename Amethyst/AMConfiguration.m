//
//  AMConfiguration.m
//  Amethyst
//
//  Created by Ian on 5/19/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import "Amethyst-Swift.h"

#import "AMConfiguration.h"

#import "AMHotKeyManager.h"
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

static NSString *const AMConfigurationScreens = @"screens";

static NSString *const AMConfigurationWindowMargins = @"window-margins";
static NSString *const AMConfigurationWindowMarginSize = @"window-margin-size";

// Command strings that reference possible window management commands. They are
// optionally present in the configuration file. If any is ommitted the default
// is used.
//
// Note: This technically allows for commands having the same key code and
// flags. The behavior in that case is not well defined. We may want this to
// be an assertion error.
static NSString *const AMConfigurationCommandCycleLayoutForwardKey = @"cycle-layout";
static NSString *const AMConfigurationCommandCycleLayoutBackwardKey = @"cycle-layout-backward";
static NSString *const AMConfigurationCommandShrinkMainKey = @"shrink-main";
static NSString *const AMConfigurationCommandExpandMainKey = @"expand-main";
static NSString *const AMConfigurationCommandIncreaseMainKey = @"increase-main";
static NSString *const AMConfigurationCommandDecreaseMainKey = @"decrease-main";
static NSString *const AMConfigurationCommandFocusCCWKey = @"focus-ccw";
static NSString *const AMConfigurationCommandFocusCWKey = @"focus-cw";
static NSString *const AMConfigurationCommandSwapScreenCCWKey = @"swap-screen-ccw";
static NSString *const AMConfigurationCommandSwapScreenCWKey = @"swap-screen-cw";
static NSString *const AMConfigurationCommandSwapCCWKey = @"swap-ccw";
static NSString *const AMConfigurationCommandSwapCWKey = @"swap-cw";
static NSString *const AMConfigurationCommandSwapMainKey = @"swap-main";
static NSString *const AMConfigurationCommandThrowSpacePrefixKey = @"throw-space";
static NSString *const AMConfigurationCommandThrowSpaceLeftKey = @"throw-space-left";
static NSString *const AMConfigurationCommandThrowSpaceRightKey = @"throw-space-right";
static NSString *const AMConfigurationCommandFocusScreenPrefixKey = @"focus-screen";
static NSString *const AMConfigurationCommandThrowScreenPrefixKey = @"throw-screen";
static NSString *const AMConfigurationCommandToggleFloatKey = @"toggle-float";
static NSString *const AMConfigurationCommandDisplayCurrentLayoutKey = @"display-current-layout";
static NSString *const AMConfigurationCommandToggleTilingKey = @"toggle-tiling";

// Key to reference an array of application bundle identifiers whose windows
// should always be floating by default.
static NSString *const AMConfigurationFloatingBundleIdentifiers = @"floating";
static NSString *const AMConfigurationIgnoreMenuBar = @"ignore-menu-bar";
static NSString *const AMConfigurationFloatSmallWindows = @"float-small-windows";
static NSString *const AMConfigurationMouseFollowsFocus = @"mouse-follows-focus";
static NSString *const AMConfigurationFocusFollowsMouse = @"focus-follows-mouse";
static NSString *const AMConfigurationEnablesLayoutHUD = @"enables-layout-hud";
static NSString *const AMConfigurationEnablesLayoutHUDOnSpaceChange = @"enables-layout-hud-on-space-change";
static NSString *const AMConfigurationUseCanaryBuild = @"use-canary-build";


@interface AMConfiguration ()
@property (nonatomic, copy) NSDictionary *configuration;
@property (nonatomic, copy) NSDictionary *defaultConfiguration;

@property (nonatomic, assign) AMModifierFlags modifier1;
@property (nonatomic, assign) AMModifierFlags modifier2;
@property (nonatomic, assign) NSInteger screens;
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

- (id)init {
    self = [super init];
    if (self) {
        self.tilingEnabled = YES;
    }
    return self;
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
    if ([layoutString isEqualToString:@"tall"]) return [TallLayout class];
    if ([layoutString isEqualToString:@"tall-right"]) return [TallRightLayout class];
    if ([layoutString isEqualToString:@"wide"]) return [WideLayout class];
    if ([layoutString isEqualToString:@"middle-wide"]) return [MiddleWideLayout class];
    if ([layoutString isEqualToString:@"fullscreen"]) return [FullscreenLayout class];
    if ([layoutString isEqualToString:@"column"]) return [ColumnLayout class];
    if ([layoutString isEqualToString:@"row"]) return [RowLayout class];
    if ([layoutString isEqualToString:@"floating"]) return [FloatingLayout class];
    if ([layoutString isEqualToString:@"widescreen-tall"]) return [WidescreenTallLayout class];
    return nil;
}

+ (NSString *)stringForLayoutClass:(Class)layoutClass {
    if (layoutClass == [TallLayout class]) return @"tall";
    if (layoutClass == [TallRightLayout class]) return @"tall-right";
    if (layoutClass == [WideLayout class]) return @"wide";
    if (layoutClass == [MiddleWideLayout class]) return @"middle-wide";
    if (layoutClass == [FullscreenLayout class]) return @"fullscreen";
    if (layoutClass == [ColumnLayout class]) return @"column";
    if (layoutClass == [RowLayout class]) return @"row";
    if (layoutClass == [FloatingLayout class]) return @"floating";
    if (layoutClass == [WidescreenTallLayout class]) return @"widescreen-tall";
    return nil;
}

- (void)loadConfiguration {
    [self loadConfigurationFile];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    for (NSString *defaultsKey in @[ AMConfigurationLayoutsKey,
                                     AMConfigurationFloatingBundleIdentifiers,
                                     AMConfigurationIgnoreMenuBar,
                                     AMConfigurationFloatSmallWindows,
                                     AMConfigurationMouseFollowsFocus,
                                     AMConfigurationFocusFollowsMouse,
                                     AMConfigurationEnablesLayoutHUD,
                                     AMConfigurationEnablesLayoutHUDOnSpaceChange,
                                     AMConfigurationUseCanaryBuild,
                                     AMConfigurationWindowMargins,
                                     AMConfigurationWindowMarginSize]) {
        id value = self.configuration[defaultsKey];
        id defaultValue = self.defaultConfiguration[defaultsKey];
        if (value || (defaultValue && ![userDefaults objectForKey:defaultsKey])) {
            [userDefaults setObject:value ?: defaultValue forKey:defaultsKey];
        }
    }
}

- (void)loadConfigurationFile {
    NSString *amethystConfigPath = [NSHomeDirectory() stringByAppendingPathComponent:@".amethyst"];
    NSString *defaultAmethystConfigPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"amethyst"];

    NSData *data;
    NSError *error;
    NSDictionary *configuration;

    if ([[NSFileManager defaultManager] fileExistsAtPath:amethystConfigPath isDirectory:NO]) {
        data = [NSData dataWithContentsOfFile:amethystConfigPath];
        if (data) {
            configuration = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                DDLogError(@"error loading configuration: %@", error);
                NSString *message = [NSString stringWithFormat:@"There was an error trying to load your .amethyst configuration. Going to use default configuration. %@", error.localizedDescription];
                NSRunAlertPanel(@"Error loading configuration", message, @"OK", nil, nil);
            } else {
                self.configuration = configuration;
            }
        }
    }

    error = nil;
    data = [NSData dataWithContentsOfFile:defaultAmethystConfigPath];
    configuration = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        DDLogError(@"error loading default configuration: %@", error);
        NSRunAlertPanel(@"Error loading default configuration", @"There was an error when trying to load the default configuration. Amethyst may not function correctly.", @"OK", nil, nil);
        return;
    }

    self.defaultConfiguration = configuration;

    self.modifier1 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod1String] ?: self.defaultConfiguration[AMConfigurationMod1String]];
    self.modifier2 = [self modifierFlagsForStrings:self.configuration[AMConfigurationMod2String] ?: self.defaultConfiguration[AMConfigurationMod2String]];
    self.screens = [(self.configuration[AMConfigurationScreens] ?: self.defaultConfiguration[AMConfigurationScreens]) integerValue];
}

- (NSString *)constructLayoutKeyString:(NSString *)layoutString {
     return [NSString stringWithFormat:@"select-%@-layout", layoutString];
}

- (BOOL)hasCustomConfiguration {
    return !!self.configuration;
}

#pragma mark Hot Key Mapping

- (AMModifierFlags)modifierFlagsForModifierString:(NSString *)modifierString {
    if ([modifierString isEqualToString:@"mod1"]) return self.modifier1;
    if ([modifierString isEqualToString:@"mod2"]) return self.modifier2;

    DDLogError(@"Unknown modifier string: %@", modifierString);

    return self.modifier1;
}

- (void)constructCommandWithHotKeyManager:(AMHotKeyManager *)hotKeyManager commandKey:(NSString *)commandKey handler:(AMHotKeyHandler)handler {
    BOOL override = NO;
    NSDictionary *command = self.configuration[commandKey];
    if (command) {
        override = YES;
    } else {
        if (self.configuration[AMConfigurationMod1String] || self.configuration[AMConfigurationMod2String]) {
            override = YES;
        }
        command = self.defaultConfiguration[commandKey];
    }
    NSString *commandKeyString = command[AMConfigurationCommandKeyKey];
    NSString *commandModifierString = command[AMConfigurationCommandModKey];

    AMModifierFlags commandFlags;
    if ([commandModifierString isEqualToString:@"mod1"]) {
        commandFlags = self.modifier1;
    } else if ([commandModifierString isEqualToString:@"mod2"]) {
        commandFlags = self.modifier2;
    } else {
        DDLogError(@"Unknown modifier string: %@", commandModifierString);
        return;
    }

    [hotKeyManager registerHotKeyWithKeyString:commandKeyString modifiers:commandFlags handler:handler defaultsKey:commandKey override:override];
}

- (void)setUpWithHotKeyManager:(AMHotKeyManager *)hotKeyManager windowManager:(AMWindowManager *)windowManager {
    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandCycleLayoutForwardKey handler:^{
        [windowManager.focusedScreenManager cycleLayoutForward];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandCycleLayoutBackwardKey handler:^{
        [windowManager.focusedScreenManager cycleLayoutBackward];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandShrinkMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(Layout *layout) {
            [layout shrinkMainPane];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandExpandMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(Layout *layout) {
            [layout expandMainPane];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandIncreaseMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(Layout *layout) {
            [layout increaseMainPaneCount];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandDecreaseMainKey handler:^{
        [[windowManager focusedScreenManager] updateCurrentLayout:^(Layout *layout) {
            [layout decreaseMainPaneCount];
        }];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandFocusCCWKey handler:^{
        [windowManager moveFocusCounterClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandFocusCWKey handler:^{
        [windowManager moveFocusClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandSwapScreenCCWKey handler:^{
        [windowManager swapFocusedWindowScreenCounterClockwise];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandSwapScreenCWKey handler:^{
        [windowManager swapFocusedWindowScreenClockwise];
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

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandDisplayCurrentLayoutKey handler:^{
        [windowManager displayCurrentLayout];
    }];

    for (NSUInteger screenNumber = 1; screenNumber <= self.screens; ++screenNumber) {
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

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandThrowSpaceLeftKey handler:^{
        [windowManager pushFocusedWindowToSpaceLeft];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandThrowSpaceRightKey handler:^{
        [windowManager pushFocusedWindowToSpaceRight];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandToggleFloatKey handler:^{
        [windowManager toggleFloatForFocusedWindow];
    }];

    [self constructCommandWithHotKeyManager:hotKeyManager commandKey:AMConfigurationCommandToggleTilingKey handler:^{
        [AMConfiguration sharedConfiguration].tilingEnabled = ![AMConfiguration sharedConfiguration].tilingEnabled;
        [windowManager markAllScreensForReflow];
    }];

    NSArray *layoutStrings = self.configuration[AMConfigurationLayoutsKey] ?: self.defaultConfiguration[AMConfigurationLayoutsKey];
    for (NSString *layoutString in layoutStrings) {
        Class layoutClass = [self.class layoutClassForString:layoutString];
        if (!layoutClass) {
            continue;
        }
        [self constructCommandWithHotKeyManager:hotKeyManager commandKey:[self constructLayoutKeyString:layoutString] handler:^{
            [[windowManager focusedScreenManager] selectLayout:layoutClass];
        }];
    }
}

#pragma mark Public Methods

- (NSArray *)layoutsWithWindowActivityCache:(id<WindowActivityCache>)windowActivityCache {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *layoutStrings = [userDefaults arrayForKey:AMConfigurationLayoutsKey];
    NSMutableArray *layouts = [NSMutableArray array];
    for (NSString *layoutString in layoutStrings) {
        if ([layoutString isEqualToString:@"tall"]) [layouts addObject:[[TallLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"tall-right"]) [layouts addObject:[[TallRightLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"wide"]) [layouts addObject:[[WideLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"middle-wide"]) [layouts addObject:[[MiddleWideLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"fullscreen"]) [layouts addObject:[[FullscreenLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"column"]) [layouts addObject:[[ColumnLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"row"]) [layouts addObject:[[RowLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"floating"]) [layouts addObject:[[FloatingLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else if ([layoutString isEqualToString:@"widescreen-tall"]) [layouts addObject:[[WidescreenTallLayout alloc] initWithWindowActivityCache:windowActivityCache]];
        else DDLogError(@"Unrecognized layout string: %@", layoutString);
    }
    return layouts;
}

- (NSArray *)layoutStrings {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults arrayForKey:AMConfigurationLayoutsKey] ?: @[];
}

- (void)setLayoutStrings:(NSArray *)layoutStrings {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:layoutStrings forKey:AMConfigurationLayoutsKey];
}

- (NSArray *)availableLayoutStrings {
    return [[[@[ [TallLayout class],
                [TallRightLayout class],
                [WideLayout class],
                [MiddleWideLayout class],
                [FullscreenLayout class],
                [ColumnLayout class],
                [RowLayout class],
                [FloatingLayout class],
                [WidescreenTallLayout class] ] rac_sequence] map:^ NSString * (Class layoutClass) {
        return [self.class stringForLayoutClass:layoutClass];
    }] array];
}

- (BOOL)runningApplicationShouldFloat:(NSRunningApplication *)runningApplication {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *floatingBundleIdentifiers = [userDefaults arrayForKey:AMConfigurationFloatingBundleIdentifiers];

    if (!floatingBundleIdentifiers) {
        return NO;
    }

    return [floatingBundleIdentifiers containsObject:runningApplication.bundleIdentifier];
}

- (BOOL)ignoreMenuBar {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationIgnoreMenuBar];
}

- (BOOL)floatSmallWindows {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationFloatSmallWindows];
}

- (BOOL)mouseFollowsFocus {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationMouseFollowsFocus];
}

- (BOOL)focusFollowsMouse {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationFocusFollowsMouse];
}

- (BOOL)enablesLayoutHUD {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationEnablesLayoutHUD];
}

- (BOOL)enablesLayoutHUDOnSpaceChange {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationEnablesLayoutHUDOnSpaceChange];
}

- (BOOL)useCanaryBuild {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationUseCanaryBuild];
}

- (CGFloat)windowMarginSize {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults floatForKey:AMConfigurationWindowMarginSize];
}

- (BOOL)windowMargins {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults boolForKey:AMConfigurationWindowMargins];
}

- (NSArray *)floatingBundleIdentifiers {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults arrayForKey:AMConfigurationFloatingBundleIdentifiers] ?: @[];
}

- (void)setFloatingBundleIdentifiers:(NSArray *)floatingBundleIdentifiers {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:floatingBundleIdentifiers ?: @[] forKey:AMConfigurationFloatingBundleIdentifiers];
}

- (NSArray *)hotKeyNameToDefaultsKey {
    NSMutableArray *hotKeyNameToDefaultsKey = [NSMutableArray arrayWithCapacity:30];

    [hotKeyNameToDefaultsKey addObject:@[@"Cycle layout forward", AMConfigurationCommandCycleLayoutForwardKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Cycle layout backwards", AMConfigurationCommandCycleLayoutBackwardKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Shrink main pane", AMConfigurationCommandShrinkMainKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Expand main pane", AMConfigurationCommandExpandMainKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Increase main pane count", AMConfigurationCommandIncreaseMainKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Decrease main pane count", AMConfigurationCommandDecreaseMainKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Move focus counter clockwise", AMConfigurationCommandFocusCCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Move focus clockwise", AMConfigurationCommandFocusCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Swap focused window to counter clockwise screen", AMConfigurationCommandSwapScreenCCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Swap focused window to clockwise screen", AMConfigurationCommandSwapScreenCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Swap focused window counter clockwise", AMConfigurationCommandSwapCCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Swap focused window clockwise", AMConfigurationCommandSwapCWKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Swap focused window with main window", AMConfigurationCommandSwapMainKey]];

    for (NSUInteger spaceNumber = 1; spaceNumber < 10; ++spaceNumber) {
        NSString *name = [NSString stringWithFormat:@"Throw focused window to space %@", @(spaceNumber)];
        [hotKeyNameToDefaultsKey addObject:@[name, [AMConfigurationCommandThrowSpacePrefixKey stringByAppendingFormat:@"-%@", @(spaceNumber)]]];
    }

    for (NSUInteger screenNumber = 1; screenNumber <= 3; ++screenNumber) {
        NSString *focusCommandName = [NSString stringWithFormat:@"Focus screen %@", @(screenNumber)];
        NSString *throwCommandName = [NSString stringWithFormat:@"Throw focused window to screen %@", @(screenNumber)];
        NSString *focusCommandKey = [AMConfigurationCommandFocusScreenPrefixKey stringByAppendingFormat:@"-%@", @(screenNumber)];
        NSString *throwCommandKey = [AMConfigurationCommandThrowScreenPrefixKey stringByAppendingFormat:@"-%@", @(screenNumber)];

        [hotKeyNameToDefaultsKey addObject:@[focusCommandName, focusCommandKey]];
        [hotKeyNameToDefaultsKey addObject:@[throwCommandName, throwCommandKey]];
    }

    [hotKeyNameToDefaultsKey addObject:@[@"Toggle float for focused window", AMConfigurationCommandToggleFloatKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Display current layout", AMConfigurationCommandDisplayCurrentLayoutKey]];
    [hotKeyNameToDefaultsKey addObject:@[@"Toggle global tiling", AMConfigurationCommandToggleTilingKey]];

    for (NSString *layoutString in self.availableLayoutStrings) {
        NSString *commandName = [NSString stringWithFormat:@"Select %@ layout", layoutString];
        NSString *commandKey = [NSString stringWithFormat:@"select-%@-layout", layoutString];
        [hotKeyNameToDefaultsKey addObject:@[commandName, commandKey]];
    }

    return hotKeyNameToDefaultsKey;
}

@end
