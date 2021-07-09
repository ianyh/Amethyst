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
        return self.context?.objectForKeyedSubscript("layout")
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

        guard
            let frameAssignmentsValue = getFrameAssignments.call(withArguments: [jsWindowsArg, jsScreenFrameArg]),
            frameAssignmentsValue.isObject
        else {
            return nil
        }

        let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
        return jsWindows.compactMap { jsWindow in
            guard let frame = frameAssignmentsValue.objectForKeyedSubscript(jsWindow.id)?.toRect() else {
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
}
