//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutManager<Window: WindowType> {
    static func layoutForKey(_ layoutKey: String, with windowActivityCache: WindowActivityCache) -> Layout<Window>? {
        return layoutByKey()[layoutKey]?.init(windowActivityCache: windowActivityCache)
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        return layoutByKey()[layoutKey]?.layoutName
    }

    static func layoutClasses() -> [Layout<Window>.Type] {
        return [
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
            WidescreenTallLayoutLeft.self,
            WidescreenTallLayoutRight.self,
            BinarySpacePartitioningLayout.self
        ]
    }

    static func layoutByKey() -> [String: Layout<Window>.Type] {
        return Dictionary(uniqueKeysWithValues: zip( layoutClasses().map { ($0.layoutKey) }, layoutClasses() ))
    }

    // Returns a list of (key, name) pairs
    static func availableLayoutStrings() -> [(key: String, name: String)] {
        return layoutClasses().map { ($0.layoutKey, $0.layoutName) }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration, windowActivityCache: WindowActivityCache) -> [Layout<Window>] {
        let layoutKeys: [String] = userConfiguration.layoutKeys()
        let layouts = layoutKeys.map { layoutKey -> Layout<Window>? in
            guard let layout = LayoutManager.layoutForKey(layoutKey, with: windowActivityCache) else {
                log.warning("Unrecognized layout key \(layoutKey)")
                return nil
            }

            return layout
        }

        return layouts.compactMap { $0 }
    }
}
