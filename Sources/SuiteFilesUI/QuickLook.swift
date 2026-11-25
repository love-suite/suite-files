import AppKit
import Quartz

/// The space-bar preview, as in Finder. Whoever owns the selection keeps `urls` current and takes
/// control of the panel through the responder chain (acceptsPreviewPanelControl and friends).
public final class QuickLook: NSObject, QLPreviewPanelDataSource {
    public var urls: [URL] = [] {
        didSet { if QuickLook.isVisible { QLPreviewPanel.shared()?.reloadData() } }
    }

    public static var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true
    }

    public static func toggle() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    public func take(_ panel: QLPreviewPanel) {
        panel.dataSource = self
        panel.reloadData()
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }

    /// Space previews; Cmd+I (Mac) or Alt+Enter (Windows) shows properties.
    public enum Key { case preview, properties }

    public static func key(for event: NSEvent) -> Key? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.charactersIgnoringModifiers == " " && flags.isEmpty { return .preview }
        if event.charactersIgnoringModifiers?.lowercased() == "i" && flags == .command { return .properties }
        if event.keyCode == 36 && flags == .option { return .properties }
        return nil
    }
}
