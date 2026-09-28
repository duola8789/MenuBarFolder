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

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 340, height: 112),
                   styleMask: [.titled, .closable],
                   backing: .buffered, defer: false)
        title = "Rename Folder"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelEdit))
        cancel.keyEquivalent = "\u{1b}"
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
    }

    /// Show pre-filled with the current alias. Enter in the field and the
    /// Rename button both fire `confirmAction` on `confirmTarget` (the owning
    /// FolderPin); the target is weakly held, per NSControl semantics.
    func show(prefill: String, confirmTarget: AnyObject, confirmAction: Selector) {
        textField.stringValue = prefill
        textField.target = confirmTarget
        textField.action = confirmAction
        confirmButton.target = confirmTarget
        confirmButton.action = confirmAction

        NSApp.activate(ignoringOtherApps: true)
        center()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textField)
        textField.selectText(nil)
    }

    // MARK: actions

    @objc private func cancelEdit() { orderOut(nil) }

    /// Escape in the text field bubbles up here.
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
