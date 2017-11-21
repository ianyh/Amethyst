//
//  FocusFollowsMouseManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

protocol FocusFollowsMouseManagerDelegate: class {
    func windowsForFocusFollowsMouse() -> [SIWindow]
}

// need to inherit from NSObject to track UserDefaults changes
final class FocusFollowsMouseManager: NSObject {
    weak var delegate: FocusFollowsMouseManagerDelegate?

    private let userConfiguration: UserConfiguration
    private var focusConfigurationChangeHandler: (Bool) -> Void   // var not let.  necessary for closure setup.
    private var mouseMovedEventHandler: Any?

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.mouseMovedEventHandler = nil

        // must fully init self before we can use it in a closure, so we put in a fake closure for the handler (for now)
        self.focusConfigurationChangeHandler = { _ in () }
        super.init()  // fully init self

        // can now set up self as an observer.
        // we want to observe changes to the focusFollowsMouse config, because mouse tracking has CPU cost
        UserDefaults.standard.addObserver(self, forKeyPath: ConfigurationKey.focusFollowsMouse.rawValue, options: NSKeyValueObservingOptions.new, context: nil)

        // now that we've initialized self for the closure, change the member function to the actual config change handler
        // TL;DR: subscribe or unsubscribe as desired.
        self.focusConfigurationChangeHandler = { followingIsDesired in
            if followingIsDesired {
                guard self.mouseMovedEventHandler == nil else {
                    return
                }
                self.mouseMovedEventHandler = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
                    self.focusWindowWithMouseMovedEvent(event)
                }
            } else {
                guard let handler = self.mouseMovedEventHandler else {
                    return
                }
                NSEvent.removeMonitor(handler)
                self.mouseMovedEventHandler = nil
            }
        }

        // now that we set up the state tracker for changes, react to the current state.  Because this is a user config setting,
        // the chance of a race condition here is negligible.
        focusConfigurationChangeHandler(self.userConfiguration.focusFollowsMouse())
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: ConfigurationKey.focusFollowsMouse.rawValue)
    }

    // handle changes to UserDefaults, specifically focusFollowsMouse
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == ConfigurationKey.focusFollowsMouse.rawValue else {
            return
        }
        self.focusConfigurationChangeHandler(self.userConfiguration.focusFollowsMouse())
    }

    private func focusWindowWithMouseMovedEvent(_ event: NSEvent) {
        guard userConfiguration.focusFollowsMouse() else {
            LogManager.log?.warning("Subscribed to mouse move events that we are ignoring")
            return
        }

        guard let windows = delegate?.windowsForFocusFollowsMouse() else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = NSScreen.globalHeight() - mousePoint.y

        if let focusedWindow = SIWindow.focused() {
            // If the point is already in the frame of the focused window do nothing.
            guard !focusedWindow.frame().contains(mousePoint) else {
                return
            }
        }

        guard let topWindow = SIWindow.topWindowForScreenAtPoint(mousePoint, withWindows: windows) else {
            return
        }

        topWindow.am_focusWindow()
    }
}

extension WindowManager: FocusFollowsMouseManagerDelegate {
    func windowsForFocusFollowsMouse() -> [SIWindow] {
        return windows
    }
}
