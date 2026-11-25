import Foundation

/// The folders File Provider apps (Google Drive, OneDrive, Dropbox) keep in ~/Library/CloudStorage, named
/// "<Provider>-<account>", shown in the sidebar by provider as Finder does.
public enum CloudStorage {
    /// "GoogleDrive-me@example.com" → "Google Drive"; "OneDrive-Personal" → "OneDrive"; "Dropbox" → "Dropbox".
    public static func displayName(ofFolderNamed folder: String) -> String {
        let provider = folder.split(separator: "-", maxSplits: 1).first.map(String.init) ?? folder
        guard provider != "OneDrive", provider.count > "Drive".count, provider.hasSuffix("Drive") else { return provider }
        return provider.dropLast("Drive".count) + " Drive"
    }

    /// The accounts in use: a folder File Provider no longer serves (the copy macOS leaves, dated, when an
    /// account is set up again) isn't an iCloud-like item any more.
    public static func folders(in storage: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isUbiquitousItemKey]
        let contents = (try? FileManager.default.contentsOfDirectory(at: storage, includingPropertiesForKeys: keys,
                                                                    options: [.skipsHiddenFiles])) ?? []
        return contents.filter { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isDirectory == true && values?.isUbiquitousItem == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
