//
//  SIApplication+Amethyst.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

public extension SIApplication {
    public func floating() -> Bool {
        let runningApplication = NSRunningApplication(processIdentifier: self.processIdentifier())
        return UserConfiguration.shared.runningApplicationShouldFloat(runningApplication!)
    }
}
