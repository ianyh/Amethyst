//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutType<Window: WindowType>: String, CaseIterable {
    enum Error: Swift.Error {
        case unknownLayout
    }

    case tall = "tall"
    case tallRight = "tall-right"
    case wide = "wide"
    case twoPane = "two-pane"
    case threeColumnLeft = "3column-left"
    case threeColumnMiddle = "middle-wide"
    case threeColumnRight = "3column-right"
    case threeColumnTallLeft = "3column-tall-left"
    case threeColumnTallMiddle = "3column-tall-middle"
    case threeColumnTallRight = "3column-tall-right"
    case fullscreen = "fullscreen"
    case column = "column"
    case row = "row"
    case floating = "floating"
    case widescreenTallLeft = "widescreen-tall"
    case widescreenTallRight = "widescreen-tall-right"
    case binarySpacePartitioning = "bsp"

    var layoutClass: Layout<Window>.Type {
        switch self {
        case .tall:
            return TallLayout<Window>.self
        case .tallRight:
            return TallRightLayout<Window>.self
        case .wide:
            return WideLayout<Window>.self
        case .twoPane:
            return TwoPaneLayout<Window>.self
        case .threeColumnLeft:
            return ThreeColumnLeftLayout<Window>.self
        case .threeColumnMiddle:
            return ThreeColumnMiddleLayout<Window>.self
        case .threeColumnRight:
            return ThreeColumnRightLayout<Window>.self
        case .threeColumnTallLeft:
            return ThreeColumnTallLeftLayout<Window>.self
        case .threeColumnTallMiddle:
            return ThreeColumnTallMiddleLayout<Window>.self
        case .threeColumnTallRight:
            return ThreeColumnTallRightLayout<Window>.self
        case .fullscreen:
            return FullscreenLayout<Window>.self
        case .column:
            return ColumnLayout<Window>.self
        case .row:
            return RowLayout<Window>.self
        case .floating:
            return FloatingLayout<Window>.self
        case .widescreenTallLeft:
            return WidescreenTallLayoutLeft<Window>.self
        case .widescreenTallRight:
            return WidescreenTallLayoutRight<Window>.self
        case .binarySpacePartitioning:
            return BinarySpacePartitioningLayout<Window>.self
        }
    }

    static func layoutClassForKey(_ layoutKey: String) -> Layout<Window>.Type? {
        return LayoutType<Window>(rawValue: layoutKey)?.layoutClass
    }

    static func layoutForKey(_ layoutKey: String) -> Layout<Window>? {
        return layoutClassForKey(layoutKey)?.init()
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        return LayoutType<Window>(rawValue: layoutKey)?.layoutClass.layoutName
    }

    static func layoutClasses() -> [Layout<Window>.Type] {
        return self.allCases.map { $0.layoutClass }
    }

    static func layoutByKey() -> [String: Layout<Window>.Type] {
        return Dictionary(uniqueKeysWithValues: zip( layoutClasses().map { ($0.layoutKey) }, layoutClasses() ))
    }

    // Returns a list of (key, name) pairs
    static func availableLayoutStrings() -> [(key: String, name: String)] {
        return layoutClasses().map { ($0.layoutKey, $0.layoutName) }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration) -> [Layout<Window>] {
        let layoutKeys: [String] = userConfiguration.layoutKeys()
        let layouts = layoutKeys.map { layoutKey -> Layout<Window>? in
            guard let layout = LayoutType.layoutForKey(layoutKey) else {
                log.warning("Unrecognized layout key \(layoutKey)")
                return nil
            }

            return layout
        }

        return layouts.compactMap { $0 }
    }

    static func encoded(layout: Layout<Window>) throws -> Data {
        switch layout {
        case let typedLayout as TallLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as TallRightLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as WideLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as TwoPaneLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnLeftLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnMiddleLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnRightLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnTallLeftLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnTallMiddleLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ThreeColumnTallRightLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as FullscreenLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as ColumnLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as RowLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as FloatingLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as WidescreenTallLayoutRight<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as WidescreenTallLayoutLeft<Window>:
            return try JSONEncoder().encode(typedLayout)
        case let typedLayout as BinarySpacePartitioningLayout<Window>:
            return try JSONEncoder().encode(typedLayout)
        default:
            throw Error.unknownLayout
        }
    }

    static func decoded(data: Data, key: String) throws -> Layout<Window> {
        guard let layoutType = LayoutType<Window>(rawValue: key) else {
            throw Error.unknownLayout
        }

        let decoder = JSONDecoder()

        switch layoutType {
        case .tall:
            return try decoder.decode(TallLayout.self, from: data)
        case .tallRight:
            return try decoder.decode(TallRightLayout.self, from: data)
        case .wide:
            return try decoder.decode(WideLayout.self, from: data)
        case .twoPane:
            return try decoder.decode(TwoPaneLayout.self, from: data)
        case .threeColumnLeft:
            return try decoder.decode(ThreeColumnLeftLayout.self, from: data)
        case .threeColumnMiddle:
            return try decoder.decode(ThreeColumnMiddleLayout.self, from: data)
        case .threeColumnRight:
            return try decoder.decode(ThreeColumnRightLayout.self, from: data)
        case .threeColumnTallLeft:
            return try decoder.decode(ThreeColumnTallLeftLayout.self, from: data)
        case .threeColumnTallMiddle:
            return try decoder.decode(ThreeColumnTallMiddleLayout.self, from: data)
        case .threeColumnTallRight:
            return try decoder.decode(ThreeColumnTallRightLayout.self, from: data)
        case .fullscreen:
            return try decoder.decode(FullscreenLayout.self, from: data)
        case .column:
            return try decoder.decode(ColumnLayout.self, from: data)
        case .row:
            return try decoder.decode(RowLayout.self, from: data)
        case .floating:
            return try decoder.decode(FloatingLayout.self, from: data)
        case .widescreenTallLeft:
            return try decoder.decode(WidescreenTallLayoutLeft.self, from: data)
        case .widescreenTallRight:
            return try decoder.decode(WidescreenTallLayoutRight.self, from: data)
        case .binarySpacePartitioning:
            return try decoder.decode(BinarySpacePartitioningLayout.self, from: data)
        }
    }
}
