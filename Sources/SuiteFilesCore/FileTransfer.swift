import Foundation

public enum TransferOperation: Sendable {
    case move, copy
}

/// What to do when an item of the same name is already there, as Windows asks.
public enum ConflictChoice: Sendable {
    case replace, skip, keepBoth
}

public struct TransferResult: Equatable, Sendable {
    /// The items that went, and where each one is now.
    public var sources: [URL] = []
    public var created: [URL] = []
    public var cancelled = false

    public init() {}

    /// What Undo needs to put things back.
    public func operation(_ kind: TransferOperation) -> FileOperation? {
        guard !created.isEmpty else { return nil }
        switch kind {
        case .move: return .moved(from: sources, to: created)
        case .copy: return .copied(sources: sources, copies: created)
        }
    }
}

/// Moving and copying files into a folder, as a drop does.
public enum FileTransfer {
    /// Windows' rule: on the same volume a drop moves, onto another volume it copies.
    /// `forceCopy` (the Option key) always copies.
    public static func defaultOperation(for sources: [URL], into folder: URL, forceCopy: Bool) -> TransferOperation {
        if forceCopy { return .copy }
        let target = volume(of: folder)
        return sources.allSatisfy { volume(of: $0) == target && target != nil } ? .move : .copy
    }

    /// Moves or copies `sources` into `folder`, naming collisions "name (2)". Moving an item already in
    /// `folder`, or a folder into itself or one of its subfolders, is skipped. Returns the new locations.
    @discardableResult
    public static func transfer(_ sources: [URL], into folder: URL, operation: TransferOperation,
                                fileManager: FileManager = .default) throws -> [URL] {
        try run(sources, into: folder, operation: operation, fileManager: fileManager).created
    }

    /// The same, asking what to do when a name is taken (`onConflict` gets the existing item and the
    /// incoming one) and reporting each item before it goes (`progress` returns false to stop there).
    /// Replaced items go to the Trash through `trash`, never erased.
    public static func run(_ sources: [URL], into folder: URL, operation: TransferOperation,
                           fileManager: FileManager = .default,
                           onConflict: (_ existing: URL, _ incoming: URL) -> ConflictChoice = { _, _ in .keepBoth },
                           progress: (_ done: Int, _ next: URL) -> Bool = { _, _ in true },
                           trash: (URL) throws -> URL = { try FileTrash.moveToTrash($0, ledger: nil) })
        throws -> TransferResult {
        let folderPath = folder.standardizedFileURL.path
        var result = TransferResult()
        for (index, source) in sources.enumerated() {
            guard progress(index, source) else {
                result.cancelled = true
                break
            }
            let sourcePath = source.standardizedFileURL.path
            if folderPath == sourcePath || folderPath.hasPrefix(sourcePath + "/") { continue }
            let sameFolder = source.deletingLastPathComponent().standardizedFileURL.path == folderPath
            if operation == .move && sameFolder { continue }
            var destination = folder.appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                // A copy into its own folder is a duplicate: it keeps both without asking, as Windows does.
                switch sameFolder ? .keepBoth : onConflict(destination, source) {
                case .skip:
                    continue
                case .replace:
                    _ = try trash(destination)
                case .keepBoth:
                    destination = CutClipboard.uniqueDestination(named: source.lastPathComponent, in: folder,
                                                                 fileManager: fileManager)
                }
            }
            switch operation {
            case .move: try fileManager.moveItem(at: source, to: destination)
            case .copy: try fileManager.copyItem(at: source, to: destination)
            }
            result.sources.append(source)
            result.created.append(destination)
        }
        return result
    }

    private static func volume(of url: URL) -> NSObject? {
        (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
    }
}
