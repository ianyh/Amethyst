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

final class LayoutNameWindow: NSWindow {
    @IBOutlet weak var layoutNameField: NSTextField?
    @IBOutlet weak var layoutDescriptionLabel: NSTextField?

    @IBOutlet override var contentView: NSView? {
        didSet {
            contentView?.wantsLayer = true
            contentView?.layer?.frame = NSRectToCGRect(contentView!.frame)
            contentView?.layer?.cornerRadius = 20.0
            contentView?.layer?.masksToBounds = true
            contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        }
    }
    @IBOutlet var containerView: NSView?

    override func awakeFromNib() {
        super.awakeFromNib()

        isOpaque = false
        ignoresMouseEvents = true
        backgroundColor = NSColor.clear
        level = .floating
    }
}
