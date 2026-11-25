import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct FinderIconPositionsTests {
    @Test func readsWhereFinderPlacedEachIcon() throws {
        let data = DSStoreWriter.make([
            (name: "Notes.txt", code: "Iloc", value: "120,80"),
            (name: "Photos", code: "Iloc", value: "1300,450"),
            (name: "Report.pdf", code: "ptbL", value: "Users/me/Documents/"),
        ])
        let positions = try FinderIconPositions.positions(from: data)
        #expect(positions == ["Notes.txt": CGPoint(x: 120, y: 80), "Photos": CGPoint(x: 1300, y: 450)])
    }

    @Test func aShortBlobIsNoPosition() {
        #expect(FinderIconPositions.point(from: Data([0, 0, 1])) == nil)
    }

    @Test func aFolderWithoutFindersFileHasNone() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(FinderIconPositions.positions(in: folder).isEmpty)
    }
}
