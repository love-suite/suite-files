import AppKit
import SuiteFilesCore

/// The cloud state of iCloud Drive and File Provider items. On big icons, a small round badge on the
/// lower-left corner of the icon's drawing, as Windows does in OneDrive folders; in lists, the same badge
/// after the name, as Finder does. Grey cloud: only online; green check: on this Mac; blue arrows:
/// syncing; red: a problem. Can be turned off (Settings › Explorer).
public enum SyncBadge {
    /// The badge's width on screen, whatever the icon's size, so files, folders, the desktop and windows
    /// all show the same badge.
    static let side: CGFloat = 16

    /// `icon` shown `displaySide` points wide, with the badge on the lower-left corner of what it draws
    /// (a document's page is narrower than a folder: the badge follows the drawing, not the image); on the
    /// lower-right one for an alias, whose arrow has the lower-left corner.
    static func decorate(_ icon: NSImage?, with state: SyncState?, displaySide: CGFloat,
                         isAlias: Bool = false) -> NSImage? {
        guard let icon, let state, DisplaySettings.showsSyncBadges, DisplaySettings.syncBadgeStyle == .onIcon,
              displaySide >= 32, icon.size.width > 0 else { return icon }
        let drawing = visibleBounds(of: icon)
        return NSImage(size: icon.size, flipped: false) { rect in
            icon.draw(in: rect)
            // In the image's own units: it is drawn scaled to displaySide points.
            let points = rect.width / displaySide
            let badge = side * points
            // Overlapping the drawing's corner a little, kept inside the image.
            let left = isAlias ? drawing.maxX - badge * 0.8 : drawing.minX - badge * 0.2
            let x = min(max(left, rect.minX), rect.maxX - badge)
            let y = min(max(drawing.minY - badge * 0.2, rect.minY), rect.maxY - badge)
            draw(state, in: NSRect(x: x, y: y, width: badge, height: badge), ring: 1.5 * points)
            return true
        }
    }

    /// The badge alone, `side` points wide, after the name in lists: the disc, or Finder's grey sign.
    public static func symbol(for state: SyncState, side: CGFloat) -> NSImage? {
        guard DisplaySettings.showsSyncBadges else { return nil }
        if DisplaySettings.syncBadgeStyle == .afterName { return nameSign(for: state) }
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(state, in: rect.insetBy(dx: 1, dy: 1), ring: 1)
            return true
        }
    }

    /// Finder's signs, as a template image (tinted like the text): a cloud with an arrow for items only
    /// online, arrows while syncing, a warning for a problem, nothing for items already here.
    static func nameSign(for state: SyncState) -> NSImage? {
        guard DisplaySettings.showsSyncBadges else { return nil }
        let name: String
        switch state {
        case .cloudOnly: name = "icloud.and.arrow.down"
        case .syncing: name = "arrow.triangle.2.circlepath.icloud"
        case .problem: name = "exclamationmark.icloud"
        case .downloaded: return nil
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description(state))?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        image?.isTemplate = true
        return image
    }

    /// A white ring, then Apple's own round sign (its disc and its optically centred check, cloud, arrows
    /// or exclamation mark), its disc laid exactly inside the ring by what the symbol draws.
    private static func draw(_ state: SyncState, in rect: NSRect, ring: CGFloat) {
        let (symbol, color) = style(state)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: rect).fill()
        let disc = rect.insetBy(dx: ring, dy: ring)
        let configuration = NSImage.SymbolConfiguration(pointSize: max(disc.height, 8), weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white, color]))
        guard let sign = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            color.setFill()
            NSBezierPath(ovalIn: disc).fill()
            return
        }
        let drawn = visibleBounds(of: sign)
        guard drawn.width > 0, drawn.height > 0 else { return }
        let scale = disc.width / drawn.width
        sign.draw(in: NSRect(x: disc.minX - drawn.minX * scale, y: disc.minY - drawn.minY * scale,
                             width: sign.size.width * scale, height: sign.size.height * scale))
    }

    /// Where the image actually draws (its non-transparent pixels), in its own coordinates.
    static func visibleBounds(of image: NSImage) -> NSRect {
        let full = NSRect(origin: .zero, size: image.size)
        let pixels = 96
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return full }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.bitmapData else { return full }
        var minX = pixels, minY = pixels, maxX = -1, maxY = -1
        for row in 0..<pixels {
            for column in 0..<pixels where data[row * bitmap.bytesPerRow + column * 4 + 3] > 24 {
                minX = min(minX, column)
                maxX = max(maxX, column)
                minY = min(minY, row)
                maxY = max(maxY, row)
            }
        }
        guard maxX >= minX, maxY >= minY else { return full }
        // Bitmap rows run top down; the image's y runs bottom up.
        let unit = image.size.width / CGFloat(pixels)
        let unitY = image.size.height / CGFloat(pixels)
        return NSRect(x: CGFloat(minX) * unit, y: CGFloat(pixels - 1 - maxY) * unitY,
                      width: CGFloat(maxX - minX + 1) * unit, height: CGFloat(maxY - minY + 1) * unitY)
    }

    public static func description(_ state: SyncState) -> String {
        switch state {
        case .cloudOnly: return "Available when online"
        case .downloaded: return "Available on this Mac"
        case .syncing: return "Syncing"
        case .problem: return "Sync problem"
        }
    }

    private static func style(_ state: SyncState) -> (String, NSColor) {
        switch state {
        case .cloudOnly: return ("icloud.circle.fill", .systemGray)
        case .downloaded: return ("checkmark.circle.fill", .systemGreen)
        case .syncing: return ("arrow.triangle.2.circlepath.circle.fill", .systemBlue)
        case .problem: return ("exclamationmark.circle.fill", .systemRed)
        }
    }
}
