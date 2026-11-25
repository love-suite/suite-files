import Foundation

/// Finder aliases and symbolic links ("shortcuts" in Windows terms).
public enum ShortcutResolver {
    /// The folder a shortcut points to, or nil if `url` is not a shortcut to a folder.
    /// Shortcuts to packages (.app) count as files, like the packages themselves.
    public static func folderTarget(of url: URL) -> URL? {
        let kind = try? url.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
        guard kind?.isAliasFile == true || kind?.isSymbolicLink == true,
              let target = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]),
              let values = try? target.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
              values.isDirectory == true, values.isPackage != true
        else { return nil }
        return target
    }
}
