import Foundation
import SuiteCore

public enum ViewMode: String, Codable, Sendable, CaseIterable {
    /// Icons, details (a list whose folders unfold), columns (Finder's column view).
    case icons, details, columns
}

/// How a folder is shown: what Windows remembers per folder.
public struct FolderViewOptions: Codable, Equatable, Sendable {
    public var mode: ViewMode = .details
    public var sortKey: SortKey = .name
    public var ascending = true
    /// Details column widths, by column identifier.
    public var columnWidths: [String: Double] = [:]

    public init() {}

    /// Choosing the current sort key again reverses it, like clicking a column header twice.
    public mutating func sort(by key: SortKey) {
        if key == sortKey {
            ascending.toggle()
        } else {
            sortKey = key
            ascending = true
        }
    }
}

/// Remembers view options per folder. Folders never customized use the default options.
public final class FolderViewStore {
    /// Shared by the desktop and Explorer windows, so a folder looks the same wherever it is shown.
    public static let shared = FolderViewStore()
    /// Posted after options are saved or applied to all folders.
    public static let didChange = Notification.Name("FolderViewStoreDidChange")

    private let defaults: UserDefaults
    private static let perFolderKey = "FolderViewOptions"
    private static let defaultKey = "DefaultFolderViewOptions"

    public init(defaults: UserDefaults = SuiteDefaults.explorer) {
        self.defaults = defaults
    }

    public var defaultOptions: FolderViewOptions {
        decode(defaults.data(forKey: Self.defaultKey)) ?? FolderViewOptions()
    }

    public func options(for folder: URL) -> FolderViewOptions {
        decode(perFolder[Self.key(folder)]) ?? defaultOptions
    }

    public func save(_ options: FolderViewOptions, for folder: URL) {
        var all = perFolder
        all[Self.key(folder)] = try? JSONEncoder().encode(options)
        defaults.set(all, forKey: Self.perFolderKey)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    /// Makes `options` the default and forgets every folder's own options, like Windows' "Apply to Folders".
    public func applyToAll(_ options: FolderViewOptions) {
        defaults.set(try? JSONEncoder().encode(options), forKey: Self.defaultKey)
        defaults.removeObject(forKey: Self.perFolderKey)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private var perFolder: [String: Data] {
        defaults.dictionary(forKey: Self.perFolderKey) as? [String: Data] ?? [:]
    }

    private func decode(_ data: Data?) -> FolderViewOptions? {
        data.flatMap { try? JSONDecoder().decode(FolderViewOptions.self, from: $0) }
    }

    /// "/a", "/a/" and "/a/b/.." are the same folder; a place that isn't one (Recents) goes by its address.
    private static func key(_ folder: URL) -> String {
        guard folder.isFileURL else { return folder.absoluteString }
        let path = folder.standardizedFileURL.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
