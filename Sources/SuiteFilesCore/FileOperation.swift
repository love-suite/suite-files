import Foundation

/// A file operation that can be undone, then redone, as Windows' Ctrl+Z and Ctrl+Y do in Explorer.
public enum FileOperation: Equatable, Sendable, Codable {
    /// Items moved: `from[i]` went to `to[i]`.
    case moved(from: [URL], to: [URL])
    /// Copies made (undoing trashes them; redoing copies again from the sources).
    case copied(sources: [URL], copies: [URL])
    case renamed(from: URL, to: URL)
    /// Items moved to the Trash: `originals[i]` is now `trashed[i]`.
    case trashed(originals: [URL], trashed: [URL])
    /// New items (New Folder, new files): undoing trashes them.
    case created([URL])

    /// The name for Edit › Undo and Redo.
    public var actionName: String {
        switch self {
        case .moved: return "Move"
        case .copied: return "Copy"
        case .renamed: return "Rename"
        case .trashed: return "Move to Trash"
        case .created: return "New Item"
        }
    }

    /// Undoes the operation and returns the one whose undoing redoes it. `trash` moves an item to the
    /// Trash and returns where it went (injected so tests don't touch the real Trash).
    public func undo(fileManager: FileManager = .default,
                     trash: (URL) throws -> URL = { try FileTrash.moveToTrash($0) }) throws -> FileOperation {
        switch self {
        case .moved(let from, let to):
            for (current, previous) in zip(to, from) {
                try fileManager.createDirectory(at: previous.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
                try fileManager.moveItem(at: current, to: previous)
            }
            return .moved(from: to, to: from)
        case .renamed(let from, let to):
            try fileManager.moveItem(at: to, to: from)
            return .renamed(from: to, to: from)
        case .trashed(let originals, let trashed):
            // Put back; redoing trashes them again.
            for (item, original) in zip(trashed, originals) {
                try fileManager.createDirectory(at: original.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
                try fileManager.moveItem(at: item, to: original)
            }
            TrashLedger.shared.forget(trashed)
            return .created(originals)
        case .copied(_, let items), .created(let items):
            // Undoing a copy or a new item sends it to the Trash, so nothing is lost; redoing puts it back.
            return .trashed(originals: items, trashed: try items.map(trash))
        }
    }
}
