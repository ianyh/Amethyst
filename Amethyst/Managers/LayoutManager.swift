//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutManager {
    static func layoutForKey(_ layoutKey: String, with windowActivityCache: WindowActivityCache) -> Layout? {
        switch layoutKey {
        case "tall":
            return TallLayout(windowActivityCache: windowActivityCache)
        case "tall-right":
            return TallRightLayout(windowActivityCache: windowActivityCache)
        case "wide":
            return WideLayout(windowActivityCache: windowActivityCache)
        case "3column-left":
            return ThreeColumnLeftLayout(windowActivityCache: windowActivityCache)
        case "middle-wide":
            return ThreeColumnMiddleLayout(windowActivityCache: windowActivityCache)
        case "3column-right":
            return ThreeColumnRightLayout(windowActivityCache: windowActivityCache)
        case "fullscreen":
            return FullscreenLayout(windowActivityCache: windowActivityCache)
        case "column":
            return ColumnLayout(windowActivityCache: windowActivityCache)
        case "row":
            return RowLayout(windowActivityCache: windowActivityCache)
        case "floating":
            return FloatingLayout(windowActivityCache: windowActivityCache)
        case "widescreen-tall":
            return WidescreenTallLayout(windowActivityCache: windowActivityCache)
        case "bsp":
            return BinarySpacePartitioningLayout(windowActivityCache: windowActivityCache)
        default:
            return nil
        }
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        switch layoutKey {
        case "tall":
            return TallLayout.layoutName
        case "tall-right":
            return TallRightLayout.layoutName
        case "wide":
            return WideLayout.layoutName
        case "3column-left":
            return ThreeColumnLeftLayout.layoutName
        case "middle-wide":
            return ThreeColumnMiddleLayout.layoutName
        case "3column-right":
            return ThreeColumnRightLayout.layoutName
        case "fullscreen":
            return FullscreenLayout.layoutName
        case "column":
            return ColumnLayout.layoutName
        case "row":
            return RowLayout.layoutName
        case "floating":
            return FloatingLayout.layoutName
        case "widescreen-tall":
            return WidescreenTallLayout.layoutName
        case "bsp":
            return BinarySpacePartitioningLayout.layoutName
        default:
            return nil
        }
    }

    // Returns a list of (key, name) pairs
    static func availableLayoutStrings() -> [(key: String, name: String)] {
        let layoutClasses: [Layout.Type] = [
            TallLayout.self,
            TallRightLayout.self,
            WideLayout.self,
            ThreeColumnLeftLayout.self,
            ThreeColumnMiddleLayout.self,
            ThreeColumnRightLayout.self,
            FullscreenLayout.self,
            ColumnLayout.self,
            RowLayout.self,
            FloatingLayout.self,
            WidescreenTallLayout.self,
            BinarySpacePartitioningLayout.self
        ]

        return layoutClasses.map { ($0.layoutKey, $0.layoutName) }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration, windowActivityCache: WindowActivityCache) -> [Layout] {
        let layoutKeys: [String] = userConfiguration.layoutKeys()
        let layouts = layoutKeys.map { layoutKey -> Layout? in
            guard let layout = LayoutManager.layoutForKey(layoutKey, with: windowActivityCache) else {
                log.warning("Unrecognized layout key \(layoutKey)")
                return nil
            }

            return layout
        }

        return layouts.compactMap { $0 }
    }
}
