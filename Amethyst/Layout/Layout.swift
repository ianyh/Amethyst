//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

public protocol WindowActivityCache {
    func windowIsActive(window: SIWindow) -> Bool
}

public class Layout: NSObject {
    public class var layoutName: String { return "" }
    public class var layoutKey: String { return "" }

    public let windowActivityCache: WindowActivityCache

    public required init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
        super.init()
    }

    func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        fatalError()
    }

    func shrinkMainPane() {}
    func expandMainPane() {}
    func increaseMainPaneCount() {}
    func decreaseMainPaneCount() {}
    func updateWithChange(windowChange: WindowChange) {}
}
