import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct ShortcutTests {
    @Test func symbolicLinkToFolderResolves() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.make("Target", directory: true)
        let link = sandbox.root.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        #expect(ShortcutResolver.folderTarget(of: link)?.standardizedFileURL.path
                == folder.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    @Test func finderAliasToFolderResolves() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let folder = try sandbox.make("Target", directory: true)
        let alias = sandbox.root.appendingPathComponent("Target alias")
        let bookmark = try folder.bookmarkData(options: .suitableForBookmarkFile)
        try URL.writeBookmarkData(bookmark, to: alias)

        let target = try #require(ShortcutResolver.folderTarget(of: alias))
        #expect(target.resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)
    }

    @Test func shortcutToFileAndPlainItemsAreNotFolders() throws {
        let sandbox = try Sandbox()
        defer { sandbox.remove() }
        let file = try sandbox.make("note.txt")
        let folder = try sandbox.make("Plain", directory: true)
        let link = sandbox.root.appendingPathComponent("note link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        #expect(ShortcutResolver.folderTarget(of: link) == nil)
        #expect(ShortcutResolver.folderTarget(of: file) == nil)
        #expect(ShortcutResolver.folderTarget(of: folder) == nil)
    }
}
