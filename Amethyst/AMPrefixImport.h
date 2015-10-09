//
//  AMPrefixImport.h
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/26/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#ifndef Amethyst_AMPrefixImport_h
#define Amethyst_AMPrefixImport_h

#import <Silica/Silica.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDLogMacros.h>
#import <Sparkle/Sparkle.h>
#import <Masonry/Masonry.h>
#import "NSScreen+Amethyst.h"
#import "SIWindow+Amethyst.h"
#import "SIApplication+Amethyst.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

#endif
