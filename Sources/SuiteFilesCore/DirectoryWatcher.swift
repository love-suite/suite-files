import Foundation
import CoreServices

/// Watches a directory for changes using FSEvents and calls `onChange` on each event.
public final class DirectoryWatcher {
    private let urls: [URL]
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "SuiteCore.DirectoryWatcher", qos: .utility)

    public init(url: URL, onChange: @escaping () -> Void) {
        // The Trash is watched in all its folders.
        urls = url.standardizedFileURL == TrashLocations.url.standardizedFileURL ? TrashLocations.all : [url]
        self.onChange = onChange
    }

    public func start() {
        guard stream == nil else { return }

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            Unmanaged<DirectoryWatcher>.fromOpaque(info!).takeUnretainedValue().onChange()
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let s = FSEventStreamCreate(
            nil,
            callback,
            &context,
            urls.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        guard let s else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
    }

    public func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}
