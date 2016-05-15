//
//  LayoutNameWindow.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import QuartzCore

public class LayoutNameWindow: NSWindow {
    @IBOutlet public weak var layoutNameField: NSTextField?

    public override var contentView: NSView? {
        didSet {
            contentView?.wantsLayer = true
            contentView?.layer?.frame = NSRectToCGRect(contentView!.frame)
            contentView?.layer?.cornerRadius = 20.0
            contentView?.layer?.masksToBounds = true
            contentView?.layer?.backgroundColor = NSColor.blackColor().colorWithAlphaComponent(0.75).CGColor
        }
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        opaque = false
        ignoresMouseEvents = true
        backgroundColor = NSColor.clearColor()
        level = Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey))
    }

//    - (void)setContentView:(NSView *)aView {
//        aView.wantsLayer = YES;
//        aView.layer.frame = aView.frame;
//        aView.layer.cornerRadius = 20.0;
//        aView.layer.masksToBounds = YES;
//        aView.layer.backgroundColor = [[NSColor blackColor] colorWithAlphaComponent:0.75].CGColor;
//
//        [super setContentView:aView];
//}

}
