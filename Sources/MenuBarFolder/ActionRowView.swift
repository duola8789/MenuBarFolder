//
//  ActionRowView.swift
//  MenuBarFolder
//
//  A custom NSMenuItem view: one row carrying a title area plus four inline
//  action buttons (open in Finder, copy path, open with Claude Code, open in
//  IDEA), so a pinned folder stays a single row instead of growing extra
//  full-width action items.
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
    var onIDEA: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let finderView = NSImageView()
    private let copyView = NSImageView()
    private let claudeView = NSImageView()
    private let ideaView = NSImageView()
    private let buttonWidth: CGFloat = 20
    private let rowHeight: CGFloat = 28

    /// Hover state (custom rows get no system highlight, so we draw our own).
    private var hovered = false {
        didSet {
            needsDisplay = true
            let color: NSColor = hovered ? .white : .labelColor
            titleLabel.textColor = color
            for v in [iconView, finderView, copyView, claudeView, ideaView] { v.contentTintColor = color }
        }
    }

    init(title: String, icon: NSImage?) {
        // Width: leading inset + icon + title (clamped) + four trailing
        // buttons + trailing inset. Insets match standard NSMenuItem content
        // padding so view-backed rows don't sit flush against the menu edge
        // next to regular items.
        let font = NSFont.menuFont(ofSize: 0)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        var width = 40 + min(titleWidth, 300) + 14 + buttonWidth * 4 + 20
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

        for (v, symbol) in [(finderView, "folder"), (copyView, "doc.on.doc"), (claudeView, "terminal"), (ideaView, "curlybraces")] {
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
        NSRect(x: bounds.width - buttonWidth - 8, y: 6, width: buttonWidth, height: 16)
    }
    private var copyFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth * 2 - 12, y: 6, width: buttonWidth, height: 16)
    }
    private var claudeFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth * 3 - 16, y: 6, width: buttonWidth, height: 16)
    }
    private var ideaFrame: NSRect {
        NSRect(x: bounds.width - buttonWidth * 4 - 20, y: 6, width: buttonWidth, height: 16)
    }

    override func layout() {
        super.layout()
        // Leading inset 16pt — tuned by eye against the standard menu
        // items above (user-directed value, not a guessed constant).
        iconView.frame = NSRect(x: 16, y: 6, width: 16, height: 16)
        let titleX: CGFloat = iconView.image == nil ? 16 : 40
        let titleW = ideaFrame.minX - 10 - titleX
        titleLabel.frame = NSRect(x: titleX, y: 6, width: titleW, height: 16)
        finderView.frame = finderFrame
        copyView.frame = copyFrame
        claudeView.frame = claudeFrame
        ideaView.frame = ideaFrame
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
        } else if ideaFrame.contains(p) {
            onIDEA?()
        } else if onTitle != nil {
            onTitle?()
        } else {
            return   // submenu row: let menu tracking own the click
        }
        enclosingMenuItem?.menu?.cancelTracking()
    }
}
