//
//  AppInfo.swift
//  MenuBarFolder
//
//  Single source of truth for the app's identity, shown in the About tab.
//

import Foundation

enum AppInfo {
    static let name = "PinFold"
    static let version = "1.5.2"  // tag-driven release: CI builds and publishes on annotated tag push
    static let tagline = "Pin your folders to the menu bar."

    static let author = "iLya Os"
    static let homepage = "http://ctrl8.com/MenuBarFolder"
    static let github = "https://github.com/ilya000"
    static let license = "MIT"

    /// Entry point for "Check for Updates": the latest published GitHub
    /// release. Follows its redirect to /releases/tag/<tag>; public page, so
    /// no REST-API rate limit applies.
    static let updateLatestPageURL = "https://github.com/duola8789/MenuBarFolder/releases/latest"

    /// Lineage: the 1998 Windows ancestor of this app.
    static let heritageTitle = "Successor to TrayMenu (1998)"
    static let heritageURL = "https://old.osipov.ru/proge.htm"

    static let summary = """
    PinFold pins your hand-picked folders to the macOS menu bar and lets you \
    act on them in one click — open in Finder, copy the path, launch Claude \
    Code or IDEA right into the folder. Folder groups turn the menu bar into \
    a launcher for your projects. Fork of MenuBarFolder (iLya Os, MIT).
    """
}
