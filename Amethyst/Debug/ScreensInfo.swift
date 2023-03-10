//
//  ScreensInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/9/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser

extension AMScreen {
    func debugDescription() -> String {
        return """
        \tScreenID: \(screenID()!)
        \tScreen Frame: \(frame())
        """
    }
}

struct Screens: ParsableCommand {
    mutating func run() throws {

    }
}
