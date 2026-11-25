import AppKit

/// As in Windows, items being dragged stay in place, faded, while a see-through image of them follows
/// the pointer.
public enum DragGhost {
    /// The items left in place.
    public static let alpha: CGFloat = 0.5
    /// Their image under the pointer.
    public static let imageAlpha: CGFloat = 0.7
    static let iconSide: CGFloat = 64

    public static func faded(_ image: NSImage, alpha: CGFloat = imageAlpha) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
            return true
        }
    }

    /// Takes the images AppKit draws from the source views now, see-through: drawn later, they would
    /// pick up the fading of the items left in place.
    public static func fadeImages(of session: NSDraggingSession) {
        session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self],
                                       searchOptions: [:]) { item, _, _ in
            let components = (item.imageComponents ?? []).map(faded)
            item.imageComponentsProvider = { components }
        }
    }

    /// Shows each item as its icon under the pointer, where a list would drag lines of text.
    public static func showIcons(in session: NSDraggingSession, at screenPoint: NSPoint, icon: (URL) -> NSImage?) {
        session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self],
                                       searchOptions: [:]) { item, index, _ in
            guard let url = fileURL(of: item), let image = icon(url)?.copy() as? NSImage else { return }
            image.size = NSSize(width: iconSide, height: iconSide)
            let shift = CGFloat(min(index, 4)) * 6
            item.setDraggingFrame(NSRect(x: screenPoint.x - iconSide / 2 + shift,
                                         y: screenPoint.y - iconSide / 2 - shift,
                                         width: iconSide, height: iconSide),
                                  contents: faded(image))
        }
    }

    private static func fileURL(of item: NSDraggingItem) -> URL? {
        if let url = item.item as? URL { return url }
        return (item.item as? NSPasteboardItem)?.string(forType: .fileURL).flatMap(URL.init(string:))
    }

    private static func faded(_ component: NSDraggingImageComponent) -> NSDraggingImageComponent {
        let copy = NSDraggingImageComponent(key: component.key)
        copy.frame = component.frame
        if let image = component.contents as? NSImage {
            copy.contents = faded(image)
        } else if let contents = component.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
            copy.contents = faded(NSImage(cgImage: contents as! CGImage, size: component.frame.size))
        } else {
            copy.contents = component.contents
        }
        return copy
    }
}
