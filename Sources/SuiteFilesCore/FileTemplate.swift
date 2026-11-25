import Foundation

public enum FileTemplate {
    case folder
    case text
    case markdown

    var defaultName: String {
        switch self {
        case .folder:   return "New Folder"
        case .text:     return "New Text File.txt"
        case .markdown: return "New Markdown File.md"
        }
    }

    /// Creates a new empty folder or file from this template in `directory` and returns its URL.
    /// Uses "Name (2).ext", "(3)", … if the default name is already taken.
    @discardableResult
    public func create(in directory: URL, fileManager: FileManager = .default) throws -> URL {
        let destination = CutClipboard.uniqueDestination(
            named: defaultName, in: directory, fileManager: fileManager
        )
        if case .folder = self {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        } else {
            try Data().write(to: destination)
        }
        return destination
    }
}
