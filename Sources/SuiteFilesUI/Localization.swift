import Foundation

/// The suite's file views' strings, from this library's own catalog.
func FL(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}
