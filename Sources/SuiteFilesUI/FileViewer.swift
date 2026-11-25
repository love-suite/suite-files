import AppKit

/// Where folders open and items are shown: the app holding the file windows role. An app that shows file
/// windows itself (Explorer) sets both at launch; elsewhere they go to the system's file viewer (Finder,
/// or whichever app the user made the default folder viewer).
public enum FileViewer {
    /// Opens a folder in a window.
    nonisolated(unsafe) public static var openFolder: (URL) -> Void = { NSWorkspace.shared.open($0) }
    /// Shows items selected in their folder's window.
    nonisolated(unsafe) public static var reveal: ([URL]) -> Void = {
        NSWorkspace.shared.activateFileViewerSelecting($0)
    }
}
