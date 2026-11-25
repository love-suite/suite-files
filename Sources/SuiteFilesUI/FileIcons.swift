import AppKit
import UniformTypeIdentifiers
import SuiteFilesCore

/// Icons for files and folders. Aliases and symbolic links show their target's icon with the alias arrow,
/// as Finder draws them: macOS gives some aliases (to folders in iCloud Drive, for instance) a blank
/// document icon instead.
public enum FileIcons {
    private static let aliasBadge = NSImage(contentsOfFile:
        "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AliasBadgeIcon.icns")
    private static let cache = NSCache<NSString, NSImage>()

    public static func icon(for item: FileItem) -> NSImage {
        guard item.isAlias else { return NSWorkspace.shared.icon(forFile: item.url.path) }
        let key = item.url.path + "|" + String(item.modified?.timeIntervalSince1970 ?? 0) + "|" + String(DisplaySettings.aliasArrowInDisc)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        let icon = aliasIcon(item.url)
        cache.setObject(icon, forKey: key as NSString)
        return icon
    }

    private static func aliasIcon(_ url: URL) -> NSImage {
        guard let target = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]),
              FileManager.default.fileExists(atPath: target.path) else {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let base = baseIcon(of: target)
        guard let badge = aliasBadge else { return base }
        return NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            if DisplaySettings.aliasArrowInDisc {
                drawAliasBadge(badge, in: rect)
            } else {
                // The arrow alone: the badge is drawn for the whole icon square, its arrow in the corner.
                badge.draw(in: rect)
            }
            return true
        }
    }

    /// What an alias shows of its target, as Finder draws it: the target's icon, except that a folder
    /// customised with a symbol or emoji in Finder (the `com.apple.icon.folder#S` attribute, macOS 26) shows
    /// as a plain folder on its aliases.
    private static func baseIcon(of target: URL) -> NSImage {
        if getxattr(target.path, "com.apple.icon.folder#S", nil, 0, 0, 0) > 0 {
            return NSWorkspace.shared.icon(for: .folder)
        }
        return NSWorkspace.shared.icon(forFile: target.path)
    }

    /// The alias arrow as macOS 27 draws it: in a white disc on the lower-left corner. The system's badge
    /// image is the arrow alone, drawn for the whole icon square with the arrow in its corner, so it is
    /// scaled to put the arrow in the middle of the disc.
    private static func drawAliasBadge(_ badge: NSImage, in rect: NSRect) {
        let side = rect.width
        let disc = NSRect(x: rect.minX + side * 0.03, y: rect.minY + side * 0.03,
                          width: side * 0.22, height: side * 0.22)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -side * 0.005)
        shadow.shadowBlurRadius = side * 0.015
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: disc).fill()
        NSGraphicsContext.restoreGraphicsState()
        // The arrow fills about the lower-left 14 % of the badge square: that part goes to the disc's middle.
        let scale = disc.width * 0.68 / (side * 0.137)
        let drawn = side * scale
        badge.draw(in: NSRect(x: disc.midX - drawn * 0.075, y: disc.midY - drawn * 0.078, width: drawn, height: drawn))
    }
}
