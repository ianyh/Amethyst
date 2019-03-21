//
//  Application.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/12/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol ApplicationType: Equatable {
    associatedtype Window: WindowType

    init(runningApplication: NSRunningApplication)

    func title() -> String?
    func windows() -> [Window]
    func pid() -> pid_t
    func windowWithTitleShouldFloat(_ windowTitle: String) -> Bool
    func dropWindowsCache()
    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> Bool
    func observe(notification: String, window: Window, handler: @escaping SIAXNotificationHandler) -> Bool
    func unobserve(notification: String)
    func unobserve(notification: String, window: Window)
}

class AnyApplication<Application: ApplicationType>: ApplicationType {
    typealias Window = Application.Window

    private let internalApplication: Application

    static func == (lhs: AnyApplication<Application>, rhs: AnyApplication<Application>) -> Bool {
        return lhs.internalApplication == rhs.internalApplication
    }

    required init(_ application: Application) {
        self.internalApplication = application
    }

    required init(runningApplication: NSRunningApplication) {
        fatalError()
    }

    func title() -> String? {
        return internalApplication.title()
    }

    func windows() -> [Window] {
        return internalApplication.windows()
    }

    func pid() -> pid_t {
        return internalApplication.pid()
    }

    func windowWithTitleShouldFloat(_ windowTitle: String) -> Bool {
        return internalApplication.windowWithTitleShouldFloat(windowTitle)
    }

    func dropWindowsCache() {
        internalApplication.dropWindowsCache()
    }

    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> Bool {
        return internalApplication.observe(notification: notification, handler: handler)
    }

    func observe(notification: String, window: Window, handler: @escaping SIAXNotificationHandler) -> Bool {
        return internalApplication.observe(notification: notification, window: window, handler: handler)
    }

    func unobserve(notification: String) {
        internalApplication.unobserve(notification: notification)
    }

    func unobserve(notification: String, window: Window) {
        internalApplication.unobserve(notification: notification, window: window)
    }
}

func != <Application: ApplicationType>(lhs: Application, rhs: Application) -> Bool {
    return !(lhs == rhs)
}

extension SIApplication: ApplicationType {
    typealias Window = AXWindow

    func windows() -> [Window] {
        let axWindows: [SIWindow] = self.windows()
        return axWindows.map { Window(axElement: $0.axElementRef) }
    }

    func pid() -> pid_t {
        return processIdentifier()
    }

    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> Bool {
        return observeNotification(notification as CFString, with: self, handler: handler)
    }

    func observe(notification: String, window: Window, handler: @escaping SIAXNotificationHandler) -> Bool {
        return observeNotification(notification as CFString, with: window, handler: handler)
    }

    func unobserve(notification: String) {
        unobserveNotification(notification as CFString, with: self)
    }

    func unobserve(notification: String, window: Window) {
        unobserveNotification(notification as CFString, with: window)
    }
}
