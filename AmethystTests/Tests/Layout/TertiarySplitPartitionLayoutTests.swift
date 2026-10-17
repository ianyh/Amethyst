//
//  TertiarySplitPartitionLayoutTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 9/29/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class TertiarySplitPartitionLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        /// A screen of the given size and `windowCount` windows ready to lay out on it.
        func fixture(width: CGFloat, height: CGFloat, windowCount: Int, origin: CGPoint = .zero) -> (screen: TestScreen, windows: [TestWindow], windowSet: WindowSet<TestWindow>) {
            let screen = TestScreen(frame: CGRect(origin: origin, size: CGSize(width: width, height: height)))
            TestScreen.availableScreens = [screen]

            let windows = (0..<windowCount).map { _ in TestWindow(element: nil)! }
            let layoutWindows = windows.map {
                LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
            }
            let windowSet = WindowSet<TestWindow>(
                windows: layoutWindows,
                isWindowWithIDActive: { _ in return true },
                isWindowWithIDFloating: { _ in return false },
                windowForID: { id in return windows.first { $0.id() == id } }
            )
            return (screen, windows, windowSet)
        }

        /// The expected frame of each window, keyed by window, in the order the windows were created.
        func expected(_ windows: [TestWindow], _ frames: [CGRect]) -> [String: CGRect] {
            return Dictionary(uniqueKeysWithValues: zip(windows.map { $0.id() }, frames))
        }

        describe("split tree") {
            it("numbers the sides of each node level by level") {
                let root = TertiarySplitNode.root
                expect(root.level).to(equal(0))
                expect(root.firstSide.number).to(equal(1))
                expect(root.secondSide.number).to(equal(2))

                let node1 = TertiarySplitNode(number: 1)
                expect(node1.level).to(equal(1))
                expect(node1.firstSide.number).to(equal(3))
                expect(node1.secondSide.number).to(equal(5))

                let node2 = TertiarySplitNode(number: 2)
                expect(node2.firstSide.number).to(equal(4))
                expect(node2.secondSide.number).to(equal(6))

                let node3 = TertiarySplitNode(number: 3)
                expect(node3.level).to(equal(2))
                expect(node3.firstSide.number).to(equal(7))
                expect(node3.secondSide.number).to(equal(11))

                let node6 = TertiarySplitNode(number: 6)
                expect(node6.firstSide.number).to(equal(10))
                expect(node6.secondSide.number).to(equal(14))

                let node7 = TertiarySplitNode(number: 7)
                expect(node7.level).to(equal(3))
                expect(node7.firstSide.number).to(equal(15))
                expect(node7.secondSide.number).to(equal(23))
            }
        }

        describe("wide screen") {
            it("gives the first window the whole screen") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 1)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 0, y: 0, width: 2700, height: 1350)
                ]))
            }

            it("gives the second window the left third") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 2)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 1800, height: 1350),
                    CGRect(x: 0, y: 0, width: 900, height: 1350)
                ]))
            }

            it("gives the third window the right third") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 3)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 0, width: 900, height: 1350),
                    CGRect(x: 1800, y: 0, width: 900, height: 1350)
                ]))
            }

            it("divides the second window's pane for the fourth window, in rows because that pane is tall, top first") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 4)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 450, width: 900, height: 900),
                    CGRect(x: 1800, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 0, width: 900, height: 450)
                ]))
            }

            it("fills the side panes level by level, choosing each split's direction from the pane's shape") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 8)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 450, width: 900, height: 450),
                    CGRect(x: 1800, y: 450, width: 900, height: 450),
                    CGRect(x: 300, y: 0, width: 600, height: 450),
                    CGRect(x: 1800, y: 0, width: 900, height: 450),
                    CGRect(x: 0, y: 900, width: 900, height: 450),
                    CGRect(x: 1800, y: 900, width: 900, height: 450),
                    CGRect(x: 0, y: 0, width: 300, height: 450)
                ]))
            }

            it("handles non-origin screens") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 3, origin: CGPoint(x: 100, y: 200))
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 1000, y: 200, width: 900, height: 1350),
                    CGRect(x: 100, y: 200, width: 900, height: 1350),
                    CGRect(x: 1900, y: 200, width: 900, height: 1350)
                ]))
            }
        }

        describe("tall screen") {
            it("puts the second window at the top and the third at the bottom") {
                let (screen, windows, windowSet) = fixture(width: 1350, height: 2700, windowCount: 3)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 0, y: 900, width: 1350, height: 900),
                    CGRect(x: 0, y: 0, width: 1350, height: 900),
                    CGRect(x: 0, y: 1800, width: 1350, height: 900)
                ]))
            }

            it("divides a wide side pane into columns") {
                let (screen, windows, windowSet) = fixture(width: 1350, height: 2700, windowCount: 4)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 0, y: 900, width: 1350, height: 900),
                    CGRect(x: 450, y: 0, width: 900, height: 900),
                    CGRect(x: 0, y: 1800, width: 1350, height: 900),
                    CGRect(x: 0, y: 0, width: 450, height: 900)
                ]))
            }
        }

        describe("square screen") {
            it("divides into rows") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 2700, windowCount: 2)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 0, y: 900, width: 2700, height: 1800),
                    CGRect(x: 0, y: 0, width: 2700, height: 900)
                ]))
            }
        }

        describe("main pane count") {
            it("stacks main windows across the split and moves the rest outward") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 4)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 675),
                    CGRect(x: 900, y: 675, width: 900, height: 675),
                    CGRect(x: 0, y: 0, width: 900, height: 1350),
                    CGRect(x: 1800, y: 0, width: 900, height: 1350)
                ]))

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 1800, height: 450),
                    CGRect(x: 900, y: 450, width: 1800, height: 450),
                    CGRect(x: 900, y: 900, width: 1800, height: 450),
                    CGRect(x: 0, y: 0, width: 900, height: 1350)
                ]))

                layout.decreaseMainPaneCount()
                layout.decreaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 450, width: 900, height: 900),
                    CGRect(x: 1800, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 0, width: 900, height: 450)
                ]))

                layout.decreaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))
            }

            it("places main windows side by side on a tall screen") {
                let (screen, windows, windowSet) = fixture(width: 1350, height: 2700, windowCount: 3)
                let layout = TertiarySplitPartitionLayout<TestWindow>()
                layout.increaseMainPaneCount()

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 0, y: 900, width: 675, height: 1800),
                    CGRect(x: 675, y: 900, width: 675, height: 1800),
                    CGRect(x: 0, y: 0, width: 1350, height: 900)
                ]))
            }
        }

        describe("main pane ratio") {
            it("changes the main pane's share and leaves the side panes divided into thirds") {
                let (screen, windows, windowSet) = fixture(width: 2700, height: 1350, windowCount: 7)
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                _ = layout.frameAssignments(windowSet, on: screen)
                layout.recommendMainPaneRatio(0.5)
                expect(layout.mainPaneRatio).to(equal(0.5))

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.verify(frames: expected(windows, [
                    CGRect(x: 675, y: 0, width: 1350, height: 1350),
                    CGRect(x: 0, y: 450, width: 675, height: 450),
                    CGRect(x: 2025, y: 450, width: 675, height: 450),
                    CGRect(x: 0, y: 0, width: 675, height: 450),
                    CGRect(x: 2025, y: 0, width: 675, height: 450),
                    CGRect(x: 0, y: 900, width: 675, height: 450),
                    CGRect(x: 2025, y: 900, width: 675, height: 450)
                ]))
            }

            it("reads a recommendation as the share of the screen the main pane should show") {
                let layout = TertiarySplitPartitionLayout<TestWindow>()

                let two = fixture(width: 2700, height: 1350, windowCount: 2)
                _ = layout.frameAssignments(two.windowSet, on: two.screen)
                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.5))

                var frameAssignments = layout.frameAssignments(two.windowSet, on: two.screen)!
                frameAssignments.verify(frames: expected(two.windows, [
                    CGRect(x: 675, y: 0, width: 2025, height: 1350),
                    CGRect(x: 0, y: 0, width: 675, height: 1350)
                ]))

                let three = fixture(width: 2700, height: 1350, windowCount: 3)
                _ = layout.frameAssignments(three.windowSet, on: three.screen)
                layout.recommendMainPaneRatio(1.0 / 3.0)
                expect(layout.mainPaneRatio).to(equal(1.0 / 3.0))

                frameAssignments = layout.frameAssignments(three.windowSet, on: three.screen)!
                frameAssignments.verify(frames: expected(three.windows, [
                    CGRect(x: 900, y: 0, width: 900, height: 1350),
                    CGRect(x: 0, y: 0, width: 900, height: 1350),
                    CGRect(x: 1800, y: 0, width: 900, height: 1350)
                ]))
            }

            it("keeps a window at the size a drag left it in either orientation") {
                let defaults = UserDefaults.standard
                let savedMargins = defaults.object(forKey: "window-margins")
                defaults.set(false, forKey: "window-margins")
                defer { defaults.set(savedMargins, forKey: "window-margins") }

                let wide = fixture(width: 2700, height: 1350, windowCount: 2)
                let wideLayout = TertiarySplitPartitionLayout<TestWindow>()
                var assignments = wideLayout.frameAssignments(wide.windowSet, on: wide.screen)!

                let mainAssignment = assignments.forWindows(wide.windows[..<1])[0].frameAssignment
                expect(mainAssignment.resizeRules.unconstrainedDimension).to(equal(.horizontal))
                let draggedMain = CGRect(x: 675, y: 0, width: 2025, height: 1350)
                wideLayout.recommendMainPaneRatio(mainAssignment.impliedMainPaneRatio(windowFrame: draggedMain))

                assignments = wideLayout.frameAssignments(wide.windowSet, on: wide.screen)!
                assignments.forWindows(wide.windows[..<1]).verify(frames: [draggedMain])

                let sideAssignment = assignments.forWindows(wide.windows[1...])[0].frameAssignment
                let draggedSide = CGRect(x: 0, y: 0, width: 900, height: 1350)
                wideLayout.recommendMainPaneRatio(sideAssignment.impliedMainPaneRatio(windowFrame: draggedSide))

                assignments = wideLayout.frameAssignments(wide.windowSet, on: wide.screen)!
                assignments.forWindows(wide.windows[1...]).verify(frames: [draggedSide])

                let tall = fixture(width: 1350, height: 2700, windowCount: 2)
                let tallLayout = TertiarySplitPartitionLayout<TestWindow>()
                assignments = tallLayout.frameAssignments(tall.windowSet, on: tall.screen)!

                let tallMainAssignment = assignments.forWindows(tall.windows[..<1])[0].frameAssignment
                expect(tallMainAssignment.resizeRules.unconstrainedDimension).to(equal(.vertical))
                let draggedTallMain = CGRect(x: 0, y: 675, width: 1350, height: 2025)
                tallLayout.recommendMainPaneRatio(tallMainAssignment.impliedMainPaneRatio(windowFrame: draggedTallMain))

                assignments = tallLayout.frameAssignments(tall.windowSet, on: tall.screen)!
                assignments.forWindows(tall.windows[..<1]).verify(frames: [draggedTallMain])
            }

            it("moves by the resize step from the hotkeys regardless of window count") {
                let defaults = UserDefaults.standard
                let savedStep = defaults.object(forKey: "window-resize-step")
                defaults.set(10, forKey: "window-resize-step")
                defer { defaults.set(savedStep, forKey: "window-resize-step") }

                let (screen, _, windowSet) = fixture(width: 2700, height: 1350, windowCount: 2)
                let layout = TertiarySplitPartitionLayout<TestWindow>()
                _ = layout.frameAssignments(windowSet, on: screen)

                layout.expandMainPane()
                expect(layout.mainPaneRatio).to(beCloseTo(1.0 / 3.0 + 0.1))

                layout.shrinkMainPane()
                layout.shrinkMainPane()
                expect(layout.mainPaneRatio).to(beCloseTo(1.0 / 3.0 - 0.1))
            }
        }

        describe("coding") {
            it("encodes and decodes") {
                let layout = TertiarySplitPartitionLayout<TestWindow>()
                layout.increaseMainPaneCount()
                layout.recommendMainPaneRatio(0.45)

                expect(layout.mainPaneCount).to(equal(2))
                expect(layout.mainPaneRatio).to(equal(0.45))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(TertiarySplitPartitionLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout.mainPaneCount).to(equal(2))
                expect(decodedLayout.mainPaneRatio).to(equal(0.45))
            }
        }

        describe("registration") {
            it("is a standard layout under the tsp key") {
                expect(LayoutType<TestWindow>.standardLayouts.map { $0.key }).to(contain("tsp"))
                expect(LayoutType<TestWindow>.from(key: "tsp").layoutClass == TertiarySplitPartitionLayout<TestWindow>.self).to(beTrue())
                expect(LayoutType<TestWindow>.layoutNameForKey("tsp")).to(equal("Tertiary Split Partition"))
            }
        }
    }
}
