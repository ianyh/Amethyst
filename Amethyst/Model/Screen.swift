//
//  Screen.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/14/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation

protocol ScreenType: Equatable {
    static var availableScreens: [Self] { get }

    var frame: NSRect { get }
    func adjustedFrame() -> CGRect
    func frameIncludingDockAndMenu() -> CGRect
    func frameWithoutDockOrMenu() -> CGRect
    func screenIdentifier() -> String?
    func focusScreen()
}

struct AMScreen: ScreenType {
    static var availableScreens: [AMScreen] { return NSScreen.screens.map { AMScreen(screen: $0) } }

    let screen: NSScreen

    var frame: NSRect { return screen.frame }

    func adjustedFrame() -> CGRect {
        return screen.adjustedFrame()
    }

    func frameIncludingDockAndMenu() -> CGRect {
        return screen.frameIncludingDockAndMenu()
    }

    func frameWithoutDockOrMenu() -> CGRect {
        return screen.frameWithoutDockOrMenu()
    }

    func screenIdentifier() -> String? {
        return screen.screenIdentifier()
    }

    func focusScreen() {
        screen.focusScreen()
    }
}
