import Foundation

extension DisplaySettings {
    /// An item's name as shown everywhere: with or without its extension as chosen, or as macOS shows it
    /// until then (every extension when macOS shows them all, otherwise all but those hidden file by file).
    public static func name(of item: FileItem) -> String {
        if showsFileExtensionsAsMacOS && !macOSShowsAllExtensions {
            return item.displayName(showingExtension: !item.hasHiddenExtension)
        }
        return item.displayName(showingExtension: showsFileExtensions)
    }
}
