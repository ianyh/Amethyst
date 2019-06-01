//
//  Application.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/12/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/// Generic protocol for objects acting as applications in the system.
protocol ApplicationType: Equatable {
    /// The type of windows that are used by the application.
    associatedtype Window: WindowType

    /**
     Initialize an application based on its corresponding `NSRunningApplication` if it exists.
     
     - Parameters:
         - runningApplication: The running application to find application for.
     */
    init(runningApplication: NSRunningApplication)

    /// The optional title of the application
    func title() -> String?

    /**
     The windows owned by the application.
     
     - Note:
     This value is cached. Call `dropWindowsCache()` if you believe this may be out of date.
     */
    func windows() -> [Window]

    /// The process ID of the application.
    func pid() -> pid_t

    /**
     Determines whether a window with a given title should float by default.
     
     - Parameters:
         - windowTitle: The window title to test.
     */
    func windowWithTitleShouldFloat(_ windowTitle: String) -> Bool

    /// Clears the internal cache of application windows.
    func dropWindowsCache()

    /**
     Observe an AX notification on the application itself with a given handler.
     
     To remove the observation you must call `unobserve(notification:)`.
     
     - Parameters:
         - notification: The notification name to be observing for.
         - handler: The callback when the notification is triggered.
     
     - Returns:
     `true` if observing the notification succeeded, and `false` otherwise.
     */
    func observe(notification: String, handler: @escaping SIAXNotificationHandler) -> Bool

    /**
     Observe an AX notification on a window of the application with a given handler.
     
     To remove the observation you must call `unobserve(notification:window:)`.
     
     - Parameters:
         - notification: The notification name to be observing for.
         - window: The window being watched for events.
         - handler: The callback when the notification is triggered.
     
     - Returns:
     `true` if observing the notification succeeded, and `false` otherwise.
     */
    func observe(notification: String, window: Window, handler: @escaping SIAXNotificationHandler) -> Bool

    /**
     Removes an observation for a notification on the application itself.
     
     - Parameters:
         - notification: The notification name to stop observing for.
     */
    func unobserve(notification: String)

    /**
     Removes an observation for a notification on the application itself.
     
     - Parameters:
         - notification: The notification name to stop observing for.
         - window: The window to stop watching for events.
     */
    func unobserve(notification: String, window: Window)
}

/**
 Type-erased concerete application for managing applications.
 
 This is necessitated by `ApplicationType` having an associated type which prevents it from being used directly as a concrete type.
 */
class AnyApplication<Application: ApplicationType>: ApplicationType {
    /// The window being used is the window being used by the contained application type.
    typealias Window = Application.Window

    /// The application being contained.
    private let internalApplication: Application

    /// Comparison for `Equatable` conformance.
    static func == (lhs: AnyApplication<Application>, rhs: AnyApplication<Application>) -> Bool {
        return lhs.internalApplication == rhs.internalApplication
    }

    /**
     Initializes an application based on another application.
     
     - Parameters:
         - application: The application to be contained.
     */
    required init(_ application: Application) {
        self.internalApplication = application
    }

    /// It is an error to call this initializer.
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

/// Conformance of `SIApplication` as an Amethyst application.
extension SIApplication: ApplicationType {
    /// `SIApplication` uses `AXWindow` as its window type.
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
