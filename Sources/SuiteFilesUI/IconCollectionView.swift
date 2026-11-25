import AppKit

/// NSCollectionView has no double-click or right-click callbacks, so we detect them here.
public final class IconCollectionView: NSCollectionView {
    public var onDoubleClick: ((IndexPath) -> Void)?
    /// Called with the item under the pointer, or nil for the background.
    public var menuProvider: ((IndexPath?) -> NSMenu?)?
    /// Gets keys first; returns true when it handled one (the space bar would otherwise go to type-select).
    public var keyHandler: ((NSEvent) -> Bool)?

    public override func keyDown(with event: NSEvent) {
        if keyHandler?(event) != true { super.keyDown(with: event) }
    }

    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        guard event.clickCount == 2 else { return }
        if let indexPath = indexPathForItem(at: convert(event.locationInWindow, from: nil)) {
            onDoubleClick?(indexPath)
        }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let indexPath = indexPathForItem(at: convert(event.locationInWindow, from: nil))
        // Like Explorer: right-clicking outside the selection selects just that item.
        if let indexPath, !selectionIndexPaths.contains(indexPath) {
            deselectAll(nil)
            selectItems(at: [indexPath], scrollPosition: [])
        } else if indexPath == nil {
            deselectAll(nil)
        }
        return menuProvider?(indexPath)
    }
}
