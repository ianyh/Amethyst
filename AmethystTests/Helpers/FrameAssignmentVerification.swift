//
//  FrameAssignmentVerification.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/21/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble

extension RandomAccessCollection where Element == FrameAssignment<TestWindow>, Index == Int {
    typealias Window = TestWindow

    func filtered(byIDs ids: [CGWindowID]) -> [Element] {
        return filter { ids.contains($0.window.id) }
    }

    func forWindows<C: RandomAccessCollection>(_ windows: C) -> [Element] where C.Element == Window, C.Index == Index {
        let convertedWindows = Array(windows)
        guard convertedWindows.count > 1 else {
            return filtered(byIDs: [convertedWindows[0].windowID()]).sorted()
        }
        return filtered(byIDs: convertedWindows.map { $0.windowID() }).sorted()
    }

    func sorted() -> [FrameAssignment<TestWindow>] {
        return sorted { $0.frame.origin.x < $1.frame.origin.x }.sorted { $0.frame.origin.y < $1.frame.origin.y }
    }

    func verify(frames: [CGRect]) {
        expect(self.count).to(equal(frames.count), description: "assignments and frames should be same length")
        zip(self, frames).forEach { assignment, frame in
            expect(assignment.frame).to(equal(frame))
        }
    }
}
