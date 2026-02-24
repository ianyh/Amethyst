//
//  CustomLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/2/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import CommonCrypto
import Foundation
import JavaScriptCore

private struct JSWindow<Window: WindowType> {
    let id: String
    let window: LayoutWindow<Window>
}

private extension JSValue {
    func toRoundedRect() -> CGRect {
        let rect = toRect()
        return CGRect(x: round(rect.origin.x), y: round(rect.origin.y), width: round(rect.width), height: round(rect.height))
    }
}

private enum LayoutExtension<Window: WindowType> {
    case none
    case layout(Layout<Window>)
}

class CustomLayout<Window: WindowType>: StatefulLayout<Window>, PanedLayout {
    typealias WindowID = Window.WindowID

    private enum CodingKeys: String, CodingKey {
        case key
        case fileURL
    }

    override static var layoutName: String { return "Custom" }
    override static var layoutKey: String { return "custom" }

    override var layoutKey: String {
        return key
    }

    override var layoutName: String {
        return layout?.objectForKeyedSubscript("name").toString() ?? layoutKey
    }

    var mainPaneRatio: CGFloat { return 1.0 }
    var mainPaneCount: Int { return 1 }

    private let key: String
    private let fileURL: URL
    private var windowIDs: [WindowID] = []

    private lazy var context: JSContext? = {
        guard let context = JSContext() else {
            log.error("Failed to create javascript context")
            return nil
        }

        context.exceptionHandler = { (_: JSContext!, value: JSValue!) in
            let name = value.objectForKeyedSubscript("name").toString() ?? ""
            let message = value.objectForKeyedSubscript("message").toString() ?? ""
            let stack = value.objectForKeyedSubscript("stack").toString() ?? ""
            log.error("\(name): \(message)\n\(stack)")
        }

        context.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")

        let consoleLog: @convention(block) (String) -> Void = { message in
            log.debug(message)
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self), forKeyedSubscript: "_consoleLog" as (NSCopying & NSObjectProtocol))

        do {
            context.evaluateScript(try String(contentsOf: self.fileURL))
        } catch {
            log.error(error)
            return nil
        }

        context.evaluateScript("""
        function sanitizeArguments(fn) {
            return function(...args) {
                const sanitizedArgs = args.map(arg => !!arg ? JSON.parse(JSON.stringify(arg)) : undefined);
                return fn(...sanitizedArgs);
            };
        }

        function normalizedLayout() {
            const l = layout();
            l.getFrameAssignments = sanitizeArguments(l.getFrameAssignments);
            return l;
        }
        """)

