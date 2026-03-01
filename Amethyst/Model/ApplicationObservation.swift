//
//  ApplicationObservation.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/21/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Cocoa
import Foundation
import RxSwift

/// Delegate for handling application observer events.
protocol ApplicationObservationDelegate: AnyObject {
    associatedtype Application: ApplicationType
    typealias Window = Application.Window

    /**
     Called when the application has added a window to being active.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was added.
     
     - Note: `window` is not necessarily newly created.
     */
    func application(_ application: AnyApplication<Application>, didAddWindow window: Window)

    /**
     Called when the application has removed a window from being active.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was removed.
     */
    func application(_ application: AnyApplication<Application>, didRemoveWindow window: Window)

    /**
     Called when the application has focused a window.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was focused.
     */
    func application(_ application: AnyApplication<Application>, didFocusWindow window: Window)

    /**
     Called when the application has encountered a window that is potentially new.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was encountered.
     
     - Note:
     This is the event that is called when native tab switching happens.
     */
    func application(_ application: AnyApplication<Application>, didFindPotentiallyNewWindow window: Window)

    /**
     Called when the application has moved a window.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was moved.
     */
    func application(_ application: AnyApplication<Application>, didMoveWindow window: Window)

    /**
     Called when the application has resized a window.
     
     - Parameters:
         - application: The application the event occurred in.
         - window: The window that was resized.
     */
    func application(_ application: AnyApplication<Application>, didResizeWindow window: Window)

    /**
     Called when the application is activated.
     
     - Parameters:
         - application: The application that was activated.
     */
    func applicationDidActivate(_ application: AnyApplication<Application>)
}

/**
 This struct sets up accessibility API event subscriptions for a given Application.
 
 Handling references to the window manager and mouse state. The observers themselves react to mouse / accessibility state by either changing window positions or updating the mouse state based on new information.
 */
struct ApplicationObservation<Delegate: ApplicationObservationDelegate> {
    typealias Application = Delegate.Application
    typealias Window = Application.Window

    /// Errors when attempting to add observers to applications
    enum Error: Swift.Error {
        /// General failure
        case failed

        /// Failure in the accessibility observation
        case observationFailed(error: Int32)
    }

    /// Notifications that are observed
    private enum Notification {
        /// A window is created
        case created

        /// A window is deminiaturized
        case windowDeminiaturized

        /// A window is miniaturized
        case windowMiniaturized

        /// The application has changed its focused window
        case focusedWindowChanged

        /// The application is activated
        case applicationActivated

        /// A window is moved
        case windowMoved

        /// A window is resized
        case windowResized

        /// The application changed its primary window
        case mainWindowChanged

        /// The window has likely been destroyed
        case elementDestroyed(window: Window)

        /// The actual notification name
        var string: String {
            switch self {
            case .created:
                return kAXCreatedNotification
            case .windowDeminiaturized:
                return kAXWindowDeminiaturizedNotification
            case .windowMiniaturized:
                return kAXWindowMiniaturizedNotification
            case .focusedWindowChanged:
                return kAXFocusedWindowChangedNotification
            case .applicationActivated:
                return kAXApplicationActivatedNotification
            case .windowMoved:
                return kAXWindowMovedNotification
            case .windowResized:
                return kAXWindowResizedNotification
            case .mainWindowChanged:
                return kAXMainWindowChangedNotification
            case .elementDestroyed:
                return kAXUIElementDestroyedNotification
            }
        }

        /// Notifications relevant to the entire application
        static var applicationNotifications: [Notification] {
            return [
                .created,
                .windowDeminiaturized,
                .windowMiniaturized,
                .focusedWindowChanged,
                .applicationActivated,
                .windowMoved,
                .windowResized,
                .mainWindowChanged
            ]
        }

        /// Notifications relevant to a particular window of an application
        static func windowNotificationsForWindow(_ window: Window) -> [Notification] {
            return [
                .elementDestroyed(window: window)
            ]
        }
    }

    /// The application being observed
    let application: AnyApplication<Application>

    /// The delegate for handling events as they come in
    private weak var delegate: Delegate?

    /**
     - Parameters:
         - application: The application to be observed.
         - delegate: The delegate to handle events.
     */
    init(application: AnyApplication<Application>, delegate: Delegate?) {
        self.application = application
        self.delegate = delegate
    }

