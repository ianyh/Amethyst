//
//  CustomLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/2/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

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
        return ""
    }

    private let key: String
    private let fileURL: URL

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
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        return []
    }
}
