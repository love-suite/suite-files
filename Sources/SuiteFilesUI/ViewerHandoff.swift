import AppKit
import SuiteFilesCore
import SuiteCore

/// Pictures and PDFs from Explorer go to Viewer, an app of its own; without it, to the app the system
/// opens them with.
public enum ViewerHandoff {
    /// Pictures open in the viewer unless turned off in Settings.
    public static func shows(_ url: URL) -> Bool {
        DisplaySettings.opensPicturesInViewer && ViewerApp.showsPicture(url)
    }

    /// PDFs open in the viewer.
    public static func showsPDF(_ url: URL) -> Bool { ViewerApp.showsPDF(url) }

    /// Hands the picture to Viewer, or to the system's app for it if Viewer is missing.
    public static func open(_ url: URL) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ViewerApp.bundleID) else {
            NSWorkspace.shared.open(url)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
    }

    /// Hands the PDF to Viewer, or to the system's app for it if Viewer is missing.
    public static func openPDF(_ url: URL) { open(url) }
}
