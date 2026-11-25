import Foundation
import Testing
@testable import SuiteFilesCore

/// Writes a small `.DS_Store` the way Finder lays one out: a buddy allocator whose "DSDB" tree holds
/// the records, in one leaf or under an internal node.
enum DSStoreWriter {
    typealias Entry = (name: String, code: String, value: String)

    static func record(_ entry: Entry) -> [UInt8] {
        var bytes = u32(entry.name.utf16.count) + utf16(entry.name)
        let xy = entry.value.split(separator: ",").compactMap { Int($0) }
        if entry.code == "Iloc", xy.count == 2 {
            // An icon position, given as "x,y": a 16-byte blob, x and y then eight bytes of 0xff.
            let blob = u32(xy[0]) + u32(xy[1]) + [UInt8](repeating: 0xff, count: 8)
            return bytes + Array("Iloc".utf8) + Array("blob".utf8) + u32(blob.count) + blob
        }
        bytes += Array(entry.code.utf8) + Array("ustr".utf8)
        return bytes + u32(entry.value.utf16.count) + utf16(entry.value)
    }

    static func make(_ entries: [Entry], twoLevels: Bool = false) -> Data {
        // Relative offsets (from after the 4-byte prefix), each a multiple of 32, with log2(size).
        let rootAt = 0x4000, headerAt = 0x800
        var nodes: [(at: Int, bytes: [UInt8])] = []
        var rootNode = 2
        if twoLevels, entries.count >= 3 {
            // Block 2: an internal node [child 3, entry 1] then the rightmost child, block 4.
            let internalNode = u32(4) + u32(1) + u32(3) + record(entries[1])
            let leftLeaf = u32(0) + u32(1) + record(entries[0])
            let rightLeaf = u32(0) + u32(entries.count - 2) + entries[2...].flatMap(record)
            nodes = [(0x1000, internalNode), (0x2000, leftLeaf), (0x3000, rightLeaf)]
        } else {
            nodes = [(0x1000, u32(0) + u32(entries.count) + entries.flatMap(record))]
            rootNode = 2
        }
        var addresses = [UInt32(rootAt | 13), UInt32(headerAt | 5)]
        addresses += nodes.map { UInt32($0.at | 12) }

        var root = u32(addresses.count) + u32(0)
        root += addresses.flatMap { u32(Int($0)) }
        root += [UInt8](repeating: 0, count: (256 - addresses.count) * 4)
        root += u32(1) + [4] + Array("DSDB".utf8) + u32(1)
        root += [UInt8](repeating: 0, count: 32 * 4)

        let header = u32(rootNode) + u32(twoLevels ? 1 : 0) + u32(entries.count) + u32(nodes.count) + u32(0x1000)

        var file = [UInt8](repeating: 0, count: 4 + rootAt + 0x2000)
        func put(_ bytes: [UInt8], at relative: Int) {
            file.replaceSubrange(4 + relative..<4 + relative + bytes.count, with: bytes)
        }
        put(u32(1) , at: -4)
        put(Array("Bud1".utf8) + u32(rootAt) + u32(0x2000) + u32(rootAt), at: 0)
        put(header, at: headerAt)
        for node in nodes { put(node.bytes, at: node.at) }
        put(root, at: rootAt)
        return Data(file)
    }

    private static func u32(_ value: Int) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8((value >> $0) & 0xff) }
    }

    private static func utf16(_ text: String) -> [UInt8] {
        text.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] }
    }
}

@Suite struct FinderTrashRecordsTests {
    private let volume = URL(fileURLWithPath: "/")

    @Test func readsWhereFinderDeletedItemsFrom() throws {
        let data = DSStoreWriter.make([
            ("photo.jpg", "ptbL", "Users/me/Pictures/"), ("photo.jpg", "ptbN", "photo.jpg"),
            ("report 10.42.17.pdf", "ptbL", "Users/me/Documents/Work/"), ("report 10.42.17.pdf", "ptbN", "report.pdf"),
            ("report 10.42.17.pdf", "Iloc", "ignored"),
        ])
        let origins = try FinderTrashRecords.parse(data, volumeRoot: volume)
        #expect(origins["photo.jpg"]?.path == "/Users/me/Pictures/photo.jpg")
        // Finder renames an item when the Trash already has that name; ptbN is the name to put back.
        #expect(origins["report 10.42.17.pdf"]?.path == "/Users/me/Documents/Work/report.pdf")
        #expect(origins.count == 2)
    }

    @Test func readsRecordsSpreadOverSeveralNodes() throws {
        let data = DSStoreWriter.make([
            ("a.txt", "ptbL", "Users/me/A/"), ("b.txt", "ptbL", "Users/me/B/"), ("c.txt", "ptbL", "Users/me/C/"),
            ("d.txt", "ptbL", "Volumes/Disk/D/"),
        ], twoLevels: true)
        let origins = try FinderTrashRecords.parse(data, volumeRoot: volume)
        #expect(origins.mapValues(\.path) == [
            "a.txt": "/Users/me/A/a.txt", "b.txt": "/Users/me/B/b.txt", "c.txt": "/Users/me/C/c.txt",
            "d.txt": "/Volumes/Disk/D/d.txt",
        ])
    }

    @Test func refusesOtherFiles() {
        #expect(throws: (any Error).self) { try FinderTrashRecords.parse(Data("hello".utf8), volumeRoot: volume) }
        var damaged = DSStoreWriter.make([("a", "ptbL", "x/")])
        damaged.removeSubrange(5000...)
        #expect(throws: (any Error).self) { try FinderTrashRecords.parse(damaged, volumeRoot: volume) }
    }

    @Test func ledgerFallsBackToFinder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FinderTrash-\(UUID().uuidString)")
        let trash = root.appendingPathComponent(".Trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let relative = String(root.path.dropFirst()) + "/Docs/"
        try DSStoreWriter.make([("note.txt", "ptbL", relative), ("note.txt", "ptbN", "note.txt")])
            .write(to: trash.appendingPathComponent(".DS_Store"))
        let trashed = trash.appendingPathComponent("note.txt")
        try "x".write(to: trashed, atomically: true, encoding: .utf8)

        let ledger = TrashLedger(file: root.appendingPathComponent("ledger.json"))
        #expect(ledger.canPutBack(trashed))
        let back = try ledger.putBack(trashed)
        #expect(back.path == root.appendingPathComponent("Docs/note.txt").path)
        #expect(FileManager.default.fileExists(atPath: back.path))
    }
}

@Suite struct SyncStateTests {
    @Test func problemsComeFirstThenSyncingThenWhereItIs() {
        #expect(SyncState(downloadingStatus: .current, isDownloading: false, isUploading: true, hasError: true,
                          hasConflicts: false) == .problem)
        #expect(SyncState(downloadingStatus: .notDownloaded, isDownloading: true, isUploading: false, hasError: false,
                          hasConflicts: false) == .syncing)
        #expect(SyncState(downloadingStatus: .notDownloaded, isDownloading: false, isUploading: false,
                          hasError: false, hasConflicts: false) == .cloudOnly)
        #expect(SyncState(downloadingStatus: .current, isDownloading: false, isUploading: false, hasError: false,
                          hasConflicts: false) == .downloaded)
    }

    @Test func localFilesHaveNone() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("local-\(UUID().uuidString).txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        #expect(DirectoryLoader.item(at: file).sync == nil)
    }
}
