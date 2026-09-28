//
//  FolderAliasWindow.swift
//  MenuBarFolder
//
//  A tiny panel with a text field for editing a pinned folder's display
//  alias. Pure AppKit; only the popup/focus handling follows the
//  BrowserBookmarksWindow pattern (activate + makeKeyAndOrderFront).
//

import AppKit

@MainActor
final class FolderAliasWindow: NSPanel {

    private let textField = NSTextField()
    private let confirmButton = NSButton(title: "Rename", target: nil, action: nil)

    /// The text currently in the field.
    var text: String { textField.stringValue }

    /// Called with the raw field content when the user confirms; the window
    /// closes itself afterwards. Trimming/clearing semantics live with the
    /// caller. Cancel leaves the value untouched.
    private var onConfirm: ((String) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 340, height: 112),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "Rename Folder"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelEdit))
        cancel.keyEquivalent = "\u{1b}"
        confirmButton.target = self
        confirmButton.action = #selector(confirmEdit)
        confirmButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, confirmButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 14, right: 16)
        stack.addView(textField, in: .leading)
        stack.addView(buttons, in: .trailing)
        contentView = stack
        textField.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true

        // Enter in the field confirms, same as the button.
        textField.target = self
        textField.action = #selector(confirmEdit)
    }

    /// Show pre-filled with the current alias. Confirming (Rename button or
    /// Enter) fires `onConfirm` with the raw field content; the window closes.
    func show(prefill: String, onConfirm: @escaping (String) -> Void) {
        self.onConfirm = onConfirm
        textField.stringValue = prefill

        NSApp.activate(ignoringOtherApps: true)
        center()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textField)
        textField.selectText(nil)
    }

    // MARK: actions

    @objc private func cancelEdit() { orderOut(nil) }

    @objc private func confirmEdit() {
        onConfirm?(text)
        orderOut(nil)
    }

    /// Escape in the text field bubbles up here.
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
