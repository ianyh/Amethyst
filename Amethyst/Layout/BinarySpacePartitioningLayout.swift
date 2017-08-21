//
//  BinarySpacePartitioningLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/29/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class TreeNode {
    weak var parent: TreeNode?
    var left: TreeNode?
    var right: TreeNode?
    var windowID: CGWindowID?

    var valid: Bool {
        return (left != nil && right != nil && windowID == nil) || (left == nil && right == nil && windowID != nil)
    }

    func findWindowID(_ windowID: CGWindowID) -> TreeNode? {
        guard self.windowID == windowID else {
            return left?.findWindowID(windowID) ?? right?.findWindowID(windowID)
        }

        return self
    }

    func orderedWindowIDs() -> [CGWindowID] {
        guard let windowID = windowID else {
            let leftWindowIDs = left?.orderedWindowIDs() ?? []
            let rightWindowIDs = right?.orderedWindowIDs() ?? []
            return leftWindowIDs + rightWindowIDs
        }

        return [windowID]
    }

    func insertWindowIDAtEnd(_ windowID: CGWindowID) {
        guard left == nil && right == nil else {
            right?.insertWindowIDAtEnd(windowID)
            return
        }

        insertWindowID(windowID)
    }

    func insertWindowID(_ windowID: CGWindowID, atPoint insertionPoint: CGWindowID) {
        guard self.windowID == insertionPoint else {
            left?.insertWindowID(windowID, atPoint: insertionPoint)
            right?.insertWindowID(windowID, atPoint: insertionPoint)
            return
        }

        insertWindowID(windowID)
    }

    func removeWindowID(_ windowID: CGWindowID) {
        guard let node = findWindowID(windowID) else {
            LogManager.log?.error("Trying to remove window not in tree")
            return
        }

        guard let parent = node.parent else {
            return
        }

        guard let grandparent = parent.parent else {
            if node == parent.left {
                parent.windowID = parent.right?.windowID
            } else {
                parent.windowID = parent.left?.windowID
            }
            parent.left = nil
            parent.right = nil
            return
        }

        if parent == grandparent.left {
            if node == parent.left {
                grandparent.left = parent.right
            } else {
                grandparent.left = parent.left
            }
            grandparent.left?.parent = grandparent
        } else {
            if node == parent.left {
                grandparent.right = parent.right
            } else {
                grandparent.right = parent.left
            }
            grandparent.right?.parent = grandparent
        }
    }

    func insertWindowID(_ windowID: CGWindowID) {
        guard parent != nil || self.windowID != nil else {
            self.windowID = windowID
            return
        }

        if let parent = parent {
            let newParent = TreeNode()
            let newNode = TreeNode()

            newNode.parent = newParent
            newNode.windowID = windowID

            newParent.left = self
            newParent.right = newNode
            newParent.parent = parent

            if self == parent.left {
                parent.left = newParent
            } else {
                parent.right = newParent
            }

            self.parent = newParent
        } else {
            let newSelf = TreeNode()
            let newNode = TreeNode()

            newSelf.windowID = self.windowID
            self.windowID = nil

            newNode.windowID = windowID

            left = newSelf
            left?.parent = self
            right = newNode
            right?.parent = self
        }
    }
}

extension TreeNode: Equatable {}

func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
    return lhs.windowID == rhs.windowID
}

final class BinarySpacePartitioningReflowOperation: ReflowOperation {
    private typealias TraversalNode = (node: TreeNode, frame: CGRect)
    private let rootNode: TreeNode

    init(screen: NSScreen, windows: [SIWindow], rootNode: TreeNode, frameAssigner: FrameAssigner) {
        self.rootNode = rootNode
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    var frameAssignments: [FrameAssignment] {
        guard !windows.isEmpty else {
            return []
        }

        let windowIDMap: [CGWindowID: SIWindow] = windows.reduce([:]) { (windowMap, window) -> [CGWindowID: SIWindow] in
            var mutableWindowMap = windowMap
            mutableWindowMap[window.windowID()] = window
            return mutableWindowMap
        }

        let focusedWindow = SIWindow.focused()
        let baseFrame = screen.adjustedFrame()
        var ret: [FrameAssignment] = []
        var traversalNodes: [TraversalNode] = [(node: rootNode, frame: baseFrame)]

        while !traversalNodes.isEmpty {
            let traversalNode = traversalNodes[0]

            traversalNodes = [TraversalNode](traversalNodes.dropFirst(1))

            if let windowID = traversalNode.node.windowID {
                guard let window = windowIDMap[windowID] else {
                    LogManager.log?.warning("Could not find window for ID: \(windowID)")
                    continue
                }

                let frameAssignment = FrameAssignment(frame: traversalNode.frame, window: window, focused: windowID == focusedWindow?.windowID(), screenFrame: baseFrame)
                ret.append(frameAssignment)
            } else {
                guard let left = traversalNode.node.left, let right = traversalNode.node.right else {
                    LogManager.log?.error("Encountered an invalid node")
                    continue
                }

                let frame = traversalNode.frame

                if frame.width > frame.height {
                    let leftFrame = CGRect(
                        x: frame.origin.x,
                        y: frame.origin.y,
                        width: frame.width / 2.0,
                        height: frame.height
                    )
                    let rightFrame = CGRect(
                        x: frame.origin.x + frame.width / 2.0,
                        y: frame.origin.y,
                        width: frame.width / 2.0,
                        height: frame.height
                    )
                    traversalNodes.append((node: left, frame: leftFrame))
                    traversalNodes.append((node: right, frame: rightFrame))
                } else {
                    let topFrame = CGRect(
                        x: frame.origin.x,
                        y: frame.origin.y,
                        width: frame.width,
                        height: frame.height / 2.0
                    )
                    let bottomFrame = CGRect(
                        x: frame.origin.x,
                        y: frame.origin.y + frame.height / 2.0,
                        width: frame.width,
                        height: frame.height / 2.0
                    )
                    traversalNodes.append((node: left, frame: topFrame))
                    traversalNodes.append((node: right, frame: bottomFrame))
                }
            }
        }

        return ret
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments)
    }
}

