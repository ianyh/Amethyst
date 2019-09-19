//
//  FloatingLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class FloatingLayout<Window: WindowType>: Layout<Window> {
    override static var layoutName: String { return "Floating" }
    override static var layoutKey: String { return "floating" }

    override var layoutDescription: String { return "" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignment<Window>]? {
        return nil
    }
}
