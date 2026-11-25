import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct TrashLedgerTests {
    private func sandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TrashTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func containsTheTrashAndWhatIsInside() {
        let trash = URL(fileURLWithPath: "/Users/me/.Trash")
        #expect(TrashFolder.contains(trash, trashes: [trash]))
        #expect(TrashFolder.contains(URL(fileURLWithPath: "/Users/me/.Trash/a.txt"), trashes: [trash]))
        #expect(!TrashFolder.contains(URL(fileURLWithPath: "/Users/me/.Trashy"), trashes: [trash]))
        #expect(!TrashFolder.contains(URL(fileURLWithPath: "/Users/me/Documents"), trashes: [trash]))
    }

    @Test func theTrashGathersHomeICloudDriveAndDisks() {
        let home = URL(fileURLWithPath: "/Users/me")
        let disk = URL(fileURLWithPath: "/Volumes/Backup")
        let all = TrashFolder.locations(home: home, volumes: [URL(fileURLWithPath: "/"), disk], uid: 501) { _ in true }
        #expect(all.map(\.path) == ["/Users/me/.Trash", "/Users/me/Library/Mobile Documents/.Trash",
                                    "/Volumes/Backup/.Trashes/501"])
        // The home Trash always; the others only when they exist.
        let some = TrashFolder.locations(home: home, volumes: [disk], uid: 501) { _ in false }
        #expect(some.map(\.path) == ["/Users/me/.Trash"])
        // iCloud Drive's Trash can be left out.
        let noICloud = TrashFolder.locations(home: home, volumes: [disk], uid: 501, iCloudDrive: false) { _ in true }
        #expect(noICloud.map(\.path) == ["/Users/me/.Trash", "/Volumes/Backup/.Trashes/501"])
        // Something deleted from an iCloud Desktop is in the Trash too, so it can be erased or put back.
        let fromDesktop = URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/.Trash/Note.txt")
        #expect(TrashFolder.contains(fromDesktop, trashes: all))
        #expect(TrashFolder.partition([fromDesktop], trashes: all).inTrash == [fromDesktop])
    }

    @Test func listsAndEmptiesEveryTrash() throws {
        let root = try sandbox()
        let first = root.appendingPathComponent("Trash", isDirectory: true)
        let second = root.appendingPathComponent("iCloud/.Trash", isDirectory: true)
        for (folder, name) in [(first, "a.txt"), (second, "b.txt")] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "x".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        #expect(try TrashFolder.contents(of: [first, second]).map(\.lastPathComponent).sorted() == ["a.txt", "b.txt"])
        // A missing second Trash is skipped, not an error.
        #expect(try TrashFolder.contents(of: [first, root.appendingPathComponent("none")]).count == 1)
        #expect(try TrashFolder.empty([first, second]).isEmpty)
        #expect(try TrashFolder.contents(of: [first, second]).isEmpty)
    }

    @Test func onlyWhatIsInTheTrashCanBeErased() {
        let trash = URL(fileURLWithPath: "/Users/me/.Trash")
        let inside = URL(fileURLWithPath: "/Users/me/.Trash/a.txt")
        let desktop = URL(fileURLWithPath: "/Users/me/Desktop/b.txt")
        let (erasable, outside) = TrashFolder.partition([inside, desktop, trash], trashes: [trash])
        #expect(erasable == [inside])
        // The Trash folder itself is never erased either.
        #expect(outside == [desktop, trash])
    }

    @Test func putsBackWhereItCameFrom() throws {
        let root = try sandbox()
        let ledger = TrashLedger(file: root.appendingPathComponent("ledger.json"))
        let original = root.appendingPathComponent("Docs/report.txt")
        let trashed = root.appendingPathComponent("Trash/report.txt")
        try FileManager.default.createDirectory(at: trashed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x".write(to: trashed, atomically: true, encoding: .utf8)
        ledger.record(original: original, trashed: trashed)

        // Survives a restart.
        let reloaded = TrashLedger(file: root.appendingPathComponent("ledger.json"))
        #expect(reloaded.canPutBack(trashed))
        let back = try reloaded.putBack(trashed)
        #expect(back.path == original.path)
        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(!reloaded.canPutBack(trashed))
    }

    @Test func putBackNumbersANameTakenSince() throws {
        let root = try sandbox()
        let ledger = TrashLedger(file: root.appendingPathComponent("ledger.json"))
        let original = root.appendingPathComponent("notes.txt")
        try "new".write(to: original, atomically: true, encoding: .utf8)
        let trashed = root.appendingPathComponent("trashed notes.txt")
        try "old".write(to: trashed, atomically: true, encoding: .utf8)
        ledger.record(original: original, trashed: trashed)
        let back = try ledger.putBack(trashed)
        #expect(back.lastPathComponent == "notes (2).txt")
    }

    @Test func unknownItemsCannotBePutBack() throws {
        let root = try sandbox()
        let ledger = TrashLedger(file: root.appendingPathComponent("ledger.json"))
        #expect(!ledger.canPutBack(root.appendingPathComponent("x")))
        #expect(throws: (any Error).self) { try ledger.putBack(root.appendingPathComponent("x")) }
    }

    @Test func emptyingErasesEverythingInside() throws {
        let trash = try sandbox()
        try "a".write(to: trash.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: trash.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: trash.appendingPathComponent("folder/sub"),
                                                withIntermediateDirectories: true)
        let failed = try TrashFolder.empty([trash])
        #expect(failed.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: trash.path).isEmpty)
        #expect(FileManager.default.fileExists(atPath: trash.path))
    }
}
