import Foundation

/// Cut clipboard: remembers files, then moves them when pasting.
public final class CutClipboard {
    public private(set) var pending: [URL] = []

    public init() {}

    public func cut(_ urls: [URL]) { pending = urls }

    public func clear() { pending = [] }

    /// Moves the cut files into `directory` and returns their new URLs.
    /// A file already in that directory is left untouched; on a name
    /// collision, the moved file becomes "name (2).ext".
    @discardableResult
    public func paste(into directory: URL, fileManager: FileManager = .default) throws -> [URL] {
        var moved: [URL] = []
        for source in pending {
            if source.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
                continue
            }
            let destination = Self.uniqueDestination(named: source.lastPathComponent, in: directory, fileManager: fileManager)
            try fileManager.moveItem(at: source, to: destination)
            moved.append(destination)
        }
        pending = []
        return moved
    }

    static func uniqueDestination(named name: String, in directory: URL, fileManager: FileManager) -> URL {
        var candidate = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        repeat {
            let numbered = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = directory.appendingPathComponent(numbered)
            n += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }
}
