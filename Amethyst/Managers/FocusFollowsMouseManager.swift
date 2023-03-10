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

protocol FocusFollowsMouseManagerDelegate: AnyObject {
    associatedtype Window: WindowType
    typealias Screen = Window.Screen
    func windows(onScreen screen: Screen) -> [Window]
}

class FocusFollowsMouseManager<Delegate: FocusFollowsMouseManagerDelegate> {
    typealias Window = Delegate.Window
    typealias Screen = Window.Screen

    weak var delegate: Delegate?

    private var lastMouseFocusTime = Date.distantPast

    private let userConfiguration: UserConfiguration
    private let disposeBag = DisposeBag()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration

        // we want to observe changes to the focusFollowsMouse config, because mouse tracking has CPU cost
        UserDefaults.standard.rx.observe(Bool.self, ConfigurationKey.focusFollowsMouse.rawValue)
            .distinctUntilChanged { $0 == $1 }
            .scan(nil) { [unowned self] existingHandler, followingIsDesired -> Any? in
                if let handler = existingHandler {
                    NSEvent.removeMonitor(handler)
                }
                if followingIsDesired! {
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

        guard let screen = Screen.availableScreens.first(where: { $0.frameIncludingDockAndMenu().contains(event.locationInWindow) }) else {
            return
        }

        guard let windows = delegate?.windows(onScreen: screen) else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = Screen.globalHeight() - mousePoint.y + screen.frameIncludingDockAndMenu().origin.y

        if let focusedWindow = Window.currentlyFocused() {
            // If the point is already in the frame of the focused window do nothing.
            guard !focusedWindow.frame().contains(mousePoint) else {
                return
            }
        }

        guard let topWindow = WindowsInformation.topWindowForScreenAtPoint(mousePoint, withWindows: windows) else {
            return
        }

        self.lastMouseFocusTime = Date()

        topWindow.focus()
    }

    func recentlyTriggeredFocusFollowsMouse() -> Bool {
        return Date().timeIntervalSince(lastMouseFocusTime) < 0.5
    }
}
