//
//  MouseState.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/21/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/**
 These are the possible actions that the mouse might be taking (that we care about).
 
 We use this enum to convey some information about the window that the mouse might be interacting with.
 */
enum MouseState<Window: WindowType> {
    typealias Screen = Window.Screen
    case pointing
    case clicking
    case dragging
    case moving(window: Window)
    case resizing(screen: Screen, ratio: CGFloat)
    case doneDragging(atTime: Date)
}

/// MouseStateKeeper will need a few things to do its job effectively
protocol MouseStateKeeperDelegate: class {
    associatedtype Window: WindowType
    func recommendMainPaneRatio(_ ratio: CGFloat)
    func swapDraggedWindowWithDropzone(_ draggedWindow: Window)
}

/**
 Maintains state information about the mouse for the purposes of mouse-based window operations.
 
 MouseStateKeeper exists because we need a single shared mouse state between all applications being observed. This class captures the state and coordinates any Amethyst reflow actions that are required in response to mouse events.
 
 Note that some actions may be initiated here and some actions may be completed here; we don't know whether the mouse event stream or the accessibility event stream will fire first.
 
This class by itself can only understand clicking, dragging, and "pointing" (no mouse buttons down). The SIApplication observers are able to augment that understanding of state by "upgrading" a drag action to a "window move" or a "window resize" event since those observers will have proper context.
 */
class MouseStateKeeper<Delegate: MouseStateKeeperDelegate> {
    let dragRaceThresholdSeconds = 0.15 // prevent race conditions during drag ops
    var state: MouseState<Delegate.Window>
    private(set) weak var delegate: Delegate?
    private(set) var lastClick: Date?
    private var monitor: Any?

    init(delegate: Delegate) {
        self.delegate = delegate

        state = .pointing
        let mouseEventsToWatch: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEventsToWatch, handler: self.handleMouseEvent)
    }

    deinit {
        guard let oldMonitor = monitor else { return }
        NSEvent.removeMonitor(oldMonitor)
    }

    // Update our understanding of the current state unless an observer has already
    // done it for us.  mouseUp events take precedence over anything an observer had
    // found -- you can't be dragging or resizing with a mouse button up, even if
    // you're using the "3 finger drag" accessibility option, where no physical button
    // is being pressed.
    func handleMouseEvent(anEvent: NSEvent) {
        switch anEvent.type {
        case .leftMouseDown:
            self.state = .clicking
        case .leftMouseDragged:
            switch self.state {
            case .moving, .resizing:
            break // ignore - we have what we need
            case .pointing, .clicking, .dragging, .doneDragging:
                self.state = .dragging
            }

        case .leftMouseUp:
            switch self.state {
            case .dragging:
                // assume window move event will come shortly after
                self.state = .doneDragging(atTime: Date())
            case let .moving(draggedWindow):
                self.state = .pointing // flip state first to prevent race condition
                self.swapDraggedWindowWithDropzone(draggedWindow)
            case let .resizing(_, ratio):
                self.state = .pointing
                self.resizeFrameToDraggedWindowBorder(ratio)
            case .doneDragging:
                self.state = .doneDragging(atTime: Date()) // reset the clock I guess
            case .clicking:
                lastClick = Date()
                self.state = .pointing
            case .pointing:
                self.state = .pointing
            }

        default: ()
        }
    }

    // React to a reflow event.  Typically this means that any window we were dragging
    // is no longer valid and should be de-correlated from the mouse
    func handleReflowEvent() {
        switch self.state {
        case .doneDragging:
            self.state = .pointing // remove associated timestamp
        case .moving:
            self.state = .dragging // remove associated window
        default: ()
        }
    }

    // Execute an action that was initiated by the observer and completed by the state keeper
    func resizeFrameToDraggedWindowBorder(_ ratio: CGFloat) {
        delegate?.recommendMainPaneRatio(ratio)
    }

    // Execute an action that was initiated by the observer and completed by the state keeper
    func swapDraggedWindowWithDropzone(_ draggedWindow: Delegate.Window) {
        delegate?.swapDraggedWindowWithDropzone(draggedWindow)
    }
}
