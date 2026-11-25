import Foundation
import SuiteCore

public struct FileItem: Hashable, Sendable, SortableFile {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    /// A directory shown as a single file, such as an .app bundle.
    public let isPackage: Bool
    public let size: Int64?
    public let modified: Date?
    public let isHidden: Bool
    /// The localized type shown in the Type column ("Folder", "PDF document" and so on).
    public let kind: String?
    /// When it was put in its folder (Finder's Date Added), and when it was made.
    public var added: Date?
    public var created: Date?
    /// Finder hides this item's extension (Get Info › Hide extension), when macOS doesn't show them all.
    public var hasHiddenExtension = false
    /// An alias or link to a folder, which Finder keeps with the folders when they come first.
    public var pointsToFolder = false

    public var sortsAsFolder: Bool { isFolder || pointsToFolder }
    /// A Finder alias or a symbolic link.
    public internal(set) var isAlias = false
    /// iCloud Drive or a cloud storage app; nil elsewhere.
    public internal(set) var sync: SyncState?

    /// A folder the user can navigate into (packages open instead).
    public var isFolder: Bool { isDirectory && !isPackage }

    public init(url: URL, name: String, isDirectory: Bool, isPackage: Bool, size: Int64?, modified: Date?,
                isHidden: Bool, kind: String?, isAlias: Bool = false, sync: SyncState? = nil,
                added: Date? = nil, created: Date? = nil, hasHiddenExtension: Bool = false) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.size = size
        self.modified = modified
        self.isHidden = isHidden
        self.kind = kind
        self.isAlias = isAlias
        self.sync = sync
        self.added = added
        self.created = created
        self.hasHiddenExtension = hasHiddenExtension
    }
}

extension FileItem {
    /// The name as shown: without its extension when extensions are hidden, as in Windows ("Report"
    /// for "Report.pdf"). Folders keep theirs; a name that is only an extension (".zshrc") stays whole.
    public func displayName(showingExtension: Bool) -> String {
        guard !showingExtension, !isFolder else { return name }
        let base = (name as NSString).deletingPathExtension
        return base.isEmpty ? name : base
    }

    /// The full name from what was typed in place of the displayed one: the hidden extension comes back.
    public func fullName(fromEdited edited: String, showingExtension: Bool) -> String {
        let shown = displayName(showingExtension: showingExtension)
        guard shown != name else { return edited }
        return edited + "." + (name as NSString).pathExtension
    }
}
