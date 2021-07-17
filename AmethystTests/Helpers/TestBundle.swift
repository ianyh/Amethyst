//
//  TestBundle.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 7/8/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

extension Bundle {
    static var testBundle: Bundle {
        return Bundle(for: TestWindow.self)
    }

    static func layoutFile(key: String) -> URL? {
        return testBundle.path(forResource: key, ofType: "js").flatMap { URL(fileURLWithPath: $0) }
    }
}
