import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct IconLibraryTests {
    @Test func defaultLibraryComesFromTheSystem() {
        let icons = IconLibrary.defaultIcons
        #expect(!icons.isEmpty)
        #expect(icons.allSatisfy { $0.path.hasPrefix(IconLibrary.systemIcons.path) })
    }

    @Test func listsOnlyImagesByName() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        try sandbox.make("b10.png")
        try sandbox.make("b2.ICNS")
        try sandbox.make("notes.txt")

        #expect(IconLibrary.icons(in: sandbox.root).map(\.lastPathComponent) == ["b2.ICNS", "b10.png"])
        #expect(IconLibrary.icons(in: sandbox.root.appendingPathComponent("missing")).isEmpty)
    }

    @Test func addCopiesImagesIntoANewFolderAndKeepsBothOnCollision() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let star = try sandbox.make("in/star.png")
        let text = try sandbox.make("in/readme.txt")
        let library = sandbox.root.appendingPathComponent("Library/Icons")

        try IconLibrary.add([star, text], to: library)
        let second = try IconLibrary.add([star], to: library)

        #expect(second.map(\.lastPathComponent) == ["star (2).png"])
        #expect(IconLibrary.icons(in: library).map(\.lastPathComponent) == ["star (2).png", "star.png"])
        #expect(FileManager.default.fileExists(atPath: star.path))
    }
}
