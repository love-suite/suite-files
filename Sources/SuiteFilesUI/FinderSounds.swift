import AppKit

/// The sounds Finder and the Dock make, from the copies macOS keeps for them, played only when "Play user
/// interface sound effects" is on (System Settings › Sound).
public enum FinderSounds {
    public enum Sound: String {
        case moveToTrash = "finder/move to trash.aif"
        case emptyTrash = "finder/empty trash.aif"
        case dragToTrash = "dock/drag to trash.aif"
        case poof = "dock/poof item off dock.aif"
    }

    private static let folder = URL(fileURLWithPath:
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds", isDirectory: true)
    private static var loaded: [Sound: NSSound] = [:]

    /// The system-wide setting; on unless turned off.
    static var areOn: Bool {
        UserDefaults.standard.object(forKey: "com.apple.sound.uiaudio.enabled") as? Bool ?? true
    }

    public static func play(_ sound: Sound) {
        guard areOn else { return }
        let player = loaded[sound] ?? NSSound(contentsOf: folder.appendingPathComponent(sound.rawValue), byReference: true)
        loaded[sound] = player
        player?.stop()
        player?.play()
    }
}
