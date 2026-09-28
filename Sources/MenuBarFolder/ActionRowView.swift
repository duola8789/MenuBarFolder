//
//  ActionRowView.swift
//  MenuBarFolder
//
//  A custom NSMenuItem view: one row carrying a title area plus three inline
//  action buttons (open in Finder, copy path, open with Claude Code), so a
//  pinned folder stays a single row instead of growing extra full-width
//  action items.
//
//  NSMenu's tracking loop swallows ordinary control events, so the buttons
//  are plain image views and clicks are hit-tested in mouseDown.
//

import AppKit

@MainActor
final class ActionRowView: NSView {

    /// Title-area click. `nil` on rows that own a submenu — hover/click then
    /// belong to the menu tracking (the submenu opens), not to this view.
    var onTitle: (() -> Void)?
    var onFinder: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClaude: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let finderView = NSImageView()
    private let copyView = NSImageView()
    private let claudeView = NSImageView()
    private let buttonWidth: CGFloat = 20
    private let rowHeight: CGFloat = 24

    /// Hover state (custom rows get no system highlight, so we draw our own).
    private var hovered = false {
        didSet {
            needsDisplay = true
            let color: NSColor = hovered ? .white : .labelColor
            titleLabel.textColor = color
            for v in [iconView, finderView, copyView, claudeView] { v.contentTintColor = color }
        }
    }

    init(title: String, icon: NSImage?) {
        // Width: leading icon + title (clamped) + three trailing buttons.
        let font = NSFont.menuFont(ofSize: 0)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        var width = 26 + min(titleWidth, 300) + 14 + buttonWidth * 3 + 12
        width = min(max(width, 200), 400)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))

        if let icon {
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyDown
            addSubview(iconView)
        }

        titleLabel.font = font
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.wraps = false
        titleLabel.stringValue = title
        addSubview(titleLabel)

        for (v, symbol) in [(finderView, "folder"), (copyView, "doc.on.doc"), (claudeView, "terminal")] {
            if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
                img.isTemplate = true
                v.image = img
                v.imageScaling = .scaleProportionallyDown
                v.contentTintColor = .labelColor
                addSubview(v)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    /// Give every row in a menu the same width, so the trailing buttons line
    /// up in one column (row widths otherwise follow their own titles).
    func setCommonWidth(_ width: CGFloat) {
        guard abs(frame.width - width) > 0.5 else { return }
        setFrameSize(NSSize(width: width, height: rowHeight))
        needsLayout = true
    }

    // MARK: layout

    private var finderFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth - 4, y: 4, width: buttonWidth, height: 16)
    }
    private var copyFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth * 2 - 8, y: 4, width: buttonWidth, height: 16)
    }
    private var claudeFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth * 3 - 12, y: 4, width: buttonWidth, height: 16)
    }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(x: 5, y: 4, width: 16, height: 16)
        let titleX: CGFloat = iconView.image == nil ? 5 : 26
        let titleW = claudeFrame.minX - 10 - titleX
        titleLabel.frame = NSRect(x: titleX, y: 4, width: titleW, height: 16)
        finderView.frame = finderFrame
        copyView.frame = copyFrame
        claudeView.frame = claudeFrame
    }

    // MARK: hover highlight

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInActiveApp],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }
    }

    // MARK: click routing

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if finderFrame.contains(p) {
            onFinder?()
        } else if copyFrame.contains(p) {
            onCopy?()
        } else if claudeFrame.contains(p) {
            onClaude?()
        } else if onTitle != nil {
            onTitle?()
        } else {
            return   // submenu row: let menu tracking own the click
        }
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
