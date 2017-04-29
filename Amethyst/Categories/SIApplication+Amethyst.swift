//
//  SIApplication+Amethyst.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

extension SIApplication {
    func floating() -> Bool {
        guard let runningApplication = NSRunningApplication(processIdentifier: processIdentifier()) else {
            return true
        }

        return UserConfiguration.shared.runningApplicationShouldFloat(runningApplication)
    }
}
