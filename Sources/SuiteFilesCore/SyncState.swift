import Foundation

/// Where an item in iCloud Drive or a cloud storage app (Dropbox, OneDrive, Google Drive… on Apple's File
/// Provider) stands, read from public file properties. Shown as a badge on the icon, like the Status
/// column of Windows' OneDrive folders.
public enum SyncState: Equatable, Sendable {
    /// Only in the cloud: opening it downloads it.
    case cloudOnly
    /// On this Mac and up to date.
    case downloaded
    /// Being uploaded or downloaded.
    case syncing
    /// Upload failed, or the cloud has conflicting versions.
    case problem

    public static let resourceKeys: Set<URLResourceKey> = [
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey, .ubiquitousItemHasUnresolvedConflictsKey,
    ]

    /// nil for items that aren't in the cloud.
    public init?(_ values: URLResourceValues?) {
        guard let values, values.isUbiquitousItem == true else { return nil }
        self.init(downloadingStatus: values.ubiquitousItemDownloadingStatus,
                  isDownloading: values.ubiquitousItemIsDownloading == true,
                  isUploading: values.ubiquitousItemIsUploading == true,
                  hasError: values.ubiquitousItemUploadingError != nil,
                  hasConflicts: values.ubiquitousItemHasUnresolvedConflicts == true)
    }

    init(downloadingStatus: URLUbiquitousItemDownloadingStatus?, isDownloading: Bool, isUploading: Bool,
         hasError: Bool, hasConflicts: Bool) {
        if hasError || hasConflicts {
            self = .problem
        } else if isDownloading || isUploading {
            self = .syncing
        } else if downloadingStatus == .notDownloaded {
            self = .cloudOnly
        } else {
            self = .downloaded
        }
    }
}
