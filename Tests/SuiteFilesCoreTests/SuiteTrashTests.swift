import Foundation
@testable import SuiteFilesCore
import Testing

@Suite struct SuiteTrashTests {
    /// A scratch folder of the test's own, standing in for the Trash: the real one is never touched.
    private func sandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SuiteTrash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".Trash"), withIntermediateDirectories: true)
        return root
    }

    @Test func explorerGetsWhatIsInTheTrashOnly() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let trash = root.appendingPathComponent(".Trash")
        let inTrash = trash.appendingPathComponent("photo.jpg")
        try Data().write(to: inTrash)
        let outside = root.appendingPathComponent("elsewhere.jpg")
        try Data().write(to: outside)
        let note = Notification(name: SuiteTrash.didTrashNotification, object: nil, userInfo: [
            "originals": ["/Users/me/Pictures/photo.jpg", "/Users/me/x.jpg", "/Users/me/gone.jpg"],
            "trashed": [inTrash.path, outside.path, trash.appendingPathComponent("gone.jpg").path],
        ])
        let items = SuiteTrash.items(of: note, trashes: [trash])
        #expect(items.map(\.original.path) == ["/Users/me/Pictures/photo.jpg"])
        #expect(items.map(\.trashed.path) == [inTrash.path])
    }

    @Test func mismatchedListsGiveNothing() {
        let note = Notification(name: SuiteTrash.didTrashNotification, object: nil,
                                userInfo: ["originals": ["/a", "/b"], "trashed": ["/c"]])
        #expect(SuiteTrash.items(of: note, trashes: [URL(fileURLWithPath: "/")]).isEmpty)
    }

    @Test func theLedgerRecordsWhereItemsCameFrom() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("ledger.json")
        SuiteTrash.writeLedger(["/t/a": "/docs/a"], to: file)
        #expect(SuiteTrash.readLedger(file) == ["/t/a": "/docs/a"])
        #expect(SuiteTrash.readLedger(root.appendingPathComponent("none.json")).isEmpty)
    }
}
