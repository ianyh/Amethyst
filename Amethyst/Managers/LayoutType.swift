//
//  LayoutManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

extension FileManager {
    func layoutsDirectory() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let layoutsDirectory = applicationSupportDirectory
            .appendingPathComponent("Amethyst", isDirectory: true)
            .appendingPathComponent("Layouts", isDirectory: true)

        if !FileManager.default.fileExists(atPath: layoutsDirectory.path, isDirectory: nil) {
            try FileManager.default.createDirectory(
                at: layoutsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return layoutsDirectory
    }

    /// The folder of layouts shipped inside the app, when the app carries one.
    var bundledLayoutsDirectory: URL? {
        return Bundle.main.url(forResource: "Layouts", withExtension: nil)
    }

    /// Every folder custom layouts are read from, the user's own folder first so that a file there takes precedence over a bundled one of the same key.
    func layoutsDirectories() throws -> [URL] {
        return [try layoutsDirectory()] + (bundledLayoutsDirectory.map { [$0] } ?? [])
    }

    /// The file for a custom layout key: the first of the folders that holds `<key>.js`, or the user's folder when none does.
    func layoutFile(key: String) throws -> URL {
        return layoutFile(key: key, in: try layoutsDirectories())
    }

    /// The file named `<key>.js` in the first of `directories` that holds one, or in the first directory when none does.
    func layoutFile(key: String, in directories: [URL]) -> URL {
        let candidates = directories.map { $0.appendingPathComponent("\(key).js") }
        return candidates.first { fileExists(atPath: $0.path) } ?? candidates[0]
    }

    /// The keys of the layout files in `directories`, each key once, in the order of the first directory that holds it.
    func customLayoutKeys(in directories: [URL]) -> [String] {
        var keys: [String] = []
        for directory in directories {
            let files = (try? contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])) ?? []
            for file in files where file.pathExtension == "js" {
                let key = file.deletingPathExtension().lastPathComponent
                if !keys.contains(key) {
                    keys.append(key)
                }
            }
        }
        return keys
    }
}

enum LayoutType<Window: WindowType> {
    enum Error: Swift.Error {
        case unknownLayout
    }

    case tall
    case tallRight
    case wide
    case twoPane
    case twoPaneRight
    case threeColumnLeft
    case threeColumnMiddle
    case threeColumnRight
    case fourColumnLeft
    case fourColumnRight
    case fullscreen
    case column
    case row
    case floating
    case widescreenTallLeft
    case widescreenTallRight
    case binarySpacePartitioning

    case custom(key: String)

    static var standardLayouts: [LayoutType<Window>] {
        return [
            .tall,
            .tallRight,
            .wide,
            .twoPane,
            .twoPaneRight,
            .threeColumnLeft,
            .threeColumnMiddle,
            .threeColumnRight,
            .fourColumnLeft,
            .fourColumnRight,
            .fullscreen,
            .column,
            .row,
            .floating,
            .widescreenTallLeft,
            .widescreenTallRight,
            .binarySpacePartitioning
        ]
    }

    var key: String {
        switch self {
        case .tall:
            return "tall"
        case .tallRight:
            return "tall-right"
        case .wide:
            return "wide"
        case .twoPane:
            return "two-pane"
        case .twoPaneRight:
            return "two-pane-right"
        case .threeColumnLeft:
            return "3column-left"
        case .threeColumnMiddle:
            return "middle-wide"
        case .threeColumnRight:
            return "3column-right"
        case .fourColumnLeft:
            return "4column-left"
        case .fourColumnRight:
            return "4column-right"
        case .fullscreen:
            return "fullscreen"
        case .column:
            return "column"
        case .row:
            return "row"
        case .floating:
            return "floating"
        case .widescreenTallLeft:
            return "widescreen-tall"
        case .widescreenTallRight:
            return "widescreen-tall-right"
        case .binarySpacePartitioning:
            return "bsp"
        case .custom(let key):
            return key
        }
    }

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
        case .twoPaneRight:
            return TwoPaneRightLayout<Window>.self
        case .threeColumnLeft:
            return ThreeColumnLeftLayout<Window>.self
        case .threeColumnMiddle:
            return ThreeColumnMiddleLayout<Window>.self
        case .threeColumnRight:
            return ThreeColumnRightLayout<Window>.self
        case .fourColumnLeft:
            return FourColumnLeftLayout<Window>.self
        case .fourColumnRight:
            return FourColumnRightLayout<Window>.self
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
        case .custom:
            return CustomLayout<Window>.self
        }
    }

    static func from(key: String) -> LayoutType<Window> {
        switch key {
        case "tall":
            return .tall
        case "tall-right":
            return .tallRight
        case "wide":
            return .wide
        case "two-pane":
            return .twoPane
        case "two-pane-right":
            return .twoPaneRight
        case "3column-left":
            return .threeColumnLeft
        case "middle-wide":
            return .threeColumnMiddle
        case "3column-right":
            return .threeColumnRight
        case "4column-left":
            return .fourColumnLeft
        case "4column-right":
            return .fourColumnRight
        case "fullscreen":
            return .fullscreen
        case "column":
            return .column
        case "row":
            return .row
        case "floating":
            return .floating
        case "widescreen-tall":
            return .widescreenTallLeft
        case "widescreen-tall-right":
            return .widescreenTallRight
        case "bsp":
            return .binarySpacePartitioning
        default:
            return .custom(key: key)
        }
    }

    static func layoutForKey(_ layoutKey: String) -> Layout<Window>? {
        let type = LayoutType<Window>.from(key: layoutKey)

        guard case .custom = type else {
            return type.layoutClass.init()
        }

        do {
            let layoutFile = try FileManager.default.layoutFile(key: layoutKey)

            guard FileManager.default.fileExists(atPath: layoutFile.path) else {
                return nil
            }

            return CustomLayout<Window>(key: layoutKey, fileURL: layoutFile)
        } catch {
            return nil
        }
    }

    static func layoutNameForKey(_ layoutKey: String) -> String? {
        let type = LayoutType<Window>.from(key: layoutKey)

        guard case .custom = type else {
            return type.layoutClass.layoutName
        }

        return layoutForKey(layoutKey)?.layoutName
    }

    static func standardLayoutClasses() -> [Layout<Window>.Type] {
        return standardLayouts.compactMap { $0.layoutClass }
    }

    // Returns a list of (key, name) pairs
    static func availableLayoutStrings() -> [(key: String, name: String)] {
        var layoutTypes = standardLayouts
            .compactMap { $0.layoutClass }
            .map { ($0.layoutKey, $0.layoutName) }

        do {
            let directories = try FileManager.default.layoutsDirectories()
            let customLayouts = FileManager.default.customLayoutKeys(in: directories)
                .compactMap { key in layoutNameForKey(key).map { (key, $0) } }
            layoutTypes.append(contentsOf: customLayouts)
        } catch {
            log.error("failed to parse custom layouts")
        }

        return layoutTypes
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
        return try JSONEncoder().encode(layout)
    }

    static func decoded(data: Data, key: String) throws -> Layout<Window> {
        let layoutType = LayoutType<Window>.from(key: key)
        let decoder = JSONDecoder()
        return try decoder.decode(layoutType.layoutClass, from: data)
    }
}
