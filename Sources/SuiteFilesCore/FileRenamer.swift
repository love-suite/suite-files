import Foundation

public enum FileRenamer {
    /// Renames a file or folder in place. Throws if a file with the new name already exists.
    @discardableResult
    public static func rename(_ url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}
