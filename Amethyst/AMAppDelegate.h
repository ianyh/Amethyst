//
//  AMAppDelegate.h
//  Amethyst
//
//  Created by Ian on 5/14/13.
//  Copyright (c) 2013 Ian Ynda-Hummel. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (void)setCurrentLayoutInStatus:(NSString *)layout;

@end
