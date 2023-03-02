//
//  BinarySpacePartitioningLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/29/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class TreeNode<Window: WindowType>: Codable {
    typealias WindowID = Window.WindowID

    private enum CodingKeys: String, CodingKey {
        case left
        case right
        case windowID
    }

    weak var parent: TreeNode?
    var left: TreeNode?
    var right: TreeNode?
    var windowID: WindowID?

    init() {}

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.left = try values.decodeIfPresent(TreeNode.self, forKey: .left)
        self.right = try values.decodeIfPresent(TreeNode.self, forKey: .right)
        self.windowID = try values.decodeIfPresent(WindowID.self, forKey: .windowID)

        self.left?.parent = self
        self.right?.parent = self

        guard valid else {
            throw LayoutDecodingError.invalidLayout
        }
    }

    var valid: Bool {
        return (left != nil && right != nil && windowID == nil) || (left == nil && right == nil && windowID != nil)
    }

    func findWindowID(_ windowID: WindowID) -> TreeNode? {
        guard self.windowID == windowID else {
            return left?.findWindowID(windowID) ?? right?.findWindowID(windowID)
        }

        return self
    }

    func orderedWindowIDs() -> [WindowID] {
        guard let windowID = windowID else {
            let leftWindowIDs = left?.orderedWindowIDs() ?? []
            let rightWindowIDs = right?.orderedWindowIDs() ?? []
            return leftWindowIDs + rightWindowIDs
        }

        return [windowID]
    }

    func insertWindowIDAtEnd(_ windowID: WindowID) {
        guard left == nil && right == nil else {
            right?.insertWindowIDAtEnd(windowID)
            return
        }

        insertWindowID(windowID)
    }

    func insertWindowID(_ windowID: WindowID, atPoint insertionPoint: WindowID) {
        guard self.windowID == insertionPoint else {
            left?.insertWindowID(windowID, atPoint: insertionPoint)
            right?.insertWindowID(windowID, atPoint: insertionPoint)
            return
        }

        insertWindowID(windowID)
    }

    func removeWindowID(_ windowID: WindowID) {
        guard let node = findWindowID(windowID) else {
            log.error("Trying to remove window not in tree")
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

    func insertWindowID(_ windowID: WindowID) {
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

extension TreeNode: Equatable {
    static func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
        return lhs.windowID == rhs.windowID && lhs.left == rhs.left && lhs.right == rhs.right
    }
}

class BinarySpacePartitioningLayout<Window: WindowType>: StatefulLayout<Window> {
    typealias WindowID = Window.WindowID

    private typealias TraversalNode = (node: TreeNode<Window>, frame: CGRect)

    private enum CodingKeys: String, CodingKey {
        case rootNode
    }

    override static var layoutName: String { return "Binary Space Partitioning" }
    override static var layoutKey: String { return "bsp" }

    override var layoutDescription: String { return "\(lastKnownFocusedWindowID.debugDescription)" }

    private var rootNode = TreeNode<Window>()
    private var lastKnownFocusedWindowID: WindowID?

    required init() {
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rootNode = try container.decode(TreeNode<Window>.self, forKey: .rootNode)
        super.init()
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootNode, forKey: .rootNode)
    }

    private func constructInitialTreeWithWindows(_ windows: [LayoutWindow<Window>]) {
        for window in windows {
            guard rootNode.findWindowID(window.id) == nil else {
                continue
            }

            rootNode.insertWindowIDAtEnd(window.id)

            if window.isFocused {
                lastKnownFocusedWindowID = window.id
            }
        }
    }

    override func updateWithChange(_ windowChange: Change<Window>) {
        switch windowChange {
        case let .add(window):
            guard rootNode.findWindowID(window.id()) == nil else {
                log.warning("Trying to add a window already in the tree")
                return
            }

            if let insertionPoint = lastKnownFocusedWindowID, window.id() != insertionPoint {
                log.info("insert \(window) - \(window.id()) at point: \(insertionPoint)")
                rootNode.insertWindowID(window.id(), atPoint: insertionPoint)
            } else {
                log.info("insert \(window) - \(window.id()) at end")
                rootNode.insertWindowIDAtEnd(window.id())
            }

            if window.isFocused() {
                lastKnownFocusedWindowID = window.id()
            }
        case let .remove(window):
            log.info("remove: \(window) - \(window.id())")
            rootNode.removeWindowID(window.id())
        case let .focusChanged(window):
            lastKnownFocusedWindowID = window.id()
        case let .windowSwap(window, otherWindow):
            let windowID = window.id()
            let otherWindowID = otherWindow.id()

            guard let windowNode = rootNode.findWindowID(windowID), let otherWindowNode = rootNode.findWindowID(otherWindowID) else {
                log.error("Tried to perform an unbalanced window swap: \(windowID) <-> \(otherWindowID)")
                return
            }

            windowNode.windowID = otherWindowID
            otherWindowNode.windowID = windowID
        case .applicationDeactivate, .applicationActivate, .spaceChange, .layoutChange, .unknown:
            break
        }
    }

    override func nextWindowIDCounterClockwise() -> WindowID? {
        guard let focusedWindow = Window.currentlyFocused() else {
            return nil
        }

        let orderedIDs = rootNode.orderedWindowIDs()

        guard let focusedWindowIndex = orderedIDs.firstIndex(of: focusedWindow.id()) else {
            return nil
        }

        let nextWindowIndex = (focusedWindowIndex == 0 ? orderedIDs.count - 1 : focusedWindowIndex - 1)

        return orderedIDs[nextWindowIndex]
    }

    override func nextWindowIDClockwise() -> WindowID? {
        guard let focusedWindow = Window.currentlyFocused() else {
            return nil
        }

        let orderedIDs = rootNode.orderedWindowIDs()

        guard let focusedWindowIndex = orderedIDs.firstIndex(of: focusedWindow.id()) else {
            return nil
        }

        let nextWindowIndex = (focusedWindowIndex == orderedIDs.count - 1 ? 0 : focusedWindowIndex + 1)

        return orderedIDs[nextWindowIndex]
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        if rootNode.left == nil && rootNode.right == nil {
            constructInitialTreeWithWindows(windows)
        }

        let windowIDMap: [WindowID: LayoutWindow<Window>] = windows.reduce([:]) { (windowMap, window) -> [WindowID: LayoutWindow<Window>] in
            var mutableWindowMap = windowMap
            mutableWindowMap[window.id] = window
            return mutableWindowMap
        }

        let baseFrame = screen.adjustedFrame()
        var ret: [FrameAssignmentOperation<Window>] = []
        var traversalNodes: [TraversalNode] = [(node: rootNode, frame: baseFrame)]

        while !traversalNodes.isEmpty {
            let traversalNode = traversalNodes[0]

            traversalNodes = [TraversalNode](traversalNodes.dropFirst(1))

            if let windowID = traversalNode.node.windowID {
                guard let window = windowIDMap[windowID] else {
                    log.warning("Could not find window for ID: \(windowID)")
                    continue
                }

                let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
                let frameAssignment = FrameAssignment<Window>(
                    frame: traversalNode.frame,
                    window: window,
                    screenFrame: baseFrame,
                    resizeRules: resizeRules
                )
                ret.append(FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet))
            } else {
                guard let left = traversalNode.node.left, let right = traversalNode.node.right else {
                    log.error("Encountered an invalid node")
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
}

extension BinarySpacePartitioningLayout: Equatable {
    static func == (lhs: BinarySpacePartitioningLayout<Window>, rhs: BinarySpacePartitioningLayout<Window>) -> Bool {
        return lhs.rootNode == rhs.rootNode
    }
}
