//
//  FloatingLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class FloatingReflowOperation: ReflowOperation {}

final class FloatingLayout: Layout {
    static var layoutName: String { return "Floating" }
    static var layoutKey: String { return "floating" }

    let windowActivityCache: WindowActivityCache

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return FloatingReflowOperation(screen: screen, windows: windows, frameAssigner: self)
    }
}

extension FloatingLayout: FrameAssigner {}
