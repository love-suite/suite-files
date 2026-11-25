import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct PropertiesTests {
    @Test func fileProperties() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = sandbox.root.appendingPathComponent("notes.txt")
        try Data(repeating: 65, count: 1234).write(to: file)

        let properties = try ItemProperties.load(file)

        #expect(properties.name == "notes.txt")
        #expect(!properties.isFolder)
        #expect(properties.size == 1234)
        #expect((properties.sizeOnDisk ?? 0) >= 1234)
        #expect(properties.location.standardizedFileURL.path == sandbox.root.standardizedFileURL.path)
        #expect(properties.modified != nil)
        #expect(!properties.isReadOnly)
    }

    @Test func readOnlyAndFolder() throws {
        let sandbox = try Sandbox()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath:
                sandbox.root.appendingPathComponent("locked.txt").path)
            sandbox.remove()
        }
        let locked = try sandbox.make("locked.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: locked.path)
        let folder = try sandbox.make("Folder", directory: true)

        #expect(try ItemProperties.load(locked).isReadOnly)
        let folderProperties = try ItemProperties.load(folder)
        #expect(folderProperties.isFolder)
        #expect(folderProperties.size == nil)
    }

    @Test func folderMeasureCountsEverythingBelow() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let top = try sandbox.make("Top", directory: true)
        try Data(count: 100).write(to: top.appendingPathComponent("a.bin"))
        try Data(count: 50).write(to: top.appendingPathComponent(".hidden"))
        try sandbox.make("Top/Sub", directory: true)
        try Data(count: 25).write(to: top.appendingPathComponent("Sub/b.bin"))

        let contents = FolderMeasure.measure(top)

        #expect(contents.files == 3)
        #expect(contents.folders == 1)
        #expect(contents.size == 175)
    }
}
