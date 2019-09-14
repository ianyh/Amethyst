//
//  Reliability.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/8/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

/// `Relatable` wraps a value with the level of confidence that the value is correct.
enum Reliable<T> {
    /// `reliable` means that the value is probably correct.
    case reliable(T)

    /// `unreliable` means that the value may be correct, but the returning function is not confident that the value will remain stable.
    case unreliable(T)
}

extension Reliable: Equatable where T: Equatable {}
