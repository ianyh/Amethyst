//
//  Reliability.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/8/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

enum Reliable<T>: Equatable where T: Equatable {
    case reliable(T)
    case unreliable(T)
}
