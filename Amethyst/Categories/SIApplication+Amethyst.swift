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
    func windowWithTitleShouldFloat(_ windowTitle: String) -> Bool {
        guard let runningApplication = NSRunningApplication(processIdentifier: processIdentifier()) else {
            return true
        }

        return UserConfiguration.shared.runningApplication(runningApplication, shouldFloatWindowWithTitle: windowTitle)
    }

    func observe(notification: String, with accessibilityElement: SIAccessibilityElement, handler: @escaping SIAXNotificationHandler) -> Bool {
        return observeNotification(notification as CFString, with: accessibilityElement, handler: handler)
    }
}
