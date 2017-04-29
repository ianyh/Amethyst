//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol WindowActivityCache {
    func windowIsActive(_ window: SIWindow) -> Bool
}

class Layout: NSObject {
    class var layoutName: String { return "" }
    class var layoutKey: String { return "" }

    let windowActivityCache: WindowActivityCache

    required init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
        super.init()
    }

    func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        fatalError()
    }

    func shrinkMainPane() {}
    func expandMainPane() {}
    func increaseMainPaneCount() {}
    func decreaseMainPaneCount() {}
    func updateWithChange(_ windowChange: WindowChange) {}
    func nextWindowIDCounterClockwise() -> CGWindowID? { return nil }
    func nextWindowIDClockwise() -> CGWindowID? { return nil }
}
