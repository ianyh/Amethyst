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
        guard let parent = parent else {
            return
        }

        let newParent = TreeNode()
        let newNode = TreeNode()

        newNode.parent = newParent
        newNode.windowID = windowID

        newParent.left = self
        newParent.right = newNode

        if self == parent.left {
            parent.left = newParent
        } else {
            parent.right = newParent
        }

        self.parent = newParent
    }
}

extension TreeNode: Equatable {}

internal func == (lhs: TreeNode, rhs: TreeNode) -> Bool {
    return lhs.windowID == rhs.windowID
}

private class BinarySpacePartitioningReflowOperation: ReflowOperation {
    private override func main() {
        let screenFrame = adjustedFrameForLayout(screen)
        let frameAssignments: [FrameAssignment] = windows.map { window in
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame)
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
        return BinarySpacePartitioningReflowOperation(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    public override func updateWithChange(windowChange: WindowChange) {
        switch windowChange {
        case let .Add(window, insertionPoint):
            if let insertionPoint = insertionPoint {
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
}
