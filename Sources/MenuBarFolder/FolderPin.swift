//
//  FolderPin.swift
//  MenuBarFolder
//
//  One pinned folder = one menu-bar status item with its own dropdown and its
//  OWN display settings (sort order + folder grouping), persisted per folder.
//

import AppKit

@MainActor
final class FolderPin: BasePin, NSMenuDelegate {

    let url: URL
    private let id: String                       // persistence key (folder path)
    private let contentDelegate: FolderMenuDelegate
    private var options: DisplayOptions
    private var listing: DirListing?
    private var aliasWindow: FolderAliasWindow?

    init(url: URL, app: AppDelegate) {
        self.url = url
        self.id = url.standardizedFileURL.path
        self.contentDelegate = FolderMenuDelegate(url: url, owner: app)
        self.options = InstancePrefs.options(for: id)
        super.init(app: app)
        contentDelegate.options = options

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.image = StatusIcon.make(letters: StatusIcon.iconLetters(for: displayName))
            button.toolTip = "PinFold — \(displayName)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// The name shown in the menu bar: the user's alias, or the folder's own
    /// display name. Display-only — the real directory is never touched.
    private var displayName: String { options.alias ?? url.displayName }

    /// Re-apply the alias to the status-bar chrome after it changes. The menu
    /// title needs no help — `layout()` rebuilds it on every open.
    private func refreshChrome() {
        guard let button = statusItem.button else { return }
        button.image = StatusIcon.make(letters: StatusIcon.iconLetters(for: displayName))
        button.toolTip = "PinFold — \(displayName)"
    }

    /// Drop the cached contents so the next open re-reads with current options.
    override func clearCache() { listing = nil }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshListing()
        layout(menu)
    }

    private func refreshListing() {
        let url = self.url
        let maxItems = contentDelegate.maxItems
        let options = self.options
        Task { @MainActor in
            let fresh = await FolderMenuDelegate.readListing(url, maxItems: maxItems, options: options)
            self.listing = fresh
            if let menu = self.statusItem.menu { self.layout(menu) }
        }
    }

    private func layout(_ menu: NSMenu) {
        menu.removeAllItems()
        let url = self.url   // capture for the row's action closures

        // 1. App submenu (program controls).
        menu.addItem(makeAppMenuItem())
        menu.addItem(.separator())

        // 2. The folder itself, as ONE row: title area opens it in Finder,
        //    four inline buttons (copy path, open with Claude Code, open in
        //    IDEA, Finder) at right.
        let row = ActionRowView(title: displayName,
                                icon: NSWorkspace.shared.icon(forFile: url.path))
        row.toolTip = url.path
        row.onTitle = { [weak self] in self?.openInFinder() }
        row.onFinder = { QuickActions.openInFinder(url) }
        row.onCopy = { QuickActions.copyPath(url) }
        row.onClaude = { QuickActions.openClaude(url) }
        row.onIDEA = { QuickActions.openInIDEA(url) }
        let folderItem = NSMenuItem()
        folderItem.view = row
        menu.addItem(folderItem)
        menu.addItem(.separator())

        // 3. Folder contents (cache → instant, else placeholder).
        var contentItems: [NSMenuItem] = []
        if let listing {
            contentItems = contentDelegate.buildItems(from: listing)
            for item in contentItems { menu.addItem(item) }
        } else {
            let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
            loading.isEnabled = false
            menu.addItem(loading)
        }

        // Uniform row width: the title row and the content rows share one
        // width, so the trailing action buttons line up in a single column.
        let rowViews = ([row] + contentItems.compactMap { $0.view as? ActionRowView })
        let commonWidth = max(rowViews.map(\.frame.width).max() ?? 0, 260)
        rowViews.forEach { $0.setCommonWidth(commonWidth) }
    }

    /// This folder's own sort + grouping, shown as a section in the
    /// MenuBarFolder submenu.
    override func displaySectionItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let sortHeader = NSMenuItem(title: "Sort by", action: nil, keyEquivalent: "")
        sortHeader.isEnabled = false
        items.append(sortHeader)
        for mode in SortMode.allCases {
            let mi = NSMenuItem(title: mode.title, action: #selector(setSort(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = mode.rawValue
            mi.state = (mode == options.sort) ? .on : .off
            items.append(mi)
        }
        let fot = NSMenuItem(title: "Folders on top",
                             action: #selector(toggleFoldersOnTop), keyEquivalent: "")
        fot.target = self
        fot.state = options.foldersOnTop ? .on : .off
        items.append(fot)
        items.append(renameMenuItem())
        return items
    }

    private func renameMenuItem() -> NSMenuItem {
        let mi = NSMenuItem(title: "Rename…", action: #selector(renameFolder), keyEquivalent: "")
        mi.target = self
        mi.toolTip = "Show a different name in the menu bar (the folder itself is not renamed)"
        return mi
    }

    // MARK: actions

    @objc private func openInFinder() { NSWorkspace.shared.open(url) }

    @objc private func setSort(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = SortMode(rawValue: raw) else { return }
        options.sort = mode
        persistOptions()
    }

    @objc private func toggleFoldersOnTop() {
        options.foldersOnTop.toggle()
        persistOptions()
    }

    /// Open (or re-open) the rename sheet, pre-filled with the current alias.
    /// Blank/whitespace-only confirm clears the alias; cancel is a no-op.
    @objc private func renameFolder() {
        let window = aliasWindow ?? FolderAliasWindow()
        aliasWindow = window
        window.show(prefill: options.alias ?? "") { [weak self] raw in
            guard let self else { return true }
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            self.options.alias = trimmed.isEmpty ? nil : trimmed
            self.persistOptions()
            self.refreshChrome()
            return true
        }
    }

    private func persistOptions() {
        InstancePrefs.set(options, for: id)
        contentDelegate.options = options
        listing = nil   // re-read with the new order on next open
    }

    override func teardown() {
        aliasWindow?.orderOut(nil)
        super.teardown()
    }
}
