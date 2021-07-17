//
//  CustomLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/2/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

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

class CustomLayout<Window: WindowType>: Layout<Window> {
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
        return layout?.objectForKeyedSubscript("name").toString() ?? ""
    }

    private let key: String
    private let fileURL: URL

    private lazy var context: JSContext? = {
        guard let context = JSContext() else {
            return nil
        }

        do {
            context.evaluateScript(try String(contentsOf: self.fileURL))
        } catch {
            return nil
        }

        return context
    }()

    private lazy var layout: JSValue? = {
        return self.context?.objectForKeyedSubscript("layout")?.call(withArguments: [])
    }()

    private lazy var state: JSValue? = {
        return self.layout?.objectForKeyedSubscript("initialState")
    }()

    private lazy var commands: JSValue? = {
        return self.layout?.objectForKeyedSubscript("commands")
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

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        guard
            let getFrameAssignments = layout?.objectForKeyedSubscript("getFrameAssignments"),
            !getFrameAssignments.isNull && !getFrameAssignments.isUndefined
        else {
            return nil
        }

        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let jsScreenFrameArg = JSValue(rect: screenFrame, in: context)!

        let jsWindows = windows.map { JSWindow<Window>(id: UUID().uuidString, window: $0) }
        let jsWindowsArg = jsWindows.map { ["id": $0.id, "window": $0] }

        let args: [Any]
        if let state = state {
            args = [jsWindowsArg, jsScreenFrameArg, state]
        } else {
            args = [jsWindowsArg, jsScreenFrameArg]
        }

        guard
            let frameAssignmentsValue = getFrameAssignments.call(withArguments: args),
            frameAssignmentsValue.isObject
        else {
            return nil
        }

        let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
        return jsWindows.compactMap { jsWindow in
            guard let frame = frameAssignmentsValue.objectForKeyedSubscript(jsWindow.id)?.toRoundedRect() else {
                return nil
            }

            let frameAssignment = FrameAssignment<Window>(
                frame: frame,
                window: jsWindow.window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )
            return FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet)
        }
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

    private func command(key: String) {
        guard let command = commands?.objectForKeyedSubscript(key), command.isObject else {
            log.debug("\(layoutKey) — \(key): no command defined")
            return
        }

        guard let updateState = command.objectForKeyedSubscript("updateState"), !updateState.isNull && !updateState.isUndefined else {
            log.debug("\(layoutKey) — \(key): no updateState function provided")
            return
        }

        guard let updatedState = updateState.call(withArguments: state.flatMap { [$0] } ?? []), !updateState.isNull && !updateState.isUndefined else {
            log.error("\(layoutKey) — \(key): received invalid updated state")
            return
        }

        state = updatedState
    }
}
