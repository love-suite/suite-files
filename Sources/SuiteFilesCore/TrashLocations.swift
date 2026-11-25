import Foundation
import SuiteCore

/// The folders the user's Trash gathers, as Finder's does: the home folder's `.Trash` (the Trash's own
/// place, `url`), iCloud Drive's (`~/Library/Mobile Documents/.Trash`, where items deleted from iCloud Drive,
/// and from the Desktop and Documents when they are in iCloud, go) and each disk's `.Trashes/<uid>`.
/// Explorer's Trash (`TrashFolder`) shows them; Suite Settings lists them.
public enum TrashLocations {
    public static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Every folder the Trash gathers, on this Mac.
    public static var all: [URL] {
        let fm = FileManager.default
        let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        return locations(home: fm.homeDirectoryForCurrentUser, volumes: volumes, uid: getuid(),
                         iCloudDrive: includesICloudDrive) { fm.fileExists(atPath: $0.path) }
    }

    /// iCloud Drive's Trash is part of the Trash unless turned off (Settings › Trash).
    public static let iCloudDriveKey = "TrashIncludesICloudDrive"
    public static var includesICloudDrive: Bool {
        SuiteDefaults.explorer.object(forKey: iCloudDriveKey) as? Bool ?? true
    }

    /// The home Trash first, always; then iCloud Drive's and the disks' (not the startup disk's, whose
    /// Trash is the home one), those that exist.
    public static func locations(home: URL, volumes: [URL], uid: uid_t, iCloudDrive: Bool = true,
                                 exists: (URL) -> Bool) -> [URL] {
        let own = home.appendingPathComponent(".Trash", isDirectory: true)
        var others = iCloudDrive ? [home.appendingPathComponent("Library/Mobile Documents/.Trash", isDirectory: true)] : []
        for volume in volumes where volume.standardizedFileURL.path != "/" {
            others.append(volume.appendingPathComponent(".Trashes/\(uid)", isDirectory: true))
        }
        return [own] + others.filter(exists)
    }
}