final class BinarySpacePartitioningLayout: Layout {
    static var layoutName: String { return "Binary Space Partitioning" }
    static var layoutKey: String { return "bsp" }

    let windowActivityCache: WindowActivityCache

    fileprivate var rootNode = TreeNode()
    fileprivate var lastKnownFocusedWindowID: CGWindowID?

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        if !windows.isEmpty && !rootNode.valid {
            constructInitialTreeWithWindows(windows)
        }

        return BinarySpacePartitioningReflowOperation(screen: screen, windows: windows, rootNode: rootNode, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return BinarySpacePartitioningReflowOperation(screen: screen, windows: windows, rootNode: rootNode, frameAssigner: self).frameAssignments.first { $0.window == window }
    }

    private func constructInitialTreeWithWindows(_ windows: [SIWindow]) {
        for window in windows {
            guard rootNode.findWindowID(window.windowID()) == nil else {
                continue
            }

            rootNode.insertWindowIDAtEnd(window.windowID())
        }
    }
}

extension BinarySpacePartitioningLayout: StatefulLayout {
    func updateWithChange(_ windowChange: WindowChange) {
        switch windowChange {
        case let .add(window):
            guard rootNode.findWindowID(window.windowID()) == nil else {
                LogManager.log?.warning("Trying to add a window already in the tree")
                return
            }

            if let insertionPoint = lastKnownFocusedWindowID, window.windowID() != insertionPoint {
                LogManager.log?.info("insert \(window) - \(window.windowID()) at point: \(insertionPoint)")
                rootNode.insertWindowID(window.windowID(), atPoint: insertionPoint)
            } else {
                LogManager.log?.info("insert \(window) - \(window.windowID()) at end")
                rootNode.insertWindowIDAtEnd(window.windowID())
            }
        case let .remove(window):
            LogManager.log?.info("remove: \(window) - \(window.windowID())")
            rootNode.removeWindowID(window.windowID())
        case let .focusChanged(window):
            lastKnownFocusedWindowID = window.windowID()
        case let .windowSwap(window, otherWindow):
            let windowID = window.windowID()
            let otherWindowID = otherWindow.windowID()

            guard let windowNode = rootNode.findWindowID(windowID), let otherWindowNode = rootNode.findWindowID(otherWindowID) else {
                LogManager.log?.error("Tried to perform an unbalanced window swap: \(windowID) <-> \(otherWindowID)")
                return
            }

            windowNode.windowID = otherWindowID
            otherWindowNode.windowID = windowID
        case .unknown:
            break
        }
    }

    func nextWindowIDCounterClockwise() -> CGWindowID? {
        guard let focusedWindow = SIWindow.focused() else {
            return nil
        }

        let orderedIDs = rootNode.orderedWindowIDs()

        guard let focusedWindowIndex = orderedIDs.index(of: focusedWindow.windowID()) else {
            return nil
        }

        let nextWindowIndex = (focusedWindowIndex == 0 ? orderedIDs.count - 1 : focusedWindowIndex - 1)

        return orderedIDs[nextWindowIndex]
    }

    func nextWindowIDClockwise() -> CGWindowID? {
        guard let focusedWindow = SIWindow.focused() else {
            return nil
        }

        let orderedIDs = rootNode.orderedWindowIDs()

        guard let focusedWindowIndex = orderedIDs.index(of: focusedWindow.windowID()) else {
            return nil
        }

        let nextWindowIndex = (focusedWindowIndex == orderedIDs.count - 1 ? 0 : focusedWindowIndex + 1)

        return orderedIDs[nextWindowIndex]
    }
}

extension BinarySpacePartitioningLayout: FrameAssigner {}
