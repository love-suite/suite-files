import Foundation

/// Where a search looks, as in Finder's "Search: This Mac | “Folder”": the whole Mac, the current folder,
/// another folder open in the window, or all of them at once.
public struct SearchScope: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case thisMac, currentFolder, otherFolder, openFolders
    }

    public let kind: Kind
    /// The folders searched; empty for the whole Mac.
    public let folders: [URL]
    public let title: String

    /// The choices offered while searching from `current`, with the other folders open in the window
    /// (the other side, the other tabs): this Mac, each open folder, then all of them.
    /// Places that aren't folders (Recents) can't be searched in: from one, the search is over this Mac
    /// or the folders open elsewhere.
    public static func choices(current: URL, open: [URL], name: (URL) -> String) -> [SearchScope] {
        let hasCurrent = current.isFileURL
        var folders: [URL] = hasCurrent ? [current.standardizedFileURL] : []
        for url in open.filter(\.isFileURL).map(\.standardizedFileURL) where !folders.contains(url) {
            folders.append(url)
        }
        var scopes = [SearchScope(kind: .thisMac, folders: [], title: "This Mac")]
        scopes += folders.enumerated().map { index, url in
            SearchScope(kind: index == 0 && hasCurrent ? .currentFolder : .otherFolder, folders: [url],
                        title: "“\(name(url))”")
        }
        if folders.count > 1 {
            scopes.append(SearchScope(kind: .openFolders, folders: folders, title: "All Open Folders"))
        }
        return scopes
    }

    /// The scope a new search starts with: the kind used last time, else the current folder (as in
    /// Windows). Another folder is not remembered: it depends on what is open.
    public static func initial(in choices: [SearchScope], remembered: Kind?) -> SearchScope? {
        let kind = remembered == .otherFolder ? .currentFolder : remembered ?? .currentFolder
        return choices.first { $0.kind == kind } ?? choices.first { $0.kind == .currentFolder } ?? choices.first
    }
}
