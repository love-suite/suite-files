import AppKit
import SuiteFilesCore

/// Shows the whole name of selected icons whose name is truncated, laid over the icons below,
/// as on Windows. Lives on top of the icons instead of inside them, so nothing clips it.
public final class FullNameOverlay {
    private var labels: [NSView] = []

    public init() {}

    /// `cells` are the selected icons' names and frames, in `container`'s (flipped) coordinates.
    public func update(in container: NSView, cells: [(name: String, frame: NSRect)], iconSide: CGFloat) {
        labels.forEach { $0.removeFromSuperview() }
        labels = []
        guard DisplaySettings.showsFullNameOfSelection else { return }
        for (name, cell) in cells {
            let oneLine = (name as NSString).size(withAttributes: [.font: IconItemView.font]).width
            // The cell already shows a name that fits; it is highlighted there.
            guard oneLine + 6 > cell.width - 4 else { continue }
            // Full cell width, so it completely covers the truncated name highlighted in the cell.
            let label = FullNameLabel(name: name, width: cell.width)
            label.setFrameOrigin(NSPoint(x: cell.minX, y: cell.minY + IconItemView.nameTop(iconSide: iconSide)))
            container.addSubview(label)
            labels.append(label)
        }
    }

    public func update(in collectionView: NSCollectionView, name: (IndexPath) -> String?) {
        let cells = collectionView.selectionIndexPaths.compactMap { indexPath -> (String, NSRect)? in
            guard let name = name(indexPath),
                  let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else { return nil }
            return (name, frame)
        }
        update(in: collectionView, cells: cells, iconSide: IconSize.medium.iconSide)
    }
}

/// Lets clicks through so the item underneath can still be clicked or double-clicked.
private final class FullNameLabel: NSTextField {
    convenience init(name: String, width: CGFloat) {
        self.init(wrappingLabelWithString: name)
        alignment = .center
        font = IconItemView.font
        textColor = .white
        wantsLayer = true
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        layer?.cornerRadius = 3
        layer?.zPosition = 10
        let size = cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
        frame.size = NSSize(width: width, height: ceil(size?.height ?? 14))
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
