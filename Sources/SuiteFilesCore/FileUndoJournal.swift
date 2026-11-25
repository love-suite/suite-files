import Darwin
import Foundation

/// One Undo history for every app of the suite that changes files (Explorer's windows, the desktop, Bar,
/// Viewer), as Windows has one: Ctrl+Z undoes the last file operation wherever it was made, even in an app
/// that has quit since. Undoing a file operation is itself a file operation (moving back, putting back
/// from the Trash), so any app can undo what another did. The history is a file, read and written under a
/// lock, so two apps never write it at once; each change is announced (`didChangeNotification`) for the
/// others' Edit menus.
public final class FileUndoJournal: @unchecked Sendable {
    /// An operation as Undo shows it: `name` is what Edit › Undo and Redo say ("Move"), the name of the
    /// operation the user made, also once it is waiting to be redone as its reverse.
    public struct Entry: Codable, Equatable, Sendable {
        public var operation: FileOperation
        public var name: String
        public var date: Date
    }

    struct Stacks: Codable, Equatable {
        var undo: [Entry] = []
        var redo: [Entry] = []
    }

    /// To every app of the suite: the history changed (an operation made, undone or redone).
    public static let didChangeNotification = Notification.Name("local.suite.files.undoDidChange")
    /// How many operations are kept, the oldest forgotten first.
    public static let limit = 100

    public static let defaultFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Suite Files/Undo.json")
    public static let shared = FileUndoJournal(file: defaultFile)

    public let file: URL

    public init(file: URL) { self.file = file }

    /// A new operation: it can be undone; what was undone before can no longer be redone.
    public func record(_ operation: FileOperation, at date: Date = Date()) {
        update { stacks in
            stacks.undo.append(Entry(operation: operation, name: operation.actionName, date: date))
            if stacks.undo.count > Self.limit { stacks.undo.removeFirst(stacks.undo.count - Self.limit) }
            stacks.redo = []
        }
    }

    public var nextUndo: Entry? { read().undo.last }
    public var nextRedo: Entry? { read().redo.last }

    /// Undoes the last operation: `perform` undoes it and returns its reverse, which Redo replays. Nothing to
    /// undo: nil. Should `perform` fail, the history is left as it was.
    @discardableResult
    public func undo(perform: (FileOperation) throws -> FileOperation = { try $0.undo() }) throws -> Entry? {
        try updateThrowing { stacks in
            guard let entry = stacks.undo.last else { return nil }
            let reverse = try perform(entry.operation)
            stacks.undo.removeLast()
            stacks.redo.append(Entry(operation: reverse, name: entry.name, date: Date()))
            return entry
        }
    }

    /// Redoes the last undone operation, as `undo` does the other way.
    @discardableResult
    public func redo(perform: (FileOperation) throws -> FileOperation = { try $0.undo() }) throws -> Entry? {
        try updateThrowing { stacks in
            guard let entry = stacks.redo.last else { return nil }
            let reverse = try perform(entry.operation)
            stacks.redo.removeLast()
            stacks.undo.append(Entry(operation: reverse, name: entry.name, date: Date()))
            return entry
        }
    }

    /// Tells every app of the suite the history changed.
    public static func announceChange() {
        DistributedNotificationCenter.default().postNotificationName(
            didChangeNotification, object: String(ProcessInfo.processInfo.processIdentifier), userInfo: nil,
            deliverImmediately: true)
    }

    // MARK: The file

    func read() -> Stacks {
        (try? withLock { $0 }) ?? Stacks()
    }

    private func update(_ change: (inout Stacks) -> Void) {
        try? updateThrowing { stacks -> Void in change(&stacks) }
    }

    private func updateThrowing<T>(_ change: (inout Stacks) throws -> T) throws -> T {
        try withLock { stacks in
            var changed = stacks
            let result = try change(&changed)
            if changed != stacks { write(changed) }
            return result
        }
    }

    /// Runs `body` on the history as saved, holding an exclusive lock on a file beside it meanwhile.
    private func withLock<T>(_ body: (Stacks) throws -> T) throws -> T {
        let folder = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lock = open(file.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        defer { close(lock) }
        flock(lock, LOCK_EX)
        defer { flock(lock, LOCK_UN) }
        let saved = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Stacks.self, from: $0) } ?? Stacks()
        return try body(saved)
    }

    private func write(_ stacks: Stacks) {
        try? JSONEncoder().encode(stacks).write(to: file, options: .atomic)
    }
}
