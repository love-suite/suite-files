import AppKit
import SuiteFilesCore

/// A stack's icon as macOS draws it: its first items piled up, the ones behind slightly smaller,
/// raised and tilted. An expanded stack carries a chevron to fold it back.
public enum StackIcon {
    public static func image(for urls: [URL], side: CGFloat, expanded: Bool) -> NSImage {
        let icons = urls.prefix(3).map { FileIcons.icon(for: DirectoryLoader.item(at: $0)) }
        let chevron = expanded ? chevronImage(side: side * 0.42) : nil
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            // Back to front, so the first item ends up on top.
            for (depth, icon) in icons.enumerated().reversed() {
                let d = CGFloat(depth)
                let size = rect.width * 0.84 * (1 - d * 0.08)
                let frame = NSRect(x: (rect.width - size) / 2, y: d * rect.height * 0.07, width: size, height: size)
                let angle: CGFloat = depth == 0 ? 0 : (depth == 1 ? -7 : 6)
                NSGraphicsContext.saveGraphicsState()
                let turn = NSAffineTransform()
                turn.translateX(by: frame.midX, yBy: frame.midY)
                turn.rotate(byDegrees: angle)
                turn.translateX(by: -frame.midX, yBy: -frame.midY)
                turn.concat()
                icon.draw(in: frame)
                NSGraphicsContext.restoreGraphicsState()
            }
            if let chevron {
                chevron.draw(in: NSRect(x: rect.maxX - chevron.size.width, y: 0,
                                        width: chevron.size.width, height: chevron.size.height))
            }
            return true
        }
    }

    private static func chevronImage(side: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: side * 0.8, weight: .semibold)
            .applying(.init(paletteColors: [.white, .systemGray]))
        return NSImage(systemSymbolName: "chevron.up.circle.fill", accessibilityDescription: "Fold stack")?
            .withSymbolConfiguration(configuration)
    }
}
