//
//  QuickActions.swift
//  MenuBarFolder
//
//  The two row-level quick actions, shared by the pin title row and the
//  subfolder rows: copy a folder's POSIX path, and open a new iTerm2
//  window cd'd to it with `claude` running.
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
    static func openClaude(_ url: URL) {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil else {
            NSSound.beep()
            return
        }
        let command = "cd \(shellQuoted(url.path)) && claude"
        let source = """
        tell application "iTerm2"
            activate
            create window with default profile
            tell current session of current window
                write text "\(applescriptEscaped(command))"
            end tell
        end tell
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        try? task.run()
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
