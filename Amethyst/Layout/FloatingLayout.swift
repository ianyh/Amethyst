//
//  FloatingLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class FloatingLayout: Layout {
    static var layoutName: String { return "Floating" }
    static var layoutKey: String { return "floating" }

    var layoutDescription: String { return "" }

    let windowActivityCache: WindowActivityCache

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation? {
        return nil
    }

}

extension FloatingLayout: FrameAssigner {}
