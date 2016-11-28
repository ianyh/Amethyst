//
//  FloatingLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class FloatingReflowOperation: ReflowOperation {}

open class FloatingLayout: Layout {
    override open class var layoutName: String { return "Floating" }
    override open class var layoutKey: String { return "floating" }

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return FloatingReflowOperation(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }
}
