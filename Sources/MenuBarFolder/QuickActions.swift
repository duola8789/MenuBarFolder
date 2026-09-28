//
//  QuickActions.swift
//  MenuBarFolder
//
//  The row-level quick actions, shared by the pin title row and the
//  subfolder rows: open a folder in Finder, copy its POSIX path, open a
//  new iTerm2 window cd'd to it with `claude` running, and open it as a
//  project in IntelliJ IDEA.
//

import AppKit

enum QuickActions {

    /// Open the folder in a Finder window.
    static func openInFinder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Copy the folder's path to the clipboard.
    static func copyPath(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    /// Open a new iTerm2 window cd'd to this folder and start `claude`.
    /// Two-step form: `create window with default profile command "..."` fails
    /// silently on iTerm 3.6.11, so we create the window, then type the command
    /// into its (interactive, login) session — which also means the user's
    /// shell PATH applies to `claude`. Verified end-to-end incl. quoted paths.
    ///
    /// Cold start: an osascript child of this bundle-less executable cannot
    /// resolve "iTerm2" BY NAME through LaunchServices while the app is quit
    /// (runtime -1728; compile-time -2741 once dictionary terms are involved,
    /// because the dictionary lookup goes through the same by-name path).
    /// So the script is never asked to do that job: if iTerm2 isn't running,
    /// we launch it ourselves via NSWorkspace — the by-bundle-ID path that
    /// works from this process — poll a cheap probe until its scripting
    /// interface answers (the launch callback alone doesn't mean that), and
    /// only then send the window script, which then talks to the RUNNING app
    /// (process-table resolution, verified working).
    static func openClaude(_ url: URL) {
        guard let itermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") else {
            NSSound.beep()
            return
        }
        let command = applescriptEscaped("cd \(shellQuoted(url.path)) && claude")
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2").isEmpty
        if running {
            runScript(windowScript(command, reuseIdleLaunchWindow: false))
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: itermURL, configuration: config) { _, _ in
            waitUntilScriptable()
            runScript(windowScript(command, reuseIdleLaunchWindow: true))
        }
    }

    /// The AppleScript that opens a window cd'd to the folder and starts
    /// `claude`. `write text` goes into the (interactive, login) session, so
    /// the user's shell PATH applies to `claude`. Verified end-to-end incl.
    /// quoted paths.
    ///
    /// After a cold launch, iTerm2 has already opened its own default window —
    /// reusing it avoids stacking a second, empty one. Only when it is the
    /// SINGLE window with an idle session, though: a session-restore crowd
    /// must not be hijacked, and a busy session gets a fresh window instead
    /// of having `cd … && claude` typed into whatever is running there.
    /// Wherever a window is targeted, it is targeted BY REFERENCE (`window 1`
    /// or the window `create window` RETURNS) — never via "current window",
    /// which is resolved dynamically and can point at another window while
    /// the new one is being opened, leaving an empty shell window behind.
    private static func windowScript(_ command: String, reuseIdleLaunchWindow: Bool) -> String {
        let write = "write text \"\(command)\""
        let body: String
        if reuseIdleLaunchWindow {
            body = """
            if (count of windows) is 1 and not (is processing of current session of window 1) then
                tell current session of window 1 to \(write)
            else
                set w to create window with default profile
                tell current session of w to \(write)
            end if
            """
        } else {
            body = """
            set w to create window with default profile
            tell current session of w to \(write)
            """
        }
        return """
        tell application id "com.googlecode.iterm2"
            activate
        \(body)
        end tell
        """
    }

    /// Fire the window script at iTerm2.
    private static func runScript(_ source: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        try? task.run()
    }

    /// Block (on a background thread) until iTerm2 answers a cheap Apple
    /// Event, so the window script doesn't race the app's startup.
    ///
    /// Ready means TWO things: the app answers at all (phase 1), AND its own
    /// launch window exists with an IDLE session (phase 2). Creating our
    /// window before iTerm's default one appears leaves TWO windows behind;
    /// and a still-`is processing` session means the login shell is starting
    /// up — the reuse check in the window script would read it as busy and
    /// open a second window. Phase 2 is capped short for setups where iTerm
    /// is configured not to open a window at launch: then we fall through
    /// and the window script creates one.
    private static func waitUntilScriptable() {
        // Phase 1: the app answers Apple Events at all — the launch callback
        // only means the launch was accepted, not that scripting works.
        var answered = false
        for _ in 0..<200 where !answered {  // 10 s max at ~20 probes/s
            answered = windowCount() != nil
            if !answered { Thread.sleep(forTimeInterval: 0.05) }
        }
        guard answered else { return }
        // Phase 2: iTerm's own launch window is up AND its session has gone
        // idle (up to 5 s more — beyond that, either the app opens no launch
        // window or the session never settles, and the window script should
        // just create a fresh one). The wait itself is shell startup time
        // (login zsh init), which we can only poll tightly, not shorten.
        for _ in 0..<100 {
            if launchWindowIdle() == true { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    /// True when iTerm2's launch window exists and its session is idle;
    /// false when it exists but is still busy; nil when unreachable.
    private static func launchWindowIdle() -> Bool? {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        probe.arguments = ["-e", """
        tell application id "com.googlecode.iterm2"
            if (count of windows) is 0 then return false
            return not (is processing of current session of window 1)
        end tell
        """]
        probe.standardError = FileHandle.nullDevice
        let out = Pipe()
        probe.standardOutput = out
        do { try probe.run() } catch { return nil }
        probe.waitUntilExit()
        guard probe.terminationStatus == 0,
              let data = try? out.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return nil }
        return Bool(text)
    }

    /// One cheap probe round-trip: the window count on success, nil when the
    /// app can't be reached yet. iTerm2 is targeted by bundle ID, never by
    /// name: the LS-registered name is "iTerm" while the executable/process
    /// is "iTerm2", so a by-name reference only resolves while the app is
    /// running — with the app quit it fails to compile (-2741) or resolve
    /// (-1728).
    private static func windowCount() -> Int? {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        probe.arguments = ["-e", "tell application id \"com.googlecode.iterm2\" to count windows"]
        probe.standardError = FileHandle.nullDevice
        let out = Pipe()
        probe.standardOutput = out
        do { try probe.run() } catch { return nil }
        probe.waitUntilExit()
        guard probe.terminationStatus == 0,
              let data = try? out.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let count = Int(text)
        else { return nil }
        return count
    }

    /// Open the folder as a project in IntelliJ IDEA. Modern builds of both
    /// Ultimate and Community report bundle id `com.jetbrains.intellij`, so
    /// whichever edition LaunchServices resolves wins; `.ce` is kept as a
    /// fallback for older installs. Beeps when no IDEA is found.
    static func openInIDEA(_ url: URL) {
        let bundleIDs = ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"]
        guard let appURL = bundleIDs.compactMap({
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }).first else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    /// Single-quote a string for interpolation into a shell command.
    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escape a string for embedding inside an AppleScript double-quoted literal.
    /// Applied AFTER `shellQuoted`, so the shell receives the quoted form intact.
    static func applescriptEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
