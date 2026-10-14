//
//  Window.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/10/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import ApplicationServices
import Foundation
import Silica

// swiftlint:disable identifier_name
 @_silgen_name("GetProcessForPID") @discardableResult
 func GetProcessForPID(_ pid: pid_t, _ psn: inout ProcessSerialNumber) -> OSStatus

 @_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
 func _SLPSSetFrontProcessWithOptions(_ psn: inout ProcessSerialNumber, _ wid: UInt32, _ mode: UInt32) -> CGError

 @_silgen_name("SLPSPostEventRecordTo") @discardableResult
 func SLPSPostEventRecordTo(_ psn: inout ProcessSerialNumber, _ bytes: inout UInt8) -> CGError

 let kCPSUserGenerated: UInt32 = 0x200
// swiftlint:enable identifier_name

/// Generic protocol for objects acting as windows in the system.
protocol WindowType: Equatable {
    associatedtype Screen: ScreenType
    associatedtype WindowID: Codable, Hashable

    /// Returns the currently focused window of its type.
    static func currentlyFocused() -> Self?

    /**
     Attempt to initialize a window based on a Silica element.
     
     Many of the accessibility APIs handle elements directly, so we need a way to convert those elements into a general window type. This is not necessarily meaningful in all cases — tests, for example, may provide window types that do not correspond to actual elements.
     
     - Parameters:
        - element: The element representing a window.
     */
    init?(element: SIAccessibilityElement?)

    /// Returns an opaque unique identifier for the window.
    func id() -> WindowID

    /// Returns the window's ID in the underlying window system.
    func cgID() -> CGWindowID

    /// Returns the window's current frame.
    func frame() -> CGRect

    /// Returns the screen, if any, that the window is currently on.
    func screen() -> Screen?

    /**
     Sets the frame of the window with an error threshold for what constitutes a new frame.
     
     The tolerance for error is necessary as for performance reasons we avoid performing unnecessary frame assignments, but some windows (e.g., Terminal's windows) have some constraints on their size such that `frame` and `window.frame()` will differ by some small amount even if `frame` has been applied before. We want to treat that frame as equivalent if it is close enough so that we get the performance benefit.
     
     - Parameters:
         - frame: The frame to apply.
         - threshold: The error tolerance for what constitutes a new frame.
     */

    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize)

    /// Whether or not the window can be resized.
    func isResizable() -> Bool

    /**
     Applies a frame with the minimum number of accessibility calls: no read-back and no threshold checks.

     Intended only for intermediate frames during an animated reflow. The final frame must still be applied with `setFrame(_:withThreshold:)`, which handles the finicky accessibility behavior that this method deliberately skips.

     - Parameters:
         - frame: The frame to apply.
         - includingSize: Whether to apply the size as well as the position. Resizes force a relayout in the target application and are far more expensive than moves.
     */
    func setAnimationFrame(_ frame: CGRect, includingSize: Bool)

    /// Called once before a sequence of `setAnimationFrame(_:includingSize:)` calls.
    func beginAnimatedMovement()

    /// Called once after a sequence of `setAnimationFrame(_:includingSize:)` calls, whether or not the animation completed.
    func endAnimatedMovement()

    /// Whether or not the window is currently holding focus.
    func isFocused() -> Bool

    /// The process ID of the process that owns the window.
    func pid() -> pid_t

    /**
     The title of the window.
     
     - Note: Windows do not necessarily have titles so this can be `nil`.
     */
    func title() -> String?

    /// Whether or not the window should actually be managed by Amethyst.
    func shouldBeManaged() -> Bool

    /// Whether or not the window should float by default.
    func shouldFloat() -> Bool

    /// Whether or not the window is currently active.
    func isActive() -> Bool

    /**
     Focuses the window.
     
     - Returns:
     `true` if the window was successfully focused, `false` otherwise.
     */
    @discardableResult func focus() -> Bool

    @discardableResult func minimize() -> Bool

    /**
     Moves the window to a screen.
     
     This method takes into account the dimensions of the screen to ensure that the window actually fits onto it.
     
     - Parameters:
        - screen: The screen to move the window to.
     */
    func moveScaled(to screen: Screen)

    /// Whether or not the window is currently on any screen.
    func isOnScreen() -> Bool

    /**
     Moves the window to a space.
     
     - Parameters:
        - space: The index of the space.
     */
    func move(toSpace space: UInt)

    /**
     Moves the window to the space at an index.
     
     - Parameters:
        - space: The index of the space
     */
    func move(toSpaceAtIndex space: UInt)

    /**
     Moves the window to a space.
     
     - Parameters:
         - spaceID: The id of the space.
     */
    func move(toSpace spaceID: CGSSpaceID)
}

extension WindowType {
    func beginAnimatedMovement() {}
    func endAnimatedMovement() {}
}

enum WindowDecodingError: Error {
    case idNotFound
}

/**
 Final subclass of the Silica `SIWindow`.
 
 A final class is necessary for satisfying the `focusedWindow()` requirement in the `WindowType` protocol. Otherwise, as `SIWindow` is not final, the type system does not know how to constrain `Self`.
 */
