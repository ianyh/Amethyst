//
//  LayoutDirectoriesTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/17/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class LayoutDirectoriesTests: QuickSpec {
    override func spec() {
        describe("custom layout folders") {
            let fileManager = FileManager.default
            var first: URL!
            var second: URL!

            func makeDirectory() -> URL {
                let url = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try! fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            }

            func place(_ keys: [String], in directory: URL) {
                for key in keys {
                    try! "function layout() { return {}; }".write(to: directory.appendingPathComponent("\(key).js"), atomically: true, encoding: .utf8)
                }
            }

            beforeEach {
                first = makeDirectory()
                second = makeDirectory()
            }

            afterEach {
                try? fileManager.removeItem(at: first)
                try? fileManager.removeItem(at: second)
            }

            it("takes a layout file from the first folder that holds it") {
                place(["shared", "only-first"], in: first)
                place(["shared", "only-second"], in: second)

                expect(fileManager.layoutFile(key: "shared", in: [first, second])).to(equal(first.appendingPathComponent("shared.js")))
                expect(fileManager.layoutFile(key: "only-second", in: [first, second])).to(equal(second.appendingPathComponent("only-second.js")))
            }

            it("points a missing layout at the first folder") {
                expect(fileManager.layoutFile(key: "absent", in: [first, second])).to(equal(first.appendingPathComponent("absent.js")))
            }

            it("lists each key once, in the order of the folder that holds it first") {
                place(["b", "shared"], in: first)
                place(["a", "shared"], in: second)

                let keys = fileManager.customLayoutKeys(in: [first, second])
                expect(keys.sorted()).to(equal(["a", "b", "shared"]))
                expect(keys.filter { $0 == "shared" }.count).to(equal(1))
                expect(keys.firstIndex(of: "shared")).to(beLessThan(keys.firstIndex(of: "a")))
            }

            it("ignores files that are not layouts and folders that do not exist") {
                place(["real"], in: first)
                try! "notes".write(to: first.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
                let missing = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

                expect(fileManager.customLayoutKeys(in: [first, missing])).to(equal(["real"]))
            }
        }
    }
}
