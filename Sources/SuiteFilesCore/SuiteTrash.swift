import Foundation

/// Moving files to the Trash the suite's way: where each item came from is written down, so Explorer's
/// Restore can put it back whichever app of the suite deleted it (Explorer, Viewer).
public enum SuiteTrash {
    /// Where items in the Trash came from (trashed path → original path), which Explorer's `TrashLedger`
    /// reads and keeps.
    public static let ledgerFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Explorer/TrashLedger.json")

    public static func readLedger(_ file: URL = ledgerFile) -> [String: String] {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    public static func writeLedger(_ origins: [String: String], to file: URL = ledgerFile) {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(origins).write(to: file, options: .atomic)
    }

    /// Moves a file or folder to the Trash and returns the URL it landed at, its origin written in the
    /// ledger (`nil`: not recorded).
    @discardableResult
    public static func moveToTrash(_ url: URL, ledger file: URL? = ledgerFile) throws -> URL {
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        let trashed = (resultURL as URL?) ?? url
        if let file {
            var origins = readLedger(file)
            origins[trashed.standardizedFileURL.path] = url.standardizedFileURL.path
            writeLedger(origins, to: file)
        }
        return trashed
    }

    // MARK: Telling the other apps

    /// To the other apps of the suite: an app (Viewer, Bar) moved items to the Trash. They join the shared
    /// Undo history here; Explorer keeps their origins for Restore. The paths are in the user info
    /// (`originals`, `trashed`, in the same order).
    public static let didTrashNotification = Notification.Name("local.suite.files.trashed")

    /// After `moveToTrash` in an app without file views of its own: the items join the shared Undo
    /// history, and the other apps are told.
    public static func announce(originals: [URL], trashed: [URL]) {
        FileUndoJournal.shared.record(.trashed(originals: originals, trashed: trashed))
        FileUndoJournal.announceChange()
        DistributedNotificationCenter.default().postNotificationName(
            didTrashNotification, object: nil,
            userInfo: ["originals": originals.map(\.path), "trashed": trashed.map(\.path)], deliverImmediately: true)
    }

    /// What a `didTrashNotification` says was trashed: only items now in one of the Trash's folders.
    public static func items(of notification: Notification, trashes: [URL] = TrashLocations.all,
                             fileManager: FileManager = .default) -> [(original: URL, trashed: URL)] {
        guard let originals = notification.userInfo?["originals"] as? [String],
              let trashed = notification.userInfo?["trashed"] as? [String], originals.count == trashed.count
        else { return [] }
        let folders = trashes.map(\.standardizedFileURL.path)
        return zip(originals, trashed).compactMap { original, trashed in
            let path = URL(fileURLWithPath: trashed).standardizedFileURL.path
            guard folders.contains(where: { path.hasPrefix($0 + "/") }), fileManager.fileExists(atPath: path)
            else { return nil }
            return (URL(fileURLWithPath: original), URL(fileURLWithPath: trashed))
        }
    }
}
