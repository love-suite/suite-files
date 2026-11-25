import Foundation

public enum FileTrash {
    /// Moves a file or folder to the Trash and returns the URL it landed at. The ledger remembers where it
    /// came from, for Restore.
    @discardableResult
    public static func moveToTrash(_ url: URL, ledger: TrashLedger? = .shared) throws -> URL {
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        let trashed = (resultURL as URL?) ?? url
        ledger?.record(original: url, trashed: trashed)
        return trashed
    }
}
