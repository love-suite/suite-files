import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct FileTransferTests {
    @Test func moveTakesTheFileAway() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("a/note.txt")
        let target = try sandbox.make("b", directory: true)

        let moved = try FileTransfer.transfer([file], into: target, operation: .move)

        #expect(moved.map(\.lastPathComponent) == ["note.txt"])
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func copyKeepsTheOriginalAndRenamesOnCollision() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("a/note.txt")
        let target = try sandbox.make("b", directory: true)
        try sandbox.make("b/note.txt")

        let copied = try FileTransfer.transfer([file], into: target, operation: .copy)

        #expect(copied.map(\.lastPathComponent) == ["note (2).txt"])
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func movingWithinTheSameFolderOrIntoItselfDoesNothing() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("a/note.txt")
        let folder = try sandbox.make("a/Sub", directory: true)
        let parent = file.deletingLastPathComponent()

        #expect(try FileTransfer.transfer([file], into: parent, operation: .move).isEmpty)
        #expect(try FileTransfer.transfer([folder], into: folder, operation: .move).isEmpty)
        #expect(try FileTransfer.transfer([parent], into: folder, operation: .move).isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func sameVolumeMovesUnlessOptionIsHeld() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("note.txt")
        let target = try sandbox.make("b", directory: true)

        #expect(FileTransfer.defaultOperation(for: [file], into: target, forceCopy: false) == .move)
        #expect(FileTransfer.defaultOperation(for: [file], into: target, forceCopy: true) == .copy)
    }
}
