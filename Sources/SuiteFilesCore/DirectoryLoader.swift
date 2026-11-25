import Foundation

public enum DirectoryLoader {
    static let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey,
                                         .isHiddenKey, .localizedTypeDescriptionKey, .isAliasFileKey,
                                         .isSymbolicLinkKey, .addedToDirectoryDateKey, .creationDateKey, .hasHiddenExtensionKey] + SyncState.resourceKeys

    /// One item, read from the disk (a search result, a folder to show).
    public static func item(at url: URL) -> FileItem {
        let values = try? url.resourceValues(forKeys: Set(keys))
        var item = FileItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: values?.isDirectory ?? false,
            isPackage: values?.isPackage ?? false,
            size: values?.fileSize.map(Int64.init),
            modified: values?.contentModificationDate,
            isHidden: values?.isHidden ?? false,
            kind: values?.localizedTypeDescription,
            isAlias: values?.isAliasFile == true || values?.isSymbolicLink == true,
            sync: SyncState(values),
            added: values?.addedToDirectoryDate,
            created: values?.creationDate,
            hasHiddenExtension: values?.hasHiddenExtension ?? false
        )
        if item.isAlias { item.pointsToFolder = pointsToFolder(url, symbolicLink: values?.isSymbolicLink == true) }
        return item
    }

    /// Where an alias or link leads is a folder (not a package), without asking to mount a disk.
    private static func pointsToFolder(_ url: URL, symbolicLink: Bool) -> Bool {
        let target = symbolicLink ? url.resolvingSymlinksInPath()
            : (try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]))
        guard let values = try? target?.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else { return false }
        return values.isDirectory == true && values.isPackage != true
    }

    /// Lists a directory: folders first, then natural name order (like Windows Explorer).
    public static func load(_ directory: URL, showHidden: Bool = false) throws -> [FileItem] {
        // The Trash shows all its folders at once (home, iCloud Drive, disks), as in Finder.
        let urls = directory.standardizedFileURL == TrashFolder.url.standardizedFileURL
            ? try TrashFolder.contents(showHidden: showHidden)
            : try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: showHidden ? [] : [.skipsHiddenFiles]
            )
        let items = urls.map { item(at: $0) }
        return items.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
