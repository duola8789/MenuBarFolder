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

    /// Keep an installed login item pointing at where the app actually lives.
    ///
    /// The plist records an absolute path to the executable, and the normal
    /// way to install this app is to drag it out of the DMG into
    /// /Applications — so moving, renaming or replacing the app strands the
    /// login item on a path that no longer exists, silently. When the file is
    /// present (that IS the user's "start at login" intent) and the recorded
    /// target differs from this executable, rewrite the target.
    ///
    /// A missing file is left alone: its absence IS the off state, and healing
    /// must never switch the login item on by itself.
    static func healIfNeeded() {
        guard FileManager.default.fileExists(atPath: plistURL.path),
              // Only an app-bundle instance may rewrite this file. A bare
              // binary (the .build/ product) would otherwise point the
              // INSTALLED app's login item at a path that the next
              // `swift build` replaces — or that `rm -rf .build` deletes.
              Bundle.main.bundleURL.pathExtension == "app",
              let exe = Bundle.main.executablePath
        else { return }

        let existing = (try? PropertyListSerialization.propertyList(
            from: Data(contentsOf: plistURL), options: [], format: nil)) as? [String: Any]

        guard let existing else {
            // Unreadable, or not a plist dictionary: rewrite it in the standard
            // shape rather than leave launchd a file it can't act on.
            try? write(agentPlist(executable: exe))
            return
        }
        // Already pointing at us — don't rewrite (keeps this idempotent, and
        // preserves any keys we didn't write).
        guard (existing["ProgramArguments"] as? [String]) != [exe] else { return }

        var updated = existing
        updated["ProgramArguments"] = [exe]
        try? write(updated)
    }

    // MARK: - private

    /// The launch agent description for this app: what `install()` writes, and
    /// what `healIfNeeded()` falls back to when the file on disk is unusable.
    /// Kept in one place so the two can't drift apart.
    private static func agentPlist(executable: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
    }

    private static func write(_ plist: [String: Any]) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
    }

    private static func install() -> Bool {
        guard let exe = Bundle.main.executablePath else {
            NSLog("PinFold: can't resolve executable path for login item")
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try write(agentPlist(executable: exe))
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
