import AppKit
import SuiteFilesCore

/// How a drop of files behaves, the same on the desktop and in Explorer windows: move on the same
/// volume, copy onto another, Option forces a copy; dropping files back where they are does nothing.
public enum FileDrop {
    /// What folders and the desktop accept: files, and files made at the drop (file promises, from
    /// Safari, Mail, Photos or Clipboard).
    public static let draggedTypes: [NSPasteboard.PasteboardType] = [.fileURL]
        + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType(rawValue: $0) }

    public static func fileURLs(in info: NSDraggingInfo) -> [URL] {
        info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    public static func transferOperation(for info: NSDraggingInfo, into folder: URL) -> TransferOperation {
        let mask = info.draggingSourceOperationMask
        let forceCopy = !mask.contains(.move) && !mask.contains(.generic)
        return FileTransfer.defaultOperation(for: fileURLs(in: info), into: folder, forceCopy: forceCopy)
    }

    /// The operation to show while hovering; none if the drop would change nothing.
    public static func dragOperation(for info: NSDraggingInfo, into folder: URL) -> NSDragOperation {
        let urls = fileURLs(in: info)
        guard !urls.isEmpty else { return promises(in: info).isEmpty ? [] : .copy }
        let operation = transferOperation(for: info, into: folder)
        let folderPath = folder.standardizedFileURL.path
        if operation == .move,
           urls.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL.path == folderPath }) {
            return []
        }
        let mask = info.draggingSourceOperationMask
        switch operation {
        case .move: return mask.contains(.move) ? .move : .generic
        case .copy: return .copy
        }
    }

    /// Moves or copies the dropped files into `folder`; returns their new locations. Files made at
    /// the drop arrive later, through `received`, on the main thread.
    @discardableResult
    public static func perform(_ info: NSDraggingInfo, into folder: URL,
                               received: (([URL]) -> Void)? = nil) -> [URL] {
        let urls = fileURLs(in: info)
        if urls.isEmpty {
            receivePromises(in: info, into: folder, received: received)
            return []
        }
        return transfer(urls, into: folder, operation: transferOperation(for: info, into: folder))
    }

    public static func promises(in info: NSDraggingInfo) -> [NSFilePromiseReceiver] {
        info.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
    }

    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private static func receivePromises(in info: NSDraggingInfo, into folder: URL, received: (([URL]) -> Void)?) {
        for promise in promises(in: info) {
            promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: promiseQueue) { url, error in
                guard error == nil else { return }
                DispatchQueue.main.async { received?([url]) }
            }
        }
    }

    @discardableResult
    public static func transfer(_ urls: [URL], into folder: URL, operation: TransferOperation) -> [URL] {
        TransferRunner.run(urls, into: folder, operation: operation)
    }

    /// The folder an item stands for as a drop target: itself, or what an alias points to.
    public static func folderTarget(of item: FileItem) -> URL? {
        item.isFolder ? item.url : ShortcutResolver.folderTarget(of: item.url)
    }
}
