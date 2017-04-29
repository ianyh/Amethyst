//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum LayoutManager {
    static func layoutClassForString(_ layoutString: String) -> Layout.Type? {
        switch layoutString {
        case "tall":
            return TallLayout.self
        case "tall-right":
            return TallRightLayout.self
        case "wide":
            return WideLayout.self
        case "middle-wide":
            return MiddleWideLayout.self
        case "fullscreen":
            return FullscreenLayout.self
        case "column":
            return ColumnLayout.self
        case "row":
            return RowLayout.self
        case "floating":
            return FloatingLayout.self
        case "widescreen-tall":
            return WidescreenTallLayout.self
        case "bsp":
            return BinarySpacePartitioningLayout.self
        default:
            return nil
        }
    }

    static func stringForLayoutClass(_ layoutClass: Layout.Type) -> String {
        return layoutClass.layoutKey
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

        return layoutClasses.map { LayoutManager.stringForLayoutClass($0) }
    }

    static func layoutsWithConfiguration(_ userConfiguration: UserConfiguration, windowActivityCache: WindowActivityCache) -> [Layout] {
        let layoutStrings: [String] = userConfiguration.layoutStrings()
        let layouts = layoutStrings.map { layoutString -> Layout? in
            guard let layoutClass = LayoutManager.layoutClassForString(layoutString) else {
                LogManager.log?.warning("Unrecognized layout string \(layoutString)")
                return nil
            }

            return layoutClass.init(windowActivityCache: windowActivityCache)
        }

        return layouts.filter { $0 != nil }.map { $0! }
    }
}
