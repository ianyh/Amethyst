//
//  relaunch.swift
//  Amethyst
//
//  Created by Agustin Suarez on 2021-02-23.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Cocoa

class AppManager {
    public static func relaunch() {
        let executablePath = Bundle.main.executablePath! as NSString
        let fileSystemRepresentedPath = executablePath.fileSystemRepresentation
        let fileSystemPath = FileManager.default.string(withFileSystemRepresentation: fileSystemRepresentedPath, length: Int(strlen(fileSystemRepresentedPath)))
        Process.launchedProcess(launchPath: fileSystemPath, arguments: [])
        NSApp.terminate(self)
    }
}
