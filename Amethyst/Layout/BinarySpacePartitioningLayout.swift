//
//  BinarySpacePartitioningLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/29/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Silica

internal class TreeNode {
    weak var parent: TreeNode?
    var left: TreeNode?
    var right: TreeNode?
    var windowID: CGWindowID?

    var valid: Bool {
        return (left != nil && left != nil) || windowID != nil
    }

    func insertWindowIDAtEnd(windowID: CGWindowID) {
        guard right == nil else {
            right?.insertWindowIDAtEnd(windowID)
            return
        }

        insertWindowID(windowID)
    }

    func insertWindowID(windowID: CGWindowID, atPoint insertionPoint: CGWindowID) {
        guard self.windowID == insertionPoint else {
            left?.insertWindowID(windowID, atPoint: insertionPoint)
            right?.insertWindowID(windowID, atPoint: insertionPoint)
            return
        }

        insertWindowID(windowID)
    }

    func removeWindowID(windowID: CGWindowID) {
        guard self.windowID == windowID else {
            left?.removeWindowID(windowID)
            right?.removeWindowID(windowID)
            return
        }

        guard let parent = parent else {
            return
        }

        guard let grandparent = parent.parent else {
            if self == parent.left {
                parent.windowID = parent.right?.windowID
            } else {
                parent.windowID = parent.left?.windowID
            }
            parent.left = nil
            parent.right = nil
            return
        }

        if parent == grandparent.left {
            if self == parent.left {
                grandparent.left = parent.right
            } else {
                grandparent.left = parent.left
            }
            grandparent.left?.parent = grandparent
        } else {
            if self == parent.left {
                grandparent.right = parent.right
            } else {
                grandparent.right = parent.left
            }
            grandparent.right?.parent = grandparent
        }
    }

    internal func insertWindowID(windowID: CGWindowID) {
        guard parent != nil || self.windowID != nil else {
            self.windowID = windowID
            return
        }

        let newParent = TreeNode()
        let newNode = TreeNode()

        newNode.parent = newParent
        newNode.windowID = windowID

        if let parent = parent {
            newParent.left = self
            newParent.right = newNode

            if self == parent.left {
                parent.left = newParent
            } else {
                parent.right = newParent
            }

            self.parent = newParent
        } else {
            newParent.windowID = self.windowID
            self.windowID = nil

            left = newParent
            left?.parent = self
            right = newNode
            right?.parent = self
        }
    }
}

extension TreeNode: Equatable {}

internal func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
    return lhs.windowID == rhs.windowID
}

private class BinarySpacePartitioningReflowOperation: ReflowOperation {
    private typealias TraversalNode = (node: TreeNode, frame: CGRect)

    private let rootNode: TreeNode

    private init(screen: NSScreen, windows: [SIWindow], rootNode: TreeNode, windowActivityCache: WindowActivityCache) {
        self.rootNode = rootNode
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    private override func main() {
        if windows.count == 0 {
            return
        }

        let focusedWindow = SIWindow.focusedWindow()
        let baseFrame = adjustedFrameForLayout(screen)
        var frameAssignments: [FrameAssignment] = []
        var traversalNodes: [TraversalNode] = [(node: rootNode, frame: baseFrame)]

        while traversalNodes.count > 0 {
            let traversalNode = traversalNodes[0]
            traversalNodes = [TraversalNode](traversalNodes.dropFirst(1))

            if let windowID = traversalNode.node.windowID {
                guard let window = windows.filter({ window -> Bool in return window.windowID() == windowID }).first else {
                    LogManager.log?.error("Encountered a window id that does not match up to a window")
                    continue
                }

                let frameAssignment = FrameAssignment(frame: traversalNode.frame, window: window, focused: windowID == focusedWindow?.windowID(), screenFrame: baseFrame)
                frameAssignments.append(frameAssignment)
            } else {
                guard let left = traversalNode.node.left, right = traversalNode.node.right else {
                    LogManager.log?.error("Encountered an invalid node")
                    continue
                }

                let frame = traversalNode.frame

                if frame.width > frame.height {
                    let leftFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width / 2.0, height: frame.height)
                    let rightFrame = CGRect(x: frame.origin.x + frame.width / 2.0, y: frame.origin.y, width: frame.width / 2.0, height: frame.height)
                    traversalNodes.append((node: left, frame: leftFrame))
                    traversalNodes.append((node: right, frame: rightFrame))
                } else {
                    let leftFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height / 2.0)
                    let rightFrame = CGRect(x: frame.origin.x, y: frame.origin.y + frame.height / 2.0, width: frame.width, height: frame.height / 2.0)
                    traversalNodes.append((node: left, frame: leftFrame))
                    traversalNodes.append((node: right, frame: rightFrame))
                }
            }
        }

        if cancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

public class BinarySpacePartitioningLayout: Layout {
    override public class var layoutName: String { return "Binary Space Partitioning" }
    override public class var layoutKey: String { return "bsp" }

    internal var rootNode = TreeNode()

    public override func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        if windows.count > 0 && !rootNode.valid {
            constructInitialTreeWithWindows(windows)
        }

        return BinarySpacePartitioningReflowOperation(screen: screen, windows: windows, rootNode: rootNode, windowActivityCache: windowActivityCache)
    }

    public override func updateWithChange(windowChange: WindowChange) {
        switch windowChange {
        case let .Add(window, insertionPoint):
            if let insertionPoint = insertionPoint where window.windowID() != insertionPoint.windowID() {
                rootNode.insertWindowID(window.windowID(), atPoint: insertionPoint.windowID())
            } else {
                rootNode.insertWindowIDAtEnd(window.windowID())
            }
        case let .Remove(window):
            rootNode.removeWindowID(window.windowID())
        case .Unknown:
            break
        }
    }

    internal func constructInitialTreeWithWindows(windows: [SIWindow]) {
        for window in windows {
            rootNode.insertWindowIDAtEnd(window.windowID())
        }
    }
}