        return context
    }()

    private lazy var layout: JSValue? = {
        return self.context?.objectForKeyedSubscript("normalizedLayout")?.call(withArguments: [])
    }()

    private lazy var state: JSValue? = {
        return self.layout?.objectForKeyedSubscript("initialState")
    }()

    private lazy var commands: JSValue? = {
        return self.layout?.objectForKeyedSubscript("commands")
    }()

    private lazy var layoutExtension: LayoutExtension<Window> = {
        guard let extendedLayoutKey = self.layout?.objectForKeyedSubscript("extends"), extendedLayoutKey.isString else {
            return .none
        }

        guard let layout = LayoutType<Window>.layoutForKey(extendedLayoutKey.toString()) else {
            return .none
        }

        return .layout(layout)
    }()

    required init() {
        fatalError("must be constructed with a file")
    }

    required init(key: String, fileURL: URL) {
        self.key = key
        self.fileURL = fileURL
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try values.decode(String.self, forKey: .key)
        self.fileURL = try values.decode(URL.self, forKey: .fileURL)
        super.init()
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(fileURL, forKey: .fileURL)
    }

    private func extendedFrameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        switch layoutExtension {
        case .none:
            return nil
        case .layout(let layout):
            return layout.frameAssignments(windowSet, on: screen)
        }
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows
        windowIDs = windows.map { $0.id }

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let jsScreenFrameArg = JSValue(rect: screenFrame, in: context)!
        let jsWindows: [WindowID: JSWindow<Window>] = windows.reduce([:]) { partialResult, layoutWindow in
            let id = idHash(forWindowID: layoutWindow.id) ?? UUID().uuidString
            let window = JSWindow<Window>(id: id, window: layoutWindow)
            return partialResult.merging([layoutWindow.id: window]) { current, _ in return current }
        }
        let jsWindowsArg = windows.map { window -> [String: Any?] in
            let jsWindow = jsWindows[window.id]!
            return [
                "id": jsWindow.id,
                "frame": JSValue(rect: jsWindow.window.frame, in: context),
                "isFocused": jsWindow.window.isFocused
            ]
        }

        let extendedFrames: [[String: Any?]]? = extendedFrameAssignments(windowSet, on: screen)?.compactMap { frameAssignmentOperation in
            let frameAssignment = frameAssignmentOperation.frameAssignment
            guard let jsWindow = jsWindows[frameAssignment.window.id] else {
                return nil
            }
            return [
                "id": jsWindow.id,
                "frame": JSValue(rect: frameAssignment.frame, in: context),
                "isFocused": jsWindow.window.isFocused
            ]
        }
        let args: [Any] = [
            jsWindowsArg,
            jsScreenFrameArg,
            state ?? JSValue(undefinedIn: context)!,
            extendedFrames ?? JSValue(undefinedIn: context)!
        ]

        guard let getAssignments = layout?.objectForKeyedSubscript("getFrameAssignments"), !getAssignments.isNull && !getAssignments.isUndefined else {
            return nil
        }

        guard let assignments = getAssignments.call(withArguments: args), assignments.isObject else {
            return nil
        }

        // If getFrameAssignments returns a 'state' property, update our state.
        // This is a workaround/extension to ensure state persistence if in-place modification fails.
        if let newState = assignments.objectForKeyedSubscript("state"), !newState.isUndefined && !newState.isNull {
             state = newState
        }

        return windows.compactMap { window -> FrameAssignmentOperation<Window>? in
            guard let jsWindow = jsWindows[window.id] else {
                return nil
            }

            guard let frame = assignments.objectForKeyedSubscript(jsWindow.id) else {
                return nil
            }

            var unconstrainedDimension: UnconstrainedDimension = .horizontal
            var scaleFactor = screenFrame.width / frame.toRoundedRect().width

            if let dimension = frame.objectForKeyedSubscript("unconstrainedDimension")?.toString() {
                switch dimension {
                case "horizontal":
                    unconstrainedDimension = .horizontal
                case "vertical":
                    unconstrainedDimension = .vertical
                    scaleFactor = screenFrame.height / frame.toRoundedRect().height
                default:
                    log.warning("Encountered unknown unconstrainedDimension value: \(dimension), defaulting to horizontal")
                    unconstrainedDimension = .horizontal
                }
            }

            let isMain = frame.objectForKeyedSubscript("isMain")?.toBool() ?? true
            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: unconstrainedDimension, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment<Window>(
                frame: frame.toRoundedRect(),
                window: jsWindow.window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )
            return FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet)
        }
    }

    override func updateWithChange(_ windowChange: Change<Window>) {
        guard let updateWithChange = layout?.objectForKeyedSubscript("updateWithChange"), !updateWithChange.isNull && !updateWithChange.isUndefined else {
            return
        }

        let updateWithChangeArgs: [Any]? = state.flatMap { state in
            return [jsChange(forChange: windowChange), state]
        }

        guard let updatedState = updateWithChange.call(withArguments: updateWithChangeArgs ?? []), !updatedState.isNull && !updatedState.isUndefined else {
            log.error("\(layoutKey)): received invalid updated state")
            return
        }

        state = updatedState
    }

    func command1() {
        command(key: "command1")
    }

    func command2() {
        command(key: "command2")
    }

    func command3() {
        command(key: "command3")
    }

    func command4() {
        command(key: "command4")
    }

    override func nextWindowIDClockwise() -> Window.WindowID? {
        guard let focusedWindow = Window.currentlyFocused() else { return nil }
        let focusedID = focusedWindow.id()
        guard let index = windowIDs.firstIndex(of: focusedID) else { return nil }
        let nextIndex = (index + 1) % windowIDs.count
        return windowIDs[nextIndex]
    }

    override func nextWindowIDCounterClockwise() -> Window.WindowID? {
        guard let focusedWindow = Window.currentlyFocused() else { return nil }
        let focusedID = focusedWindow.id()
        guard let index = windowIDs.firstIndex(of: focusedID) else { return nil }
        let nextIndex = (index - 1 + windowIDs.count) % windowIDs.count
        return windowIDs[nextIndex]
    }

    private func command(key: String) {
        guard let command = commands?.objectForKeyedSubscript(key), command.isObject else {
            log.debug("\(layoutKey) — \(key): no command defined")
            return
        }

        guard let updateState = command.objectForKeyedSubscript("updateState"), !updateState.isNull && !updateState.isUndefined else {
            log.debug("\(layoutKey) — \(key): no updateState function provided")
            return
        }

        let focusedWindowID = Window.currentlyFocused().flatMap { idHash(forWindowID: $0.id()) }
        let updateStateArgs: [Any]? = state.flatMap { state in
            if let id = focusedWindowID {
                return [state, id]
            } else {
                return [state]
            }
        }

        guard let updatedState = updateState.call(withArguments: updateStateArgs ?? []), !updatedState.isNull && !updatedState.isUndefined else {
            log.error("\(layoutKey) — \(key): received invalid updated state")
            return
        }

        state = updatedState
    }

    private func idHash(forWindowID windowID: WindowID) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            let encodedID = try encoder.encode(windowID)
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            encodedID.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(encodedID.count), &hash)
            }
            return hash.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            log.warning("Failed to hash window id: \(error)")
            return nil
        }
    }

    private func jsChange(forChange change: Change<Window>) -> [String: String] {
        var jsChange: [String: String] = [:]

        switch change {
        case .add(window: let window):
            jsChange["change"] = "add"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .remove(window: let window):
            jsChange["change"] = "remove"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .focusChanged(window: let window):
            jsChange["change"] = "focus_changed"
            jsChange["windowID"] = idHash(forWindowID: window.id())
        case .windowSwap(window: let window, otherWindow: let otherWindow):
            jsChange["change"] = "window_swap"
            jsChange["windowID"] = idHash(forWindowID: window.id())
            jsChange["otherWindowID"] = idHash(forWindowID: otherWindow.id())
        case .applicationActivate:
            jsChange["change"] = "application_activate"
        case .applicationDeactivate:
            jsChange["change"] = "application_deactivate"
        case .spaceChange:
            jsChange["change"] = "space_change"
        case .layoutChange:
            jsChange["change"] = "layout_change"
        case .tabChange:
            jsChange["change"] = "tab_change"
        case .unknown:
            jsChange["change"] = "unknown"
        case .none:
            jsChange["change"] = "none"
        }

        return jsChange
    }

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        guard
            let recommendMainPaneRatio = layout?.objectForKeyedSubscript("recommendMainPaneRatio"),
            !recommendMainPaneRatio.isNull && !recommendMainPaneRatio.isUndefined
        else {
            return
        }

        let recommendMainPaneRatioArgs: [Any]? =  state.flatMap { [rawRatio, $0] }

        guard let updatedState = recommendMainPaneRatio.call(withArguments: recommendMainPaneRatioArgs ?? []), !updatedState.isNull && !updatedState.isUndefined else {
            log.error("\(layoutKey) — recommendMainPaneRawRatio: received invalid updated state")
            return
        }

        state = updatedState
    }

    func increaseMainPaneCount() {
        command(key: "increaseMain")
    }

    func decreaseMainPaneCount() {
        command(key: "decreaseMain")
    }

    func shrinkMainPane() {
        command(key: "shrinkMain")
    }

    func expandMainPane() {
        command(key: "expandMain")
    }

    // Allow native code to invoke an arbitrary command defined in the JS `commands` object.
    func performCommand(_ key: String) {
        log.debug("\(layoutKey) — performCommand called with key: \(key)")
        command(key: key)
    }

    // Find and focus window in direction using current positions
    func focusWindow(inDirection direction: String, windowSet: WindowSet<Window>, on screen: Screen) {
        guard let focusedWindow = Window.currentlyFocused() else {
            return
        }

        guard let assignments = frameAssignments(windowSet, on: screen) else {
            return
        }

        let focusedFrame = focusedWindow.frame()
        let focusedCenter = CGPoint(x: focusedFrame.midX, y: focusedFrame.midY)

        var candidates: [(window: LayoutWindow<Window>, overlap: CGFloat, distance: CGFloat)] = []

        for assignment in assignments {
            let window = assignment.frameAssignment.window
            if window.id == focusedWindow.id() {
                continue
            }

            let frame = assignment.frameAssignment.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)

            var isCandidate = false
            var overlap: CGFloat = 0
            var distance: CGFloat = 0

            switch direction {
            case "left":
                isCandidate = center.x < focusedCenter.x
                if isCandidate {
                    overlap = max(0, min(frame.maxY, focusedFrame.maxY) - max(frame.minY, focusedFrame.minY))
                    distance = focusedFrame.minX - frame.maxX
                }
            case "right":
                isCandidate = center.x > focusedCenter.x
                if isCandidate {
                    overlap = max(0, min(frame.maxY, focusedFrame.maxY) - max(frame.minY, focusedFrame.minY))
                    distance = frame.minX - focusedFrame.maxX
                }
            case "up":
                isCandidate = center.y < focusedCenter.y
                if isCandidate {
                    overlap = max(0, min(frame.maxX, focusedFrame.maxX) - max(frame.minX, focusedFrame.minX))
                    distance = focusedFrame.minY - frame.maxY
                }
            case "down":
                isCandidate = center.y > focusedCenter.y
                if isCandidate {
                    overlap = max(0, min(frame.maxX, focusedFrame.maxX) - max(frame.minX, focusedFrame.minX))
                    distance = frame.minY - focusedFrame.maxY
                }
            default:
                break
            }

            if isCandidate {
                candidates.append((window, overlap, max(0, distance)))
            }
        }

        candidates.sort { (lhs, rhs) -> Bool in
            if abs(lhs.overlap - rhs.overlap) > 1.0 {
                return lhs.overlap > rhs.overlap
            }
            return lhs.distance < rhs.distance
        }

        if let bestCandidate = candidates.first, let window = windowSet.window(forID: bestCandidate.window.id) {
            window.focus()
        }
    }

    // Find and swap window in direction using current positions
    func swapWindow(inDirection direction: String, windowSet: WindowSet<Window>, on screen: Screen) {
        guard let focusedWindow = Window.currentlyFocused() else {
            return
        }
        guard let assignments = frameAssignments(windowSet, on: screen) else {
            return
        }

        let focusedFrame = focusedWindow.frame()
        let focusedCenter = CGPoint(x: focusedFrame.midX, y: focusedFrame.midY)

        var candidates: [(window: LayoutWindow<Window>, overlap: CGFloat, distance: CGFloat)] = []

        for assignment in assignments {
            let window = assignment.frameAssignment.window
            if window.id == focusedWindow.id() {
                continue
            }

            let frame = assignment.frameAssignment.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)

            var isCandidate = false
            var overlap: CGFloat = 0
            var distance: CGFloat = 0

            switch direction {
            case "left":
                isCandidate = center.x < focusedCenter.x
                if isCandidate {
                    overlap = max(0, min(frame.maxY, focusedFrame.maxY) - max(frame.minY, focusedFrame.minY))
                    distance = focusedFrame.minX - frame.maxX
                }
            case "right":
                isCandidate = center.x > focusedCenter.x
                if isCandidate {
                    overlap = max(0, min(frame.maxY, focusedFrame.maxY) - max(frame.minY, focusedFrame.minY))
                    distance = frame.minX - focusedFrame.maxX
                }
            case "up":
                isCandidate = center.y < focusedCenter.y
                if isCandidate {
                    overlap = max(0, min(frame.maxX, focusedFrame.maxX) - max(frame.minX, focusedFrame.minX))
                    distance = focusedFrame.minY - frame.maxY
                }
            case "down":
                isCandidate = center.y > focusedCenter.y
                if isCandidate {
                    overlap = max(0, min(frame.maxX, focusedFrame.maxX) - max(frame.minX, focusedFrame.minX))
                    distance = frame.minY - focusedFrame.maxY
                }
            default:
                break
            }

            if isCandidate {
                candidates.append((window, overlap, max(0, distance)))
            }
        }

        candidates.sort { (lhs, rhs) -> Bool in
            if abs(lhs.overlap - rhs.overlap) > 1.0 {
                return lhs.overlap > rhs.overlap
            }
            return lhs.distance < rhs.distance
        }

        if let bestCandidate = candidates.first {
            performSwap(sourceID: focusedWindow.id(), targetID: bestCandidate.window.id)
        }
    }

    private func performSwap(sourceID: Window.WindowID, targetID: Window.WindowID) {
        let commandKey = "swap"
        guard let command = commands?.objectForKeyedSubscript(commandKey), command.isObject else {
            return
        }

        guard let updateState = command.objectForKeyedSubscript("updateState"), !updateState.isNull && !updateState.isUndefined else {
            return
        }

        guard let sourceIDHash = idHash(forWindowID: sourceID), let targetIDHash = idHash(forWindowID: targetID) else {
            return
        }

        let updateStateArgs: [Any]? = state.flatMap { state in
            return [state, sourceIDHash, targetIDHash]
        }

        guard let updatedState = updateState.call(withArguments: updateStateArgs ?? []), !updatedState.isNull && !updatedState.isUndefined else {
            return
        }

        state = updatedState
    }
}
