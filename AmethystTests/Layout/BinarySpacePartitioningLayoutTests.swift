//
//  BinarySpacePartitioningLayoutTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/29/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Nimble
import Quick

@testable import Amethyst

final class BinarySpacePartitioningLayoutTests: QuickSpec {
    override func spec() {
        describe("TreeNode") {
            describe("finding") {
                it("finds a node that exists") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    let node3 = TreeNode()
                    let node4 = TreeNode()
                    
                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3
                    
                    node2.windowID = CGWindowID(0)
                    node2.parent = node1
                    
                    node3.windowID = CGWindowID(1)
                    node3.parent = node1
                    
                    node4.windowID = CGWindowID(2)
                    node4.parent = rootNode
                    
                    rootNode.left = node1
                    rootNode.right = node4
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID(CGWindowID(0))).to(equal(node2))
                    expect(rootNode.findWindowID(CGWindowID(1))).to(equal(node3))
                    expect(rootNode.findWindowID(CGWindowID(2))).to(equal(node4))
                }

                it("does not find a node that does not exist") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    
                    node1.windowID = CGWindowID(0)
                    node1.parent = rootNode
                    node2.windowID = CGWindowID(1)
                    node2.parent = rootNode
                    
                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID(CGWindowID(2))).to(beNil())
                }
            }

            describe("traversing") {
                it("generates an empty list for an empty tree") {
                    let rootNode = TreeNode()
                    expect(rootNode.orderedWindowIDs()).to(equal([]))
                }

                it("generates a correctly ordered list") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    let node3 = TreeNode()
                    let node4 = TreeNode()
                    
                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3
                    
                    node2.windowID = CGWindowID(0)
                    node2.parent = node1
                    
                    node3.windowID = CGWindowID(1)
                    node3.parent = node1
                    
                    node4.windowID = CGWindowID(2)
                    node4.parent = rootNode
                    
                    rootNode.left = node4
                    rootNode.right = node1

                    let orderedList = rootNode.orderedWindowIDs()

                    expect(orderedList).to(equal([CGWindowID(2), CGWindowID(0), CGWindowID(1)]))
                }
            }

            describe("insertion") {
                it("inserts at end") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()

                    node1.windowID = CGWindowID(0)
                    node1.parent = rootNode
                    node2.windowID = CGWindowID(1)
                    node2.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.insertWindowIDAtEnd(CGWindowID(2))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.right?.left?.windowID).to(equal(CGWindowID(1)))
                    expect(rootNode.right?.right?.windowID).to(equal(CGWindowID(2)))

                    rootNode.insertWindowIDAtEnd(CGWindowID(3))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.right?.left?.windowID).to(equal(CGWindowID(1)))
                    expect(rootNode.right?.right?.left?.windowID).to(equal(CGWindowID(2)))
                    expect(rootNode.right?.right?.right?.windowID).to(equal(CGWindowID(3)))
                }

                it("inserts at the insertion point") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    
                    node1.windowID = CGWindowID(0)
                    node1.parent = rootNode
                    node2.windowID = CGWindowID(1)
                    node2.parent = rootNode
                    
                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())
                    
                    rootNode.insertWindowID(CGWindowID(2), atPoint: CGWindowID(0))
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal(CGWindowID(0)))
                    expect(rootNode.left?.right?.windowID).to(equal(CGWindowID(2)))

                    rootNode.insertWindowID(CGWindowID(3), atPoint: CGWindowID(2))
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.right?.windowID).to(beNil())
                    expect(rootNode.left?.right?.left?.windowID).to(equal(CGWindowID(2)))
                    expect(rootNode.left?.right?.right?.windowID).to(equal(CGWindowID(3)))
    
                    rootNode.insertWindowID(CGWindowID(4), atPoint: CGWindowID(0))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.left?.windowID).to(equal(CGWindowID(0)))
                    expect(rootNode.left?.left?.right?.windowID).to(equal(CGWindowID(4)))
                }

                it("inserts") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    
                    node1.windowID = CGWindowID(0)
                    node1.parent = rootNode
                    node2.windowID = CGWindowID(1)
                    node2.parent = rootNode
                    
                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())

                    node1.insertWindowID(CGWindowID(2))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal(CGWindowID(0)))
                    expect(rootNode.left?.right?.windowID).to(equal(CGWindowID(2)))
                }

                it("sets root value when the tree is empty") {
                    let rootNode = TreeNode()

                    rootNode.insertWindowIDAtEnd(CGWindowID(0))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.windowID).to(equal(CGWindowID(0)))
                }

                it("clears root value when inserting value after first one") {
                    let rootNode = TreeNode()
                    
                    rootNode.insertWindowIDAtEnd(CGWindowID(0))
                    rootNode.insertWindowIDAtEnd(CGWindowID(1))

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left).toNot(beNil())
                    expect(rootNode.right).toNot(beNil())
                    expect(rootNode.windowID).to(beNil())
                }
            }

            describe("removing") {
                it("removes from a shallow tree") {
                    let rootNode = TreeNode()
                    let node1 = TreeNode()
                    let node2 = TreeNode()
                    let node3 = TreeNode()
                    let node4 = TreeNode()
                    
                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3
                    
                    node2.windowID = CGWindowID(0)
                    node2.parent = node1
                    
                    node3.windowID = CGWindowID(1)
                    node3.parent = node1
                    
                    node4.windowID = CGWindowID(2)
                    node4.parent = rootNode
                    
                    rootNode.left = node1
                    rootNode.right = node4
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    
                    rootNode.removeWindowID(CGWindowID(1))
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID(CGWindowID(1))).to(beNil())
                    expect(rootNode.left?.windowID).to(equal(CGWindowID(0)))
                    
                    rootNode.removeWindowID(CGWindowID(2))
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID(CGWindowID(2))).to(beNil())
                    expect(rootNode.windowID).to(equal(CGWindowID(0)))
                }

                it("removes from a deep tree") {
                    let rootNode = TreeNode()

                    (0..<10).forEach { rootNode.insertWindowIDAtEnd(CGWindowID($0)) }

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.removeWindowID(CGWindowID(5))
                    
                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID(CGWindowID(5))).to(beNil())
                }
            }

            describe("validitity") {
                it("is invalid when a node has children and an id at the same time") {
                    let node = TreeNode()
                    let node2 = TreeNode()
                    let node3 = TreeNode()

                    node.windowID = CGWindowID(0)
                    node2.windowID = CGWindowID(1)
                    node3.windowID = CGWindowID(2)

                    expect(node.valid).to(beTrue())

                    node.left = node2
                    node.right = node3

                    expect(node.valid).to(beFalse())
                }
            }
        }
    }
}

extension TreeNode {
    fileprivate func treeIsValid() -> Bool {
        var valid = self.valid
        if let left = left, let right = right {
            valid = valid && left.parent == self && right.parent == self
            valid = valid && left.treeIsValid() && right.treeIsValid()
        }
        return valid
    }
}
