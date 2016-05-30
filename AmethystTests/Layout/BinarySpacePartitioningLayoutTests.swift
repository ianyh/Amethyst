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

public class BinarySpacePartitioningLayoutTests: QuickSpec {
    public override func spec() {
        describe("TreeNode") {
            context("insertion") {
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

                    rootNode.insertWindowIDAtEnd(CGWindowID(2))

                    expect(rootNode.right?.left?.windowID).to(equal(CGWindowID(1)))
                    expect(rootNode.right?.right?.windowID).to(equal(CGWindowID(2)))

                    rootNode.insertWindowIDAtEnd(CGWindowID(3))

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
                    
                    print(rootNode)

                    rootNode.insertWindowID(CGWindowID(2), atPoint: CGWindowID(0))
                    
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal(CGWindowID(0)))
                    expect(rootNode.left?.right?.windowID).to(equal(CGWindowID(2)))

                    rootNode.insertWindowID(CGWindowID(3), atPoint: CGWindowID(2))
                    
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.right?.windowID).to(beNil())
                    expect(rootNode.left?.right?.left?.windowID).to(equal(CGWindowID(2)))
                    expect(rootNode.left?.right?.right?.windowID).to(equal(CGWindowID(3)))
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

                    node1.insertWindowID(CGWindowID(2))

                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal(CGWindowID(0)))
                    expect(rootNode.left?.right?.windowID).to(equal(CGWindowID(2)))
                }
            }

            context("removing") {
                it("removes") {
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

                    rootNode.removeWindowID(CGWindowID(1))
                    
                    expect(rootNode.left?.windowID).to(equal(CGWindowID(0)))

                    rootNode.removeWindowID(CGWindowID(2))

                    expect(rootNode.windowID).to(equal(CGWindowID(0)))
                }
            }
        }
    }
}
