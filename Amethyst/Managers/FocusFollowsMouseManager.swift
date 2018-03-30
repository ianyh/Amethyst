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
import RxSwift

protocol FocusFollowsMouseManagerDelegate: class {
    func windowsForFocusFollowsMouse() -> [SIWindow]
}

final class FocusFollowsMouseManager {
    weak var delegate: FocusFollowsMouseManagerDelegate?

    private let userConfiguration: UserConfiguration

    private var subscription: Disposable? // to work around capture of self in closure

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration

        subscription = nil // with this done, we can capture self

        // we want to observe changes to the focusFollowsMouse config, because mouse tracking has CPU cost
        subscription = UserDefaults.standard.rx.observe(Bool.self, ConfigurationKey.focusFollowsMouse.rawValue)
            .distinctUntilChanged { $0 == $1 }
            .scan(nil) { existingHandler, followingIsDesired -> Any? in
                if let handler = existingHandler {
                    NSEvent.removeMonitor(handler)
                    return nil
                } else if followingIsDesired! {
                    return NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
                        self.focusWindowWithMouseMovedEvent(event)
                    }
                } else {
                    return nil
                }
            }
            .subscribe()
    }

    deinit {
        subscription?.dispose()
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
