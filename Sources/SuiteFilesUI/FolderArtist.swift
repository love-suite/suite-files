import AppKit
import SuiteFilesCore

/// Coloured folders with an emoji, the way macOS customises folders (without tags).
public enum FolderArtist {
    /// Apple's folder colours.
    public static let colors: [(name: String, color: NSColor)] = [
        ("Blue", .systemBlue), ("Red", .systemRed), ("Orange", .systemOrange), ("Yellow", .systemYellow),
        ("Green", .systemGreen), ("Mint", .systemMint), ("Teal", .systemTeal), ("Cyan", .systemCyan),
        ("Indigo", .systemIndigo), ("Purple", .systemPurple), ("Pink", .systemPink), ("Brown", .systemBrown),
        ("Gray", .systemGray),
    ]

    private static var baseFolder: NSImage {
        let generic = IconLibrary.systemIcons.appendingPathComponent("GenericFolderIcon.icns")
        return NSImage(contentsOf: generic) ?? NSWorkspace.shared.icon(for: .folder)
    }

    /// The folder icon tinted with `color` (keeping its shading), with `emoji` on its front.
    public static func folder(color: NSColor?, emoji: String?, side: CGFloat = 512) -> NSImage {
        let base = baseFolder
        let emoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            base.draw(in: rect)
            if let color {
                // Hue and saturation from the colour, light and shade from the folder…
                color.set()
                rect.fill(using: .color)
                // …and only where the folder is.
                base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            }
            if let emoji, !emoji.isEmpty {
                let font = NSFont.systemFont(ofSize: side * 0.34)
                let text = NSAttributedString(string: emoji, attributes: [.font: font])
                let size = text.size()
                // The front panel of the macOS folder sits a little below the middle.
                text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.height * 0.40 - size.height / 2))
            }
            return true
        }
    }
}
