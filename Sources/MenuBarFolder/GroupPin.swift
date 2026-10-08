//
//  GroupPin.swift
//  MenuBarFolder
//
//  One pinned GROUP = one menu-bar icon holding a hand-picked list of member
//  folders. The dropdown is a pure launcher list — one row per member with
//  the usual inline action buttons — and deliberately shows NO directory
//  contents. Hovering a row opens a small action palette (rename + text
//  versions of the actions + remove) instead of a file listing.
//
//  There is no background directory reading here at all: members are few
//  (hand-picked), so bookmark resolution + existence checks happen
//  synchronously in layout(), which runs fresh on every menu open. The store
//  is the single source of truth — GroupPin only remembers its group's id.
//

import AppKit

@MainActor
final class GroupPin: BasePin, NSMenuDelegate {

    let groupID: UUID
    private let store: GroupStore

    /// Rename window shared by the group-name rename and every member-row
    /// rename (lazily created, reused — pattern from FolderMenuDelegate).
    private var renameWindow: FolderAliasWindow?

    init(groupID: UUID, store: GroupStore, app: AppDelegate) {
        self.groupID = groupID
        self.store = store
        super.init(app: app)

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.image = StatusIcon.make(letters: StatusIcon.iconLetters(for: displayName))
            button.toolTip = "MenuBarFolder — \(displayName)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// The group's name: shown in the menu bar icon and tooltip.
    private var displayName: String { store.group(id: groupID)?.name ?? "" }

    /// Re-apply name-derived chrome after a group rename.
    private func refreshChrome() {
        guard let button = statusItem.button else { return }
        button.image = StatusIcon.make(letters: StatusIcon.iconLetters(for: displayName))
        button.toolTip = "MenuBarFolder — \(displayName)"
    }

    override func teardown() {
        renameWindow?.orderOut(nil)
        super.teardown()
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        layout(menu)
    }

    // MARK: menu construction (all synchronous — see header)

    private func layout(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let record = store.group(id: groupID) else { return }

        // 0. Group name header — the icon shows only 1–2 letters, so the
        //    full name needs a home inside the menu (long names ellipsize,
        //    tooltip keeps the whole thing).
        let header = NSMenuItem(title: record.name.ellipsizedMenuTitle(),
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.toolTip = record.name
        menu.addItem(header)

        // 1. App submenu (program controls, display section, add/close).
        menu.addItem(makeAppMenuItem())
        menu.addItem(.separator())

        // 2. One launcher row per member — no directory listing anywhere.
        let aliases = InstancePrefs.aliasSnapshot()
        var rowViews: [ActionRowView] = []
        for (index, data) in record.members.enumerated() {
            let url = GroupStore.resolve(data)
            let onDisk = url.map {
                FileManager.default.fileExists(atPath: $0.path, isDirectory: nil)
            } ?? false

            if let url, onDisk {
                let row = memberRow(for: url, aliases: aliases)
                let item = NSMenuItem()
                item.view = row
                // Hover opens the action palette — while the title click stays
                // an instant "open in Finder". Both on one row is deliberate
                // (unlike subfolder rows, which give the title to the submenu).
                item.submenu = actionPalette(for: url, memberIndex: index,
                                              memberCount: record.members.count,
                                              hasAlias: aliases[url.standardizedFileURL.path] != nil)
                rowViews.append(row)
                menu.addItem(item)
            } else if let url {
                // Bookmark resolves but the folder is gone: keep the last
                // known identity visible; hover offers the only removal path.
                // (Kept enabled-with-no-action on purpose: AppKit won't open
                // the submenu of a disabled item, so "disabled" is expressed
                // by the item having no action instead.)
                let item = NSMenuItem(title: "\(url.displayName) (missing)",
                                      action: nil, keyEquivalent: "")
                item.toolTip = url.path
                item.submenu = removalPalette(memberIndex: index)
                menu.addItem(item)
            } else {
                // Bookmark itself is dead: no known name or path.
                let item = NSMenuItem(title: "(missing)", action: nil, keyEquivalent: "")
                item.submenu = removalPalette(memberIndex: index)
                menu.addItem(item)
            }
        }

        if record.members.isEmpty {
            let empty = NSMenuItem(title: "(no folders yet)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        // Uniform row width so the inline buttons line up in one column.
        if let w = rowViews.map(\.frame.width).max() {
            rowViews.forEach { $0.setCommonWidth(max(w, 260)) }
        }
    }

    /// The launcher row for a live member: title prefers the member's
    /// per-path alias; title click and all four buttons target the folder.
    private func memberRow(for url: URL, aliases: [String: String]) -> ActionRowView {
        let title = aliases[url.standardizedFileURL.path] ?? url.displayName
        let row = ActionRowView(title: title, icon: NSWorkspace.shared.icon(forFile: url.path))
        row.toolTip = url.path
        row.onTitle = { QuickActions.openInFinder(url) }
        row.onFinder = { QuickActions.openInFinder(url) }
        row.onCopy = { QuickActions.copyPath(url) }
        row.onClaude = { QuickActions.openClaude(url) }
        row.onIDEA = { QuickActions.openInIDEA(url) }
        return row
    }

    /// Hover palette for a live member: rename (+ restore when aliased) +
    /// text versions of the four inline actions + manual ordering + remove.
    /// No file listing.
    private func actionPalette(for url: URL, memberIndex: Int,
                                memberCount: Int, hasAlias: Bool) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(memberRenameItem(for: url))
        if hasAlias {
            menu.addItem(restoreNameItem(for: url))
        }
        menu.addItem(.separator())
        menu.addItem(textAction("Open in Finder", url, #selector(paletteFinder(_:))))
        menu.addItem(textAction("Copy Path", url, #selector(paletteCopy(_:))))
        menu.addItem(textAction("Open with Claude Code (iTerm2)", url, #selector(paletteClaude(_:))))
        menu.addItem(textAction("Open in IDEA", url, #selector(paletteIDEA(_:))))
        menu.addItem(.separator())
        if memberIndex > 0 {
            menu.addItem(moveItem("Move Up", memberIndex, #selector(moveMemberUp(_:))))
        }
        if memberIndex < memberCount - 1 {
            menu.addItem(moveItem("Move Down", memberIndex, #selector(moveMemberDown(_:))))
        }
        menu.addItem(removeItem(memberIndex))
        return menu
    }

    /// Minimal hover palette for a missing member: remove is the only action.
    private func removalPalette(memberIndex: Int) -> NSMenu {
        let menu = NSMenu(title: "")
        menu.addItem(removeItem(memberIndex))
        return menu
    }

    private func textAction(_ title: String, _ url: URL, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = url
        return item
    }

    private func removeItem(_ memberIndex: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "Remove from Group",
                              action: #selector(removeMember(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = memberIndex
        return item
    }

    private func moveItem(_ title: String, _ memberIndex: Int, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = memberIndex
        return item
    }

    /// Explicit "clear the alias" affordance — blank-confirm-in-Rename… does
    /// the same thing, but nobody discovers it (first-round verification
    /// feedback). Only shown when an alias actually exists.
    private func restoreNameItem(for url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: "Restore Original Name",
                              action: #selector(restoreName(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = url.standardizedFileURL.path
        item.toolTip = "Clear the alias and show the folder's real name again"
        return item
    }

    private func memberRenameItem(for url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: "Rename…", action: #selector(openMemberRename(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = url.standardizedFileURL.path
        item.toolTip = "Show a different name in the group (the folder itself is not renamed)"
        return item
    }

    // MARK: display section (shown inside the MenuBarFolder submenu)

    /// A group has no listing, so there are no sort/group options — just the
    /// group rename and the member picker.
    override func displaySectionItems() -> [NSMenuItem] {
        let rename = NSMenuItem(title: "Rename…", action: #selector(renameGroup), keyEquivalent: "")
        rename.target = self
        rename.toolTip = "Rename this group (menu-bar icon letters follow the name)"
        let add = NSMenuItem(title: "Add Folder to Group…", action: #selector(addMember), keyEquivalent: "")
        add.target = self
        return [rename, add]
    }

    // MARK: actions

    /// Rename the GROUP itself. A blank confirm keeps the old name (a group
    /// must stay named — unlike a folder alias, blank cannot mean "clear").
    @objc private func renameGroup() {
        let window = renameWindow ?? FolderAliasWindow()
        renameWindow = window
        window.show(prefill: store.group(id: groupID)?.name ?? "") { [weak self] raw in
            guard let self else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            self.store.rename(trimmed, for: self.groupID)
            self.refreshChrome()
            self.app?.notifyPinsChanged()   // live-refresh an open Settings window
        }
    }

    /// Rename a MEMBER folder's per-path alias (same keyspace as folder-pin
    /// aliases; blank confirm clears — same semantics as subfolder rename).
    @objc private func openMemberRename(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let window = renameWindow ?? FolderAliasWindow()
        renameWindow = window
        window.show(prefill: InstancePrefs.options(for: path).alias ?? "") { [weak self] raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            var opts = InstancePrefs.options(for: path)
            opts.alias = trimmed.isEmpty ? nil : trimmed
            InstancePrefs.set(opts, for: path)
            self?.app?.notifyPinsChanged()   // Settings shows the alias too
        }
    }

    @objc private func addMember() {
        guard let url = app?.chooseGroupMemberFolder() else { return }
        store.addMember(url, to: groupID)
        app?.notifyPinsChanged()   // live-refresh an open Settings window
    }

    @objc private func removeMember(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        store.removeMember(at: index, of: groupID)
        app?.notifyPinsChanged()
    }

    @objc private func moveMemberUp(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        store.moveMember(from: index, to: index - 1, of: groupID)
        app?.notifyPinsChanged()
    }

    @objc private func moveMemberDown(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        store.moveMember(from: index, to: index + 1, of: groupID)
        app?.notifyPinsChanged()
    }

    @objc private func restoreName(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        var opts = InstancePrefs.options(for: path)
        opts.alias = nil
        InstancePrefs.set(opts, for: path)
        app?.notifyPinsChanged()   // Settings rows show the real name again
    }

    // Text palette actions — same QuickActions entry points as the inline
    // buttons, so degrade behaviour (missing app → beep) is identical.

    @objc private func paletteFinder(_ sender: NSMenuItem) {
        (sender.representedObject as? URL).map(QuickActions.openInFinder)
    }

    @objc private func paletteCopy(_ sender: NSMenuItem) {
        (sender.representedObject as? URL).map(QuickActions.copyPath)
    }

    @objc private func paletteClaude(_ sender: NSMenuItem) {
        (sender.representedObject as? URL).map(QuickActions.openClaude)
    }

    @objc private func paletteIDEA(_ sender: NSMenuItem) {
        (sender.representedObject as? URL).map(QuickActions.openInIDEA)
    }
}
