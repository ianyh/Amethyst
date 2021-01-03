//
//  main.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 2/24/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa

if CommandLine.arguments.contains("--debug-info") {
    print(DebugInfo.description(arguments: CommandLine.arguments))
} else {
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
