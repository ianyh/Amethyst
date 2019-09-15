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
    associatedtype Window: WindowType
    func windowsForFocusFollowsMouse() -> [Window]
}

class FocusFollowsMouseManager<Delegate: FocusFollowsMouseManagerDelegate> {
    typealias Screen = Delegate.Window.Screen

    weak var delegate: Delegate!

    private let userConfiguration: UserConfiguration

    private let disposeBag = DisposeBag()

    init(delegate: Delegate, userConfiguration: UserConfiguration) {
        self.delegate = delegate
        self.userConfiguration = userConfiguration

        // we want to observe changes to the focusFollowsMouse config, because mouse tracking has CPU cost
        UserDefaults.standard.rx.observe(Bool.self, ConfigurationKey.focusFollowsMouse.rawValue)
            .distinctUntilChanged { $0 == $1 }
            .scan(nil) { [unowned self] existingHandler, followingIsDesired -> Any? in
                if let handler = existingHandler {
                    NSEvent.removeMonitor(handler)
                    return nil
                } else if followingIsDesired! {
                    return NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [unowned self] event in
                        self.focusWindowWithMouseMovedEvent(event)
                    }
                } else {
                    return nil
                }
            }
            .subscribe()
            .disposed(by: disposeBag)
    }

    private func focusWindowWithMouseMovedEvent(_ event: NSEvent) {
        guard userConfiguration.focusFollowsMouse() else {
            log.warning("Subscribed to mouse move events that we are ignoring")
            return
        }

        guard let windows = delegate?.windowsForFocusFollowsMouse() else {
            return
        }

        guard let screen = Screen.availableScreens.first(where: { $0.frameIncludingDockAndMenu().contains(event.locationInWindow) }) else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = Screen.globalHeight() - mousePoint.y + screen.frameIncludingDockAndMenu().origin.y

        if let focusedWindow = Delegate.Window.currentlyFocused() {
            // If the point is already in the frame of the focused window do nothing.
            guard !focusedWindow.frame().contains(mousePoint) else {
                return
            }
        }

        guard let topWindow = WindowsInformation.topWindowForScreenAtPoint(mousePoint, withWindows: windows) else {
            return
        }

        topWindow.focus()
    }
}

extension WindowManager: FocusFollowsMouseManagerDelegate {
    func windowsForFocusFollowsMouse() -> [Application.Window] {
        return windows
    }
}
