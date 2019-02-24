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
        return layoutByKey[layoutKey]?.init(windowActivityCache: windowActivityCache)
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        return layoutByKey[layoutKey]?.layoutName
    }

    static var layoutClasses: [Layout.Type] = [
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

    static var layoutByKey: [String: Layout.Type] = Dictionary(uniqueKeysWithValues: zip( layoutClasses.map { ($0.layoutKey) }, layoutClasses ))

    // Returns a list of (key, name) pairs
    static func availableLayoutStrings() -> [(key: String, name: String)] {
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