final class AXWindow: SIWindow {
    /// One entry per animation currently registered with `EnhancedUserInterfaceSuppression` for this window, holding the
    /// application it registered with. Two screens can animate the same window object in turn when it is thrown between
    /// them; each begin registers, each end deregisters, and the two balance out.
    fileprivate var suppressedApplicationPIDs: [pid_t] = []
    /// Guards `suppressedApplicationPIDs`, which the reflow operations of different screens touch from their own queues.
    fileprivate static let suppressionLock = NSLock()
}

/**
 Keeps an application's enhanced user interface flag cleared for as long as any of its windows is being animated.

 The flag belongs to the application, not to a window. When windows of one application animate on several screens at once, each
 screen's operation begins and ends on its own, so the flag is cleared for the first window to begin and restored only when the
 last window ends. The flag is read and written under the lock so that two screens cannot interleave a clear and a restore.
 */
final class EnhancedUserInterfaceSuppression {
    static let shared = EnhancedUserInterfaceSuppression()

    private let lock = NSLock()
    private var animatingWindows: [pid_t: Int] = [:]
    private var clearedApplications: Set<pid_t> = []

    /**
     Registers a window of the application as animating.

     - Parameters:
         - pid: The application's process identifier.
         - clear: Invoked for the application's first animating window; clears the flag if it is set and returns whether it did.
     */
    func begin(for pid: pid_t, clear: () -> Bool) {
        lock.lock()
        defer { lock.unlock() }

        let count = (animatingWindows[pid] ?? 0) + 1
        animatingWindows[pid] = count

        if count == 1, clear() {
            clearedApplications.insert(pid)
        }
    }

    /**
     Registers that a window of the application has finished animating.

     - Parameters:
         - pid: The application's process identifier.
         - restore: Invoked when the application's last animating window ends and the flag had been cleared for it.
     */
    func end(for pid: pid_t, restore: () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        guard let count = animatingWindows[pid] else {
            return
        }

        guard count == 1 else {
            animatingWindows[pid] = count - 1
            return
        }

        animatingWindows[pid] = nil
        if clearedApplications.remove(pid) != nil {
            restore()
        }
    }
}

/**
 Identifier for `AXWindow` objects.
 
 - Note:
 Decoding for this object is very inefficient. Use it sparingly.
 */
final class AXWindowID: Hashable, Codable {
    /// Coding keys.
    private enum CodingKeys: String, CodingKey {
        /// The pid of the process that owns the window.
        case pid

        /// The CoreGraphics id for the window.
        case windowID
    }

    private let window: AXWindow
    private let pid: pid_t
    private let windowID: CGWindowID

    /// Equality for window IDs is based on the underlying CoreGraphics id and the owning pid, which (mostly) uniquely identifies a window.
    static func == (lhs: AXWindowID, rhs: AXWindowID) -> Bool {
        return lhs.pid == rhs.pid && lhs.windowID == rhs.windowID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(windowID)
    }

    fileprivate init(window: AXWindow) {
        self.window = window
        self.pid = window.pid()
        self.windowID = window.windowID()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pid = try container.decode(pid_t.self, forKey: .pid)
        let windowID = try container.decode(CGWindowID.self, forKey: .windowID)

        guard let application = SIApplication(pid: pid) else {
            throw WindowDecodingError.idNotFound
        }

        let windows: [SIWindow] = application.windows()

        guard let window = windows.first(where: { $0.windowID() == windowID }) else {
            throw WindowDecodingError.idNotFound
        }

        self.window = AXWindow(axElement: window.axElementRef)
        self.pid = pid
        self.windowID = windowID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pid, forKey: .pid)
        try container.encode(windowID, forKey: .windowID)
    }
}

extension AXWindowID: CustomStringConvertible {
    var description: String {
        return "\(window.title() ?? "unknown") (\(window.windowID()))"
    }
}

/// Conformance of `AXWindow` as an Amethyst window.
extension AXWindow: WindowType {
    typealias Screen = AMScreen
    typealias WindowID = AXWindowID

    /// Some assistive apps set this attribute on applications. Silica clears it around every frame change because it interferes with positioning; an animation keeps it cleared for as long as any of the application's windows is animating.
    private static let enhancedUserInterfaceKey = "AXEnhancedUserInterface" as CFString

    func setAnimationFrame(_ frame: CGRect, includingSize: Bool) {
        var origin = frame.origin
        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(axElementRef, kAXPositionAttribute as CFString, positionValue)
        }

        guard includingSize else {
            return
        }

        var size = frame.size
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axElementRef, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    func beginAnimatedMovement() {
        guard let application = app() else {
            return
        }

        let pid = application.processIdentifier()
        AXWindow.suppressionLock.lock()
        suppressedApplicationPIDs.append(pid)
        AXWindow.suppressionLock.unlock()
        EnhancedUserInterfaceSuppression.shared.begin(for: pid) {
            guard application.number(forKey: AXWindow.enhancedUserInterfaceKey)?.boolValue == true else {
                return false
            }

            application.setFlag(false, forKey: AXWindow.enhancedUserInterfaceKey)
            return true
        }
    }

