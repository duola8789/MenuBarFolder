//
//  GroupStore.swift
//  MenuBarFolder
//
//  Persists the LIST of folder groups (each = one menu-bar icon holding a
//  hand-picked list of member folders). Members are stored as plain bookmarks
//  for the same reason as FolderStore's pins: a plain bookmark survives the
//  folder being moved or renamed, and keeps working in this non-sandboxed
//  binary (security-scoped bookmarks fail here with NSCocoaErrorDomain 259).
//
//  Unlike FolderStore, members whose bookmark no longer resolves are KEPT
//  (raw Data preserved): a group shows a "(missing)" row for them instead of
//  silently dropping them, and they can still be removed from the group menu.
//

import Foundation

final class GroupStore {

    /// One group: a stable id (the menu-bar pin and its rename target), the
    /// group's display name, and the member bookmarks in add order.
    /// Identifiable so SwiftUI Settings lists can ForEach over groups.
    struct GroupRecord: Codable, Identifiable {
        let id: UUID
        var name: String
        var members: [Data]
    }

    private let key = "folderGroups"     // [GroupRecord] as one JSON blob
    private(set) var groups: [GroupRecord] = []

    init() {
        load()
    }

    // MARK: groups

    func group(id: UUID) -> GroupRecord? {
        groups.first { $0.id == id }
    }

    @discardableResult
    func addGroup(name: String) -> GroupRecord {
        let record = GroupRecord(id: UUID(), name: name, members: [])
        groups.append(record)
        save()
        return record
    }

    func rename(_ name: String, for id: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[i].name = name
        save()
    }

    func remove(id: UUID) {
        groups.removeAll { $0.id == id }
        save()
    }

    // MARK: members

    /// Add a member folder, appended at the end (order = add order). Adding a
    /// path that's already a resolvable member of this group is a no-op.
    func addMember(_ url: URL, to id: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == id }) else { return }
        let url = url.standardizedFileURL
        let existing = Set(groups[i].members.compactMap { Self.resolve($0)?.standardizedFileURL })
        guard !existing.contains(url),
              let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return }
        groups[i].members.append(data)
        save()
    }

    /// Remove by position, not by URL: a member whose bookmark no longer
    /// resolves has no usable path identity, but its slot is still valid.
    func removeMember(at index: Int, of id: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == id }),
              groups[i].members.indices.contains(index) else { return }
        groups[i].members.remove(at: index)
        save()
    }

    /// Move a member to an arbitrary slot — manual ordering (order expresses
    /// use frequency, not dictionary order). The palette passes adjacent
    /// slots for Move Up/Down; the Settings list passes drag destinations.
    /// Out-of-range is a no-op.
    func moveMember(from: Int, to: Int, of id: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == id }),
              groups[i].members.indices.contains(from),
              (0...groups[i].members.count).contains(to) else { return }
        let member = groups[i].members.remove(at: from)
        groups[i].members.insert(member, at: min(to, groups[i].members.count))
        save()
    }

    // MARK: - persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GroupRecord].self, from: data) else { return }
        groups = decoded
        save()   // normalize storage (re-mint live bookmarks)
    }

    /// Re-mint the bookmarks of resolvable members (a moved folder's bookmark
    /// then points at its new location, same normalization FolderStore does),
    /// but keep the raw Data of dead ones — dropping them would silently hide
    /// members the user only removed via the group menu.
    private func save() {
        groups = groups.map { record in
            var r = record
            r.members = r.members.map { data in
                if let url = Self.resolve(data),
                   let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil,
                                                     relativeTo: nil) {
                    return fresh
                }
                return data
            }
            return r
        }
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Resolve a member bookmark. Plain (NOT `.withSecurityScope`) — see the
    /// header comment in FolderStore.swift for why scoped bookmarks fail here.
    static func resolve(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [],
                                  relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        return url.standardizedFileURL
    }
}
