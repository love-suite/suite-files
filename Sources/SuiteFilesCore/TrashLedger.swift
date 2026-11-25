import Foundation
import SuiteCore

/// The user's Trash. Like Finder's, it gathers several folders: the home folder's `.Trash` (the Trash's own
/// place, `url`), iCloud Drive's (`~/Library/Mobile Documents/.Trash`, where items deleted from iCloud Drive,
/// and from the Desktop and Documents when they are in iCloud, go) and each disk's `.Trashes/<uid>`.
public enum TrashFolder {
    /// Where the Trash's folders are (`TrashLocations`, which Suite Settings reads too).
    public static var url: URL { TrashLocations.url }

    /// Every folder the Trash gathers, on this Mac.
    public static var locations: [URL] { TrashLocations.all }

    public static func locations(home: URL, volumes: [URL], uid: uid_t, iCloudDrive: Bool = true,
                                 exists: (URL) -> Bool) -> [URL] {
        TrashLocations.locations(home: home, volumes: volumes, uid: uid, iCloudDrive: iCloudDrive, exists: exists)
    }

    /// True for a Trash folder itself and anything inside one.
    public static func contains(_ url: URL, trashes: [URL] = TrashFolder.locations) -> Bool {
        let path = url.standardizedFileURL.path
        return trashes.contains { trash in
            let own = trash.standardizedFileURL.path
            return path == own || path.hasPrefix(own + "/")
        }
    }

    /// True for a Trash folder itself.
    public static func isTrashFolder(_ url: URL, trashes: [URL] = TrashFolder.locations) -> Bool {
        trashes.contains { $0.standardizedFileURL.path == url.standardizedFileURL.path }
    }

    /// Only what is already in the Trash can be erased: everything else has to go through the Trash first.
    public static func partition(_ urls: [URL], trashes: [URL] = TrashFolder.locations)
        -> (inTrash: [URL], outside: [URL]) {
        let inside = urls.filter { contains($0, trashes: trashes) && !isTrashFolder($0, trashes: trashes) }
        return (inside, urls.filter { !inside.contains($0) })
    }

    /// What the Trash holds, from all its folders; the home one's error (Full Disk Access) is passed on.
    public static func contents(of trashes: [URL] = TrashFolder.locations, showHidden: Bool = false,
                                fileManager: FileManager = .default) throws -> [URL] {
        var items: [URL] = []
        for (index, trash) in trashes.enumerated() {
            let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
            do {
                items += try fileManager.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: options)
            } catch where index > 0 {
                continue
            }
        }
        return items
    }

    /// Erases everything in the Trash for good, hidden files included; returns failed items with their errors.
    @discardableResult
    public static func empty(_ trashes: [URL] = TrashFolder.locations, fileManager: FileManager = .default) throws
        -> [URL: Error] {
        erase(try contents(of: trashes, showHidden: true, fileManager: fileManager), fileManager: fileManager)
    }

    /// Erases items for good (Delete in Windows' Recycle Bin); returns failed items with their errors.
    @discardableResult
    public static func erase(_ items: [URL], fileManager: FileManager = .default) -> [URL: Error] {
        var failed: [URL: Error] = [:]
        for item in items {
            do { try fileManager.removeItem(at: item) } catch { failed[item] = error }
        }
        TrashLedger.shared.forget(items)
        return failed
    }
}

/// Where items in the Trash came from, so they can be restored, as in Windows' Recycle Bin: Explorer's own
/// record of what it deleted, then Finder's (`FinderTrashRecords`) for what Finder and other apps deleted.
public final class TrashLedger {
    /// The record every app of the suite writes to when it trashes something (`SuiteTrash`).
    public static let shared = TrashLedger(file: SuiteTrash.ledgerFile)

    private let file: URL
    /// Trashed path → original path.
    private var origins: [String: String]

    /// Finder's record, looked up for items Explorer didn't delete.
    private let finderOrigin: (URL) -> URL?

    public init(file: URL, finderOrigin: @escaping (URL) -> URL? = FinderTrashRecords.originalLocation) {
        self.file = file
        self.finderOrigin = finderOrigin
        origins = SuiteTrash.readLedger(file)
    }

    public func record(original: URL, trashed: URL) {
        origins[trashed.standardizedFileURL.path] = original.standardizedFileURL.path
        save()
    }

    public func originalLocation(of trashed: URL) -> URL? {
        origins[trashed.standardizedFileURL.path].map { URL(fileURLWithPath: $0) } ?? finderOrigin(trashed)
    }

    public func canPutBack(_ trashed: URL) -> Bool {
        originalLocation(of: trashed) != nil && FileManager.default.fileExists(atPath: trashed.path)
    }

    /// Moves the item back where it was, recreating its folder if needed; a name taken since then gets
    /// a number. Returns where it is now.
    @discardableResult
    public func putBack(_ trashed: URL, fileManager: FileManager = .default) throws -> URL {
        guard let original = originalLocation(of: trashed) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: trashed.path])
        }
        let folder = original.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = fileManager.fileExists(atPath: original.path)
            ? CutClipboard.uniqueDestination(named: original.lastPathComponent, in: folder, fileManager: fileManager)
            : original
        try fileManager.moveItem(at: trashed, to: destination)
        forget([trashed])
        return destination
    }

    public func forget(_ trashed: [URL]) {
        let before = origins.count
        trashed.forEach { origins[$0.standardizedFileURL.path] = nil }
        if origins.count != before { save() }
    }

    private func save() {
        SuiteTrash.writeLedger(origins, to: file)
    }
}
