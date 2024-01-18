//
//  Change.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum Change<Window: WindowType> {
    case add(window: Window)
    case remove(window: Window)
    case focusChanged(window: Window)
    case windowSwap(window: Window, otherWindow: Window)
    case applicationActivate
    case applicationDeactivate
    case spaceChange
    case layoutChange
    case tabChange
    case unknown
}
