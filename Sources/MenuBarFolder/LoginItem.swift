//
//  LoginItem.swift
//  MenuBarFolder
//
//  "Start at Login" implemented as a per-user LaunchAgent. We can't use
//  SMAppService.mainApp here because that requires a real .app bundle; this
//  is a bare executable, so we write a LaunchAgent plist pointing at the
//  current binary and (de)register it with launchctl.
//

import Foundation

enum LoginItem {

    /// Fork identity — deliberately different from upstream's
    /// com.ctrl8.menubarfolder (and from this fork's own pre-rename
    /// label) so up- and downstream can each manage their own login
    /// item without clobbering each other's plist.
    static let label = "com.duola8789.pinfold"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Whether the LaunchAgent is currently installed.
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Install or remove the LaunchAgent. Returns false if a step failed, so
    /// the caller can avoid flipping the checkmark.
    @discardableResult
    static func setEnabled(_ enable: Bool) -> Bool {
        enable ? install() : remove()
    }

    // MARK: - private

    private static func install() -> Bool {
        guard let exe = Bundle.main.executablePath else {
            NSLog("PinFold: can't resolve executable path for login item")
            return false
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
            // Deliberately NO `launchctl load` here: RunAtLoad would make the
            // load itself spawn a SECOND copy of this binary right now, and
            // every status item would appear twice in the menu bar. The plist
            // is picked up by launchd automatically at the next login — the
            // only situation this agent actually needs to start the app. The
            // flock singleton lock in main.swift is the backstop for any
            // accidental double start.
            return true
        } catch {
            NSLog("PinFold: failed to install login item: \(error)")
            return false
        }
    }

    private static func remove() -> Bool {
        guard isEnabled else { return true }
        launchctl(["unload", "-w", plistURL.path])
        do {
            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            NSLog("PinFold: failed to remove login item: \(error)")
            return false
        }
    }

    private static func launchctl(_ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        do { try task.run(); task.waitUntilExit() }
        catch { NSLog("PinFold: launchctl \(args) failed: \(error)") }
    }
}
