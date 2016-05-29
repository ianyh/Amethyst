//
//  FloatingLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class FloatingReflowOperation: ReflowOperation {}

public class FloatingLayout: Layout {
    override public class var layoutName: String { return "Floating" }
    override public class var layoutKey: String { return "floating" }

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return FloatingReflowOperation(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }
}
