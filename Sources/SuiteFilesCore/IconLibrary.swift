import Foundation

/// Where custom icons come from: Apple's own icons (the default library) and a personal library,
/// one per macOS user account.
public enum IconLibrary {
    /// Read from the system at run time, never copied.
    public static let systemIcons = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources")

    static let defaultNames = [
        "GenericFolderIcon", "OpenFolderIcon", "ApplicationsFolderIcon", "DesktopFolderIcon",
        "DocumentsFolderIcon", "DownloadsFolder", "HomeFolderIcon", "LibraryFolderIcon", "MusicFolderIcon",
        "MovieFolderIcon", "PicturesFolderIcon", "PublicFolderIcon", "SitesFolderIcon", "DeveloperFolderIcon",
        "UtilitiesFolder", "SystemFolderIcon", "UsersFolderIcon", "GroupFolder", "SmartFolderIcon",
        "BurnableFolderIcon", "GenericDocumentIcon", "GenericApplicationIcon", "GenericURLIcon", "BookmarkIcon",
        "FavoriteItemsIcon", "Clock", "LockedIcon", "UnlockedIcon", "TrashIcon", "FullTrashIcon", "UserIcon",
        "GroupIcon", "GenericNetworkIcon", "GenericAirDiskIcon", "GenericSpeaker", "GenericFontIcon",
        "AlertNoteIcon", "GenericQuestionMarkIcon", "public.generic-pc",
    ]

    /// The default library: the Apple icons present on this Mac.
    public static var defaultIcons: [URL] {
        defaultNames.map { systemIcons.appendingPathComponent($0 + ".icns") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// The personal library of the current user.
    public static var personalFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Explorer/Icons", isDirectory: true)
    }

    static let imageExtensions: Set<String> = ["icns", "png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp"]

    /// The images in `folder`, by name; nothing if the folder doesn't exist yet.
    public static func icons(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Copies the images among `files` into `folder` (created if needed), renaming on collision.
    /// Returns the copies; other files are skipped.
    @discardableResult
    public static func add(_ files: [URL], to folder: URL, fileManager: FileManager = .default) throws -> [URL] {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return try files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }.map { file in
            let destination = CutClipboard.uniqueDestination(named: file.lastPathComponent, in: folder,
                                                             fileManager: fileManager)
            try fileManager.copyItem(at: file, to: destination)
            return destination
        }
    }
}
