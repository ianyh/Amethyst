//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutManager {
    static func layoutForKey(_ layoutString: String, with windowActivityCache: WindowActivityCache) -> Layout? {
        switch layoutString {
        case "tall":
            return TallLayout(windowActivityCache: windowActivityCache)
        case "tall-right":
            return TallRightLayout(windowActivityCache: windowActivityCache)
        case "wide":
            return WideLayout(windowActivityCache: windowActivityCache)
        case "middle-wide":
            return MiddleWideLayout(windowActivityCache: windowActivityCache)
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

    static func availableLayoutStrings() -> [String] {
        let layoutClasses: [Layout.Type] = [
            TallLayout.self,
            TallRightLayout.self,
            WideLayout.self,
            MiddleWideLayout.self,
            FullscreenLayout.self,
            ColumnLayout.self,
            RowLayout.self,
            FloatingLayout.self,
            WidescreenTallLayout.self,
            BinarySpacePartitioningLayout.self
        ]

        return layoutClasses.map { $0.layoutKey }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration, windowActivityCache: WindowActivityCache) -> [Layout] {
        let layoutStrings: [String] = userConfiguration.layoutStrings()
        let layouts = layoutStrings.map { layoutString -> Layout? in
            guard let layout = LayoutManager.layoutForKey(layoutString, with: windowActivityCache) else {
                LogManager.log?.warning("Unrecognized layout string \(layoutString)")
                return nil
            }

            return layout
        }

        return layouts.flatMap { $0 }
    }
}
