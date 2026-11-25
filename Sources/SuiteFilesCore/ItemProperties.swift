import Foundation

/// What a Windows "Properties" window shows for a file or folder.
public struct ItemProperties: Sendable {
    public let url: URL
    public let name: String
    public let kind: String?
    public let isFolder: Bool
    /// Files only: a folder's size comes from `FolderMeasure`.
    public let size: Int64?
    public let sizeOnDisk: Int64?
    public let created: Date?
    public let modified: Date?
    public let accessed: Date?
    public let isHidden: Bool
    public let isReadOnly: Bool

    public var location: URL { url.deletingLastPathComponent() }

    public static func load(_ url: URL) throws -> ItemProperties {
        let values = try url.resourceValues(forKeys: [
            .localizedNameKey, .localizedTypeDescriptionKey, .isDirectoryKey, .isPackageKey, .fileSizeKey,
            .totalFileAllocatedSizeKey, .creationDateKey, .contentModificationDateKey, .contentAccessDateKey,
            .isHiddenKey, .isWritableKey, .isUserImmutableKey,
        ])
        let isFolder = values.isDirectory == true && values.isPackage != true
        return ItemProperties(
            url: url,
            name: url.lastPathComponent,
            kind: values.localizedTypeDescription,
            isFolder: isFolder,
            size: isFolder ? nil : values.fileSize.map(Int64.init),
            sizeOnDisk: isFolder ? nil : values.totalFileAllocatedSize.map(Int64.init),
            created: values.creationDate,
            modified: values.contentModificationDate,
            accessed: values.contentAccessDate,
            isHidden: values.isHidden == true,
            isReadOnly: values.isWritable == false || values.isUserImmutable == true
        )
    }
}

/// A folder's total size and what it contains, everything included (hidden files too), as Windows counts.
public struct FolderContents: Equatable, Sendable {
    public var size: Int64 = 0
    public var sizeOnDisk: Int64 = 0
    public var files = 0
    public var folders = 0

    public init() {}
}

public enum FolderMeasure {
    /// Walks the whole tree, so it can take a while: call it off the main thread. Unreadable parts are skipped.
    public static func measure(_ folder: URL, isCancelled: () -> Bool = { false }) -> FolderContents {
        var contents = FolderContents()
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                          options: [], errorHandler: { _, _ in true })
        else { return contents }
        for case let url as URL in walker {
            if isCancelled() { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                contents.folders += 1
            } else {
                contents.files += 1
                contents.size += Int64(values.fileSize ?? 0)
                contents.sizeOnDisk += Int64(values.totalFileAllocatedSize ?? 0)
            }
        }
        return contents
    }
}
