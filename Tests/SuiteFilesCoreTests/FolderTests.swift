import Foundation
import Testing
@testable import SuiteFilesCore

/// A throwaway directory tree, removed by `remove()`.
struct Sandbox {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func make(_ path: String, directory: Bool = false) throws -> URL {
        let url = root.appendingPathComponent(path)
        if directory {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: url)
        }
        return url
    }
}

@Suite struct ExplorerCoreTests {
    @Test func loaderPutsDirectoriesFirstAndSortsNaturally() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.make("b.txt")
        try sandbox.make("a10.txt")
        try sandbox.make("a2.txt")
        try sandbox.make("Zfolder", directory: true)

        let names = try DirectoryLoader.load(sandbox.root).map(\.name)

        #expect(names == ["Zfolder", "a2.txt", "a10.txt", "b.txt"])
    }

    @Test func cutThenPasteMovesFile() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("src/note.txt")
        let target = try sandbox.make("dst", directory: true)
        let clipboard = CutClipboard()

        clipboard.cut([file])
        let moved = try clipboard.paste(into: target)

        #expect(moved.map(\.lastPathComponent) == ["note.txt"])
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(clipboard.pending.isEmpty)
    }

    @Test func pasteRenamesOnCollision() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("src/note.txt")
        let target = try sandbox.make("dst", directory: true)
        try sandbox.make("dst/note.txt")
        let clipboard = CutClipboard()

        clipboard.cut([file])
        let moved = try clipboard.paste(into: target)

        #expect(moved.map(\.lastPathComponent) == ["note (2).txt"])
    }
}
