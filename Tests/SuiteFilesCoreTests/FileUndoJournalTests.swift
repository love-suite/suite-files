import Foundation
import Testing
@testable import SuiteFilesCore

private func freshJournal() -> FileUndoJournal {
    FileUndoJournal(file: FileManager.default.temporaryDirectory
        .appendingPathComponent("FileUndoJournalTests-\(UUID().uuidString)/Undo.json"))
}

private let a = URL(fileURLWithPath: "/tmp/a.txt"), b = URL(fileURLWithPath: "/tmp/b.txt")

@Suite struct FileUndoJournalTests {
    @Test func anOperationCanBeUndoneThenRedone() throws {
        let journal = freshJournal()
        journal.record(.renamed(from: a, to: b))
        #expect(journal.nextUndo?.name == "Rename")
        var performed: [FileOperation] = []
        let undone = try journal.undo { performed.append($0); return .renamed(from: b, to: a) }
        #expect(undone?.operation == .renamed(from: a, to: b))
        #expect(journal.nextUndo == nil)
        #expect(journal.nextRedo?.operation == .renamed(from: b, to: a))
        // Waiting to be redone, it keeps the name of what the user did.
        #expect(journal.nextRedo?.name == "Rename")
        try journal.redo { performed.append($0); return .renamed(from: a, to: b) }
        #expect(performed == [.renamed(from: a, to: b), .renamed(from: b, to: a)])
        #expect(journal.nextUndo?.operation == .renamed(from: a, to: b))
        #expect(journal.nextRedo == nil)
    }

    @Test func aNewOperationForgetsWhatCouldBeRedone() throws {
        let journal = freshJournal()
        journal.record(.created([a]))
        try journal.undo { _ in .trashed(originals: [a], trashed: [b]) }
        journal.record(.created([b]))
        #expect(journal.nextRedo == nil)
    }

    @Test func anOperationThatFailsToUndoStaysInTheHistory() {
        let journal = freshJournal()
        journal.record(.moved(from: [a], to: [b]))
        #expect(throws: CocoaError.self) { try journal.undo { _ in throw CocoaError(.fileNoSuchFile) } }
        #expect(journal.nextUndo?.operation == .moved(from: [a], to: [b]))
        #expect(journal.nextRedo == nil)
    }

    @Test func twoAppsShareOneHistory() throws {
        let first = freshJournal()
        let second = FileUndoJournal(file: first.file)
        first.record(.created([a]))
        #expect(second.nextUndo?.operation == .created([a]))
        try second.undo { _ in .trashed(originals: [a], trashed: [b]) }
        #expect(first.nextUndo == nil)
        #expect(first.nextRedo?.name == "New Item")
    }

    @Test func onlyTheLatestOperationsAreKept() {
        let journal = freshJournal()
        for i in 0..<(FileUndoJournal.limit + 5) {
            journal.record(.created([URL(fileURLWithPath: "/tmp/\(i)")]))
        }
        #expect(journal.read().undo.count == FileUndoJournal.limit)
        #expect(journal.read().undo.first?.operation == .created([URL(fileURLWithPath: "/tmp/5")]))
    }

    @Test func nothingToUndoIsNil() throws {
        #expect(try freshJournal().undo { $0 } == nil)
    }
}