    /**
     - Returns:
     An observable that attemps to subscribe to events on the application. The observable completes when subscriptions have been put in place, and errors otherwise.
     */
    func addObservers() -> Observable<Void> {
        return _addObservers(notifications: Notification.applicationNotifications).retry { errorTrigger in
            errorTrigger.enumerated().flatMap { count, error -> Observable<Int> in
                guard count < 6 else {
                    return .error(error)
                }

                return .timer(.milliseconds((count ^ 2 * 100)), scheduler: MainScheduler.instance)
            }
        }
    }

    /**
     - Returns:
     An observable that attempts to subscribe to events specifically relevant to a window in an application. The observable completes when subscriptions have been put in place, and errors otherwise.
     */
    func addObserversForWindow(_ window: Window) -> Observable<Void> {
        let notifications = Notification.windowNotificationsForWindow(window)
        return _addObservers(notifications: notifications).retry { errorTrigger in
            errorTrigger.enumerated().flatMap { count, error -> Observable<Int> in
                guard count < 6 else {
                    return .error(error)
                }

                return .timer(.milliseconds((count ^ 2 * 100)), scheduler: MainScheduler.instance)
            }
        }
    }

    /**
     - Returns:
     An observable that unsubscribes from events that may be tracked for a specific window.

     - Parameters:
        - window: the window on which notifications may be observed.
     
     - Note:
     This is a no op in the case where no notifications were being observed.
     */
    func removeObserversForWindow(_ window: Window) {
        let notifications = Notification.windowNotificationsForWindow(window)
        removeObservers(notifications: notifications, for: window)
    }

    private func _addObservers(notifications: [Notification]) -> Observable<Void> {
        return Observable.from(notifications)
            .scan([]) { observed, notification -> [Notification] in
                let notifications = observed + [notification]

                do {
                    try self.addObserver(for: notification)
                } catch {
                    let applicationTitle = self.application.title() ?? "<unknown>"
                    log.error("Failed to add observer \(notification) on application \(applicationTitle) (\(self.application.pid())): \(error)")
                    self.removeObservers(notifications: notifications)
                    throw error
                }

                return notifications
            }
            .map { _ in }
    }

    /**
     Observes a specific notification.
     
     - Parameters:
         - notification: The notification to observe.
     
     - Throws:
     An error when failing to add observer.
     */
    private func addObserver(for notification: Notification) throws {
        let success: AXError
        switch notification {
        case .elementDestroyed(let window):
            success = application.observe(notification: notification.string, window: window) { _ in
                DispatchQueue.main.async {
                    self.handle(notification: notification, window: window)
                }
            }
        default:
            success = application.observe(notification: notification.string) { element in
                guard let window = Window(element: element) else {
                    return
                }

                DispatchQueue.main.async {
                    self.handle(notification: notification, window: window)
                }
            }
        }

        switch success {
        case .success:
            return
        case .notificationAlreadyRegistered:
            return
        default:
            throw Error.observationFailed(error: success.rawValue)
        }
    }

    /**
     Removes notifications from being observed.
     
     - Parameters:
         - notifications: The notifications to stop observing.
     */
    private func removeObservers(notifications: [Notification]) {
        notifications.forEach { application.unobserve(notification: $0.string) }
    }

    /**
     Removes notifications from being observed for a window.
     
     - Parameters:
        - notifications: the notifications to stop observing.
        - window: the window for which notifications were being observed.
     */
    private func removeObservers(notifications: [Notification], for window: Window) {
        notifications.forEach { application.unobserve(notification: $0.string, window: window) }
    }

    private func handle(notification: Notification, window: Window) {
        log.debug("""
        Received notification for window: \(window)
            notification: \(notification)
            \(window.title() ?? "no title") (\(window.id()))
        """)
        switch notification {
        case .created:
            // Disabling window creations because they end up being more reliably tracked with main window changed
//            delegate?.application(application, didFindPotentiallyNewWindow: window)
            break
        case .windowDeminiaturized:
            delegate?.application(application, didAddWindow: window)
        case .windowMiniaturized:
            delegate?.application(application, didRemoveWindow: window)
        case .focusedWindowChanged:
            guard let focusedWindow = Window.currentlyFocused() else {
                return
            }
            delegate?.application(application, didFocusWindow: focusedWindow)
        case .applicationActivated:
            delegate?.applicationDidActivate(application)
        case .windowMoved:
            delegate?.application(application, didMoveWindow: window)
        case .windowResized:
            delegate?.application(application, didResizeWindow: window)
        case .mainWindowChanged:
            delegate?.application(application, didFindPotentiallyNewWindow: window)
        case .elementDestroyed:
            delegate?.application(application, didRemoveWindow: window)
        }
    }
}
