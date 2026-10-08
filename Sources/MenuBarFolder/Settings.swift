//
//  Settings.swift
//  MenuBarFolder
//
//  The Settings window: a SwiftUI form hosted in an NSWindow. Centralizes
//  everything that used to live in the status menus — the pinned-folder list,
//  sort order, folder grouping, and Start at Login.
//

import AppKit
import SwiftUI

// MARK: - Model

@MainActor
final class SettingsModel: ObservableObject {

    private weak var app: AppDelegate?

    @Published var startAtLogin: Bool
    @Published var folders: [URL]
    @Published var bookmarks: [BookmarkSource]
    @Published var groups: [GroupStore.GroupRecord]

    init(app: AppDelegate) {
        self.app = app
        self.startAtLogin = LoginItem.isEnabled
        self.folders = app.pinnedFolders
        self.bookmarks = app.bookmarkSources
        self.groups = app.folderGroups
        // Live-refresh the lists when pins are added/removed from a menu.
        // `guard let self` first: older toolchains (Xcode 15.4 on CI) reject
        // referencing the weak `self` capture directly inside a @Sendable Task.
        NotificationCenter.default.addObserver(forName: .mbfPinsChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.reloadLists() }
        }
    }

    /// Re-pull state when the window is re-shown.
    func reload() {
        startAtLogin = LoginItem.isEnabled
        reloadLists()
    }

    func reloadLists() {
        folders = app?.pinnedFolders ?? []
        bookmarks = app?.bookmarkSources ?? []
        groups = app?.folderGroups ?? []
    }

    /// Display label for a bookmark source: "Browser · Profile".
    func label(for source: BookmarkSource) -> String {
        let browser = Browser.by(id: source.browserID)
        let name = browser?.profiles().profiles.first { $0.dir == source.profileDir }?.name ?? source.profileDir
        return "\(browser?.name ?? source.browserID) · \(name)"
    }

    func setStartAtLogin(_ on: Bool) {
        let ok = LoginItem.setEnabled(on)
        startAtLogin = ok ? on : LoginItem.isEnabled
    }

    // Sort order and folder grouping are now per-instance — set from each
    // folder's own "Display" submenu, not here.

    func addFolder() {
        _ = app?.addFolderViaPicker()
        reloadLists()
    }

    func remove(_ url: URL) {
        app?.removeFolderURL(url)
        reloadLists()
    }

    func addBookmarks() {
        app?.addBookmarksViaChooser()
        // The chooser adds asynchronously and posts .mbfPinsChanged on add.
    }

    func removeBookmark(_ source: BookmarkSource) {
        app?.removeBookmarkSource(source)
        reloadLists()
    }

    // Group members — drag to reorder (same persistence the group menu's
    // Move Up/Move Down writes), button to remove.

    func moveGroupMember(_ groupID: UUID, from: Int, to: Int) {
        app?.moveGroupMember(groupID, from: from, to: to)
        reloadLists()
    }

    func removeGroupMember(_ groupID: UUID, at index: Int) {
        app?.removeGroupMember(groupID, at: index)
        reloadLists()
    }

    func addGroupMember(_ groupID: UUID) {
        guard let url = app?.chooseGroupMemberFolder() else { return }
        app?.addGroupMember(url, to: groupID)
        reloadLists()
    }
}

// MARK: - View

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsTab(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 520)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var model: SettingsModel
    @State private var selection: URL?
    @State private var bmSelection: BookmarkSource?

    var body: some View {
        Form {
            Section("Pinned folders") {
                List(selection: $selection) {
                    ForEach(model.folders, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: Self.icon(for: url))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.displayName)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .tag(url)
                    }
                }
                // Show every pinned folder — the form scrolls, the list
                // doesn't (was a fixed 110pt window with inner scrolling).
                .frame(minHeight: CGFloat(max(model.folders.count, 2)) * 28 + 12)

                HStack {
                    Button("Add Folder…") { model.addFolder() }
                    Button("Remove") {
                        if let sel = selection { model.remove(sel); selection = nil }
                    }
                    .disabled(selection == nil)
                    Spacer()
                }
            }

            Section("Folder groups") {
                if model.groups.isEmpty {
                    Text("None yet — use “New Folder Group…” in any PinFold menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.groups) { group in
                    groupRows(group)
                }
            }

            Section("Browser bookmarks") {
                List(selection: $bmSelection) {
                    ForEach(model.bookmarks) { source in
                        Text(model.label(for: source)).tag(source)
                    }
                }
                .frame(minHeight: CGFloat(max(model.bookmarks.count, 2)) * 28 + 12)

                HStack {
                    Button("Add Bookmarks…") { model.addBookmarks() }
                    Button("Remove") {
                        if let sel = bmSelection { model.removeBookmark(sel); bmSelection = nil }
                    }
                    .disabled(bmSelection == nil)
                    Spacer()
                }
            }

            Section("General") {
                Toggle("Start at Login", isOn: Binding(
                    get: { model.startAtLogin },
                    set: { model.setStartAtLogin($0) }))
            }
        }
        .formStyle(.grouped)
    }

    static func icon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