    func endAnimatedMovement() {
        AXWindow.suppressionLock.lock()
        let pid = suppressedApplicationPIDs.popLast()
        AXWindow.suppressionLock.unlock()
        guard let pid = pid else {
            return
        }

        let application = app()
        EnhancedUserInterfaceSuppression.shared.end(for: pid) {
            application?.setFlag(true, forKey: AXWindow.enhancedUserInterfaceKey)
        }
    }

    /**
     Returns the currently focused window.
     
     - Returns:
     The currently focused window as an `AXWindow`.
     */
    static func currentlyFocused() -> AXWindow? {
        return SIWindow.focused().flatMap { AXWindow(axElement: $0.axElementRef) }
    }

    /**
     The Silica initializer is not failable because it can always assume it has a reference to an ax element. The window type in general does not make that assumption and thus has a failable initializer. This just ports one into the other.
     
     - Parameters:
        - element: The element representing a window.
     */
    convenience init?(element: SIAccessibilityElement?) {
        guard let axElementRef = element?.axElementRef else {
            return nil
        }

        self.init(axElement: axElementRef)

        if string(forKey: "AXRole" as CFString) != "AXWindow" {
            return nil
        }
    }

    func id() -> WindowID {
        return AXWindowID(window: self)
    }

    func cgID() -> CGWindowID {
        return windowID()
    }

    func screen() -> AMScreen? {
        // A window an animation is moving belongs to the screen animating it even while its frame lies elsewhere or, when
        // parked beyond every display, nowhere at all. Everything that routes hotkeys and focus by screen relies on this answer.
        if let animatingScreenID = AnimatingWindows.shared.screenID(for: cgID()), let screen = AMScreen.screen(withID: animatingScreenID) {
            return screen
        }

        let nsScreen: NSScreen? = screen()
        return nsScreen.flatMap { AMScreen(screen: $0) }
    }

    func pid() -> pid_t {
        // Some window operations can surface elements owned by a helper process.
        // Use AXParent's PID when available so identity checks stay stable.
        return forKey("AXParent" as CFString)?.processIdentifier() ?? processIdentifier()
    }

    /**
     Whether or not the window should actually be managed by Amethyst.
     
     In this case the window must be movable and be a standard window.
     */
    func shouldBeManaged() -> Bool {
        guard isMovable() else {
            return false
        }

        guard let subrole = string(forKey: kAXSubroleAttribute as CFString), subrole == kAXStandardWindowSubrole as String else {
            return false
        }

        return true
    }

    func shouldFloat() -> Bool {
        let userConfiguration = UserConfiguration.shared
        let frame = self.frame()
        let threshold = userConfiguration.smallWindowSize()

        if userConfiguration.floatSmallWindows() && frame.size.width < threshold && frame.size.height < threshold {
            return true
        }

        return false
    }

    func isFocused() -> Bool {
        guard let focused = AXWindow.currentlyFocused() else {
            return false
        }

        return isEqual(to: focused)
    }

    /**
     Focuses the window.
     
     This handles focusing and also moves the cursor to the window's frame if mouse-follows-focus is enabled.
     
     - Returns:
     `true` if the window was successfully focused, `false` otherwise.
     
     - Description:
     What a mess. See: https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
     */
    @discardableResult override func focus() -> Bool {
        let pid = self.pid()
        var wid = self.cgID()
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            return false
        }

        var cgStatus = _SLPSSetFrontProcessWithOptions(&psn, wid, kCPSUserGenerated)

        guard cgStatus == .success else {
            return false
        }

        for byte in [0x01, 0x02] {
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xF8
            bytes[0x08] = UInt8(byte)
            bytes[0x3a] = 0x10
            memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
            memset(&bytes[0x20], 0xFF, 0x10)
            cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
                return SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
            }
            guard cgStatus == .success else {
                return false
            }
        }

        guard super.raise() else {
            return false
        }

        guard UserConfiguration.shared.mouseFollowsFocus() else {
            return true
        }

        let windowFrame = frame()
        let mouseCursorPoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) else {
            return true
        }
        mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)

        return true
    }

    @discardableResult func minimize() -> Bool {
        super.minimize()
        return isWindowMinimized()
    }

    func moveScaled(to screen: Screen) {
        let screenFrame = screen.frameWithoutDockOrMenu()
        let currentFrame = frame()
        var scaledFrame = currentFrame

        if scaledFrame.width > screenFrame.width {
            scaledFrame.size.width = screenFrame.width
        }

        if scaledFrame.height > screenFrame.height {
            scaledFrame.size.height = screenFrame.height
        }

        if scaledFrame != currentFrame {
            setFrame(scaledFrame)
        }

        move(to: screen.screen)
    }

    func move(toSpaceAtIndex space: UInt) {
        super.move(toSpace: space)
    }

    func move(toSpace spaceID: CGSSpaceID) {
    }
}

extension AXWindow {
    override var description: String {
        return "\(super.description) (\(cgID()))"
    }
}
