import AppKit

/// Runs the closure a menu item carries.
public final class MenuAction: NSObject {
    public static let shared = MenuAction()
    @objc public func run(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
}
