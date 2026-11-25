import Foundation

/// The user-wide NSFileViewer setting: which app handles "Show in Finder" requests from other apps.
/// Turning it off removes the key, which gives the role back to Finder.
public enum DefaultFileViewer {
    private static let key = "NSFileViewer" as CFString

    /// Only a bundled app (Explorer.app) has an identifier to register.
    public static var canBeSet: Bool { Bundle.main.bundleIdentifier != nil }

    public static var isThisApp: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let value = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return value as? String == id
    }

    /// Turning it off only removes the setting if it names this app, so another viewer is left alone.
    public static func setThisApp(_ enabled: Bool) {
        guard enabled || isThisApp else { return }
        let value = enabled ? Bundle.main.bundleIdentifier as CFString? : nil
        CFPreferencesSetValue(key, value, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