// Folder-groups section content, FLATTENED on purpose: every element (group
// name, each member row, the add button) is a DIRECT child row of the form
// section. Six rounds of screenshots showed that one tall child inside a
// formStyle(.grouped) section (a List, or a VStack bundling everything) gets
// vertically centered/clipped when it outgrows the section's allotted height
// — the group name and buttons kept vanishing. Individual rows are the one
// layout a form is guaranteed to handle: they grow and scroll natively.
extension GeneralSettingsTab {

    /// The direct section children for one group (emits several rows).
    @ViewBuilder
    fileprivate func groupRows(_ group: GroupStore.GroupRecord) -> some View {
        Text(group.name)
            .font(.headline)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
        if group.members.isEmpty {
            Text("No folders yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            // Same display rule as the group menu rows: alias first, real
            // folder name in the path caption below. Drag row A onto row B
            // and A takes B's slot (.draggable/.dropDestination, the system
            // drag pair — List's .onMove needs a List, which is what broke).
            let aliases = InstancePrefs.aliasSnapshot()
            ForEach(Array(group.members.enumerated()), id: \.offset) { index, data in
                memberRow(group: group, aliases: aliases, data: data, index: index)
                    .draggable(String(index))   // Int isn't Transferable
                    .dropDestination(for: String.self) { items, _ in
                        guard let from = items.first.flatMap(Int.init),
                              from != index else { return false }
                        model.moveGroupMember(group.id, from: from, to: index)
                        return true
                    }
            }
        }
        Button("Add Folder…") { model.addGroupMember(group.id) }
            .padding(.top, 2)
    }

    fileprivate func memberRow(group: GroupStore.GroupRecord,
                               aliases: [String: String], data: Data, index: Int) -> some View {
        HStack(spacing: 8) {
            if let url = GroupStore.resolve(data) {
                Image(nsImage: Self.icon(for: url))
                VStack(alignment: .leading, spacing: 0) {
                    Text(aliases[url.standardizedFileURL.path] ?? url.displayName)
                    Text(url.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Image(systemName: "questionmark.square.dashed")
                Text("(missing)").foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.removeGroupMember(group.id, at: index)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: AppIcon.make(size: 128))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)

            VStack(spacing: 3) {
                Text(AppInfo.name).font(.title2).bold()
                Text("Version \(AppInfo.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(AppInfo.summary)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Divider().padding(.vertical, 2)

            VStack(spacing: 6) {
                LabeledLink(label: "Home", title: AppInfo.homepage, url: AppInfo.homepage)
                LabeledLink(label: "Author", title: "\(AppInfo.author) · github.com/ilya000",
                            url: AppInfo.github)
                LabeledLink(label: "Heritage", title: AppInfo.heritageTitle, url: AppInfo.heritageURL)
                HStack(spacing: 6) {
                    Text("License").foregroundStyle(.secondary)
                    Text("\(AppInfo.license) — free and open source")
                }
                .font(.callout)
            }

            Spacer()

            Text("© 2026 \(AppInfo.author)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct LabeledLink: View {
    let label: String
    let title: String
    let url: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            if let u = URL(string: url) {
                Link(title, destination: u)
            } else {
                Text(title)
            }
        }
        .font(.callout)
    }
}

// MARK: - Window

@MainActor
final class SettingsWindowController {

    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var model: SettingsModel?

    func show(app: AppDelegate) {
        if window == nil {
            let model = SettingsModel(app: app)
            self.model = model
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "PinFold Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            self.window = win
        } else {
            model?.reload()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
