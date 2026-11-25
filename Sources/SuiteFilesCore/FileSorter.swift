import Foundation

public enum SortKey: String, Codable, CaseIterable, Sendable {
    case name, modified, size, kind
    /// When the item was put in its folder, and when it was made: Finder's Date Added and Date Created.
    case added, created
}

/// What sorting looks at in an item: Explorer's `FileItem`, a file of the folder Viewer steps through.
public protocol SortableFile {
    var name: String { get }
    /// A folder that opens as a folder (packages sort as files).
    var isFolder: Bool { get }
    var size: Int64? { get }
    var modified: Date? { get }
    /// The localized type shown in the Type column.
    var kind: String? { get }
    /// When the item was put in its folder (Finder's Date Added).
    var added: Date? { get }
    var created: Date? { get }
    /// Kept with the folders when folders come first: a folder, or an alias to one, as Finder counts it.
    var sortsAsFolder: Bool { get }
}

extension SortableFile {
    public var added: Date? { nil }
    public var created: Date? { nil }
    public var sortsAsFolder: Bool { isFolder }
}

/// How a folder's items are ordered for a sort key, wherever the folder is shown.
public enum FileSorter {
    /// With `foldersFirst`, folders (and aliases to them) come first, as Windows always does and Finder does
    /// when its Keep folders on top is on. Ties are broken by name, A to Z.
    public static func sorted<Item: SortableFile>(_ items: [Item], by key: SortKey, ascending: Bool,
                                                  foldersFirst: Bool = true) -> [Item] {
        items.sorted { a, b in
            if foldersFirst, a.sortsAsFolder != b.sortsAsFolder { return a.sortsAsFolder }
            let order = compare(a, b, by: key)
            if order == .orderedSame {
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            return order == (ascending ? .orderedAscending : .orderedDescending)
        }
    }

    private static func compare<Item: SortableFile>(_ a: Item, _ b: Item, by key: SortKey) -> ComparisonResult {
        switch key {
        case .name: return a.name.localizedStandardCompare(b.name)
        case .modified: return compare(a.modified, b.modified)
        case .size: return compare(a.size, b.size)
        case .kind: return (a.kind ?? "").localizedStandardCompare(b.kind ?? "")
        case .added: return compare(a.added, b.added)
        case .created: return compare(a.created, b.created)
        }
    }

    /// Missing values (folders have no size) sort before present ones.
    private static func compare<T: Comparable>(_ a: T?, _ b: T?) -> ComparisonResult {
        switch (a, b) {
        case let (a?, b?): return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedAscending
        case (_, nil): return .orderedDescending
        }
    }
}
