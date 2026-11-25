import Foundation

/// Zip archives, as Windows' "Compress to ZIP file" and "Extract All" and Finder's Compress do.
public enum Archiver {
    public static func isArchive(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "zip"
    }

    /// One item becomes "name.zip", several "Archive.zip", next to them; a taken name gets a number.
    @discardableResult
    public static func compress(_ items: [URL], fileManager: FileManager = .default) throws -> URL {
        guard let first = items.first else { throw CocoaError(.fileNoSuchFile) }
        let folder = first.deletingLastPathComponent()
        let name = items.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archive"
        let archive = CutClipboard.uniqueDestination(named: name + ".zip", in: folder, fileManager: fileManager)
        if items.count == 1 {
            try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, archive.path])
        } else {
            try run("/usr/bin/zip", ["-q", "-r", "-y", archive.path] + items.map(\.lastPathComponent)
                        + ["-x", "*.DS_Store"], in: folder)
        }
        return archive
    }

    /// Unpacks into a folder named after the archive, next to it; a taken name gets a number.
    @discardableResult
    public static func extract(_ archive: URL, fileManager: FileManager = .default) throws -> URL {
        let folder = archive.deletingLastPathComponent()
        let destination = CutClipboard.uniqueDestination(named: archive.deletingPathExtension().lastPathComponent,
                                                         in: folder, fileManager: fileManager)
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, destination.path])
        return destination
    }

    private static func run(_ tool: String, _ arguments: [String], in directory: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey:
                "The archive couldn't be made or opened. \(message)".trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }
}
