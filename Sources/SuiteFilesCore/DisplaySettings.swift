import Foundation
import SuiteCore

/// Display preferences shared by the desktop and Explorer windows.
public enum DisplaySettings {
    public static let didChange = Notification.Name("ExplorerDisplaySettingsDidChange")
    private static let fullNameKey = "ShowFullNameOfSelection"
    private static let thumbnailsKey = "ShowThumbnails"
    private static let viewerKey = "OpenPicturesInViewer"
    private static let hiddenKey = "ShowHiddenFiles"
    private static let returnKey = "ReturnKeyRenames"
    private static let extensionsKey = "ShowFileExtensions"
    private static let badgesKey = "ShowSyncBadges"
    private static let addressBarHiddenKey = "AddressBarCompletionShowsHiddenFolders"

    /// File names keep their extension ("Report.pdf"); off, they show without it ("Report"), as Windows does.
    /// Until it is chosen, as macOS shows them (`showsFileExtensionsAsMacOS`).
    public static var showsFileExtensions: Bool {
        get { SuiteDefaults.explorer.object(forKey: extensionsKey) as? Bool ?? macOSShowsAllExtensions }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: extensionsKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// File extensions not chosen yet: shown as macOS shows them (Finder's Show all filename extensions; off,
    /// only the extensions hidden file by file are hidden).
    public static var showsFileExtensionsAsMacOS: Bool { SuiteDefaults.explorer.object(forKey: extensionsKey) == nil }

    /// Folders (and aliases to them) before files, in windows: as Finder's Keep folders on top (Finder ›
    /// Settings › Advanced) by default, or always (as Windows) or never.
    public static var foldersFirst: FoldersFirst {
        get { SuiteDefaults.explorer.string(forKey: foldersFirstKey).flatMap(FoldersFirst.init(rawValue:)) ?? .asFinder }
        set {
            SuiteDefaults.explorer.set(newValue.rawValue, forKey: foldersFirstKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }
    private static let foldersFirstKey = "FoldersFirst"
    public static var sortsFoldersFirst: Bool { foldersFirst.sorts(finder: finderBool("_FXSortFoldersFirst")) }
    /// Finder's Keep folders on top for the desktop, which macOS keeps apart from the windows'.
    public static var finderSortsFoldersFirstOnDesktop: Bool { finderBool("_FXSortFoldersFirstOnDesktop") }

    /// File extensions: as macOS shows them (the default), always, or never (as Windows).
    public static var fileExtensions: FileExtensions {
        get {
            guard let shown = SuiteDefaults.explorer.object(forKey: extensionsKey) as? Bool else { return .asMacOS }
            return shown ? .always : .never
        }
        set {
            switch newValue {
            case .asMacOS: SuiteDefaults.explorer.removeObject(forKey: extensionsKey)
            case .always: SuiteDefaults.explorer.set(true, forKey: extensionsKey)
            case .never: SuiteDefaults.explorer.set(false, forKey: extensionsKey)
            }
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Names under icons on two lines, as Finder, a long one cut in the middle; off, on one line.
    public static var namesOnTwoLines: Bool {
        get { SuiteDefaults.explorer.object(forKey: "NamesOnTwoLines") as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: "NamesOnTwoLines")
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// The alias arrow in a white disc, as macOS 27 draws it; off, the arrow alone, as earlier macOS.
    public static var aliasArrowInDisc: Bool {
        get { SuiteDefaults.explorer.object(forKey: "AliasArrowInDisc") as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: "AliasArrowInDisc")
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    private static func finderBool(_ key: String) -> Bool {
        CFPreferencesAppSynchronize("com.apple.finder" as CFString)
        return CFPreferencesCopyAppValue(key as CFString, "com.apple.finder" as CFString) as? Bool ?? false
    }

    /// Finder › Settings › Advanced › Show all filename extensions (a setting of the whole Mac).
    public static var macOSShowsAllExtensions: Bool {
        CFPreferencesCopyAppValue("AppleShowAllExtensions" as CFString, kCFPreferencesAnyApplication) as? Bool ?? false
    }

    /// iCloud Drive and cloud storage items show their state (online only, on this Mac, syncing, a
    /// problem). On by default.
    public static var showsSyncBadges: Bool {
        get { SuiteDefaults.explorer.object(forKey: badgesKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: badgesKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Where the cloud state shows: a coloured disc on the icon, as Windows does, or a grey sign after
    /// the name, as Finder does (nothing for items already on this Mac).
    public enum SyncBadgeStyle: String, CaseIterable, Sendable {
        case onIcon, afterName
    }

    public static var syncBadgeStyle: SyncBadgeStyle {
        get { SuiteDefaults.explorer.string(forKey: "SyncBadgeStyle").flatMap(SyncBadgeStyle.init(rawValue:)) ?? .afterName }
        set {
            SuiteDefaults.explorer.set(newValue.rawValue, forKey: "SyncBadgeStyle")
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// What was deleted from iCloud Drive (and an iCloud Desktop or Documents) shows in the Trash, to be put
    /// back or erased. On by default.
    public static var showsICloudTrash: Bool {
        get { TrashLocations.includesICloudDrive }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: TrashLocations.iCloudDriveKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Hidden files and folders (dot files, system files) are listed, dimmed, as Finder's Cmd+Shift+.
    /// and Explorer's "Hidden items" show them. Off by default.
    public static var showsHiddenFiles: Bool {
        get { SuiteDefaults.explorer.bool(forKey: hiddenKey) }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: hiddenKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Return renames the selected item, as in Finder; off, it opens it, as Enter does in Windows.
    /// On by default; F2 always renames and Cmd+Down always opens.
    public static var returnKeyRenames: Bool {
        get { SuiteDefaults.explorer.object(forKey: returnKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: returnKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Pictures open in Explorer's own viewer rather than in Preview. On by default.
    public static var opensPicturesInViewer: Bool {
        get { SuiteDefaults.explorer.object(forKey: viewerKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: viewerKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Images, videos and documents show a preview of their content instead of their type's icon.
    /// On by default.
    public static var showsThumbnails: Bool {
        get { SuiteDefaults.explorer.object(forKey: thumbnailsKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: thumbnailsKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Hidden folders appear at the end of the address bar's completion list; off, they are omitted.
    /// On by default. Independent from showsHiddenFiles, which controls the file views.
    public static var addressBarCompletionShowsHiddenFolders: Bool {
        get { SuiteDefaults.explorer.object(forKey: addressBarHiddenKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: addressBarHiddenKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Selected items show their whole name instead of a truncated one. On by default.
    public static var showsFullNameOfSelection: Bool {
        get { SuiteDefaults.explorer.object(forKey: fullNameKey) as? Bool ?? true }
        set {
            SuiteDefaults.explorer.set(newValue, forKey: fullNameKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }
}

/// Whether folders come before files: as Finder's Keep folders on top, always (as Windows), or never.
public enum FoldersFirst: String, CaseIterable, Codable, Sendable {
    case asFinder, always, never

    /// With Finder's own setting for that place (windows or the desktop).
    public func sorts(finder: Bool) -> Bool {
        switch self {
        case .asFinder: return finder
        case .always: return true
        case .never: return false
        }
    }
}

/// File extensions in names: as macOS shows them, always, or never (as Windows).
public enum FileExtensions: String, CaseIterable, Sendable {
    case asMacOS, always, never
}
