@testable import SuiteFilesCore
import Foundation
import Testing

/// What sorting looks at, as Explorer's `FileItem` and Viewer's `FolderFile` give it.
struct Item: SortableFile {
    var name: String
    var isFolder: Bool
    var size: Int64?
    var modified: Date?
    var kind: String?
}

private func item(_ name: String, folder: Bool = false, size: Int64? = nil, modified: TimeInterval? = nil,
                  kind: String? = nil) -> Item {
    Item(name: name, isFolder: folder, size: size, modified: modified.map(Date.init(timeIntervalSince1970:)), kind: kind)
}

@Suite struct FileSorterTests {
    let items = [
        item("b.txt", size: 300, modified: 2, kind: "Text"),
        item("Folder", folder: true, modified: 9, kind: "Folder"),
        item("a10.png", size: 100, modified: 3, kind: "PNG image"),
        item("a2.png", size: 200, modified: 1, kind: "PNG image"),
    ]

    @Test func nameAscendingIsNaturalWithFoldersFirst() {
        let names = FileSorter.sorted(items, by: .name, ascending: true).map(\.name)
        #expect(names == ["Folder", "a2.png", "a10.png", "b.txt"])
    }

    @Test func descendingKeepsFoldersFirst() {
        let names = FileSorter.sorted(items, by: .name, ascending: false).map(\.name)
        #expect(names == ["Folder", "b.txt", "a10.png", "a2.png"])
    }

    @Test func bySizeAndDate() {
        #expect(FileSorter.sorted(items, by: .size, ascending: false).map(\.name)
                == ["Folder", "b.txt", "a2.png", "a10.png"])
        #expect(FileSorter.sorted(items, by: .modified, ascending: true).map(\.name)
                == ["Folder", "a2.png", "b.txt", "a10.png"])
    }

    @Test func byKindBreaksTiesByName() {
        #expect(FileSorter.sorted(items, by: .kind, ascending: true).map(\.name)
                == ["Folder", "a2.png", "a10.png", "b.txt"])
    }
}

@Suite struct SortChoiceTests {
    @Test func sameKeyReversesNewKeyStartsAscending() {
        var options = FolderViewOptions()
        options.sort(by: .name)
        #expect(options.sortKey == .name && !options.ascending)
        options.sort(by: .size)
        #expect(options.sortKey == .size && options.ascending)
        options.sort(by: .size)
        #expect(!options.ascending)
    }
}

@Suite struct FolderViewStoreTests {
    /// A private defaults domain, removed after each test.
    private func withStore(_ body: (FolderViewStore) throws -> Void) rethrows {
        let suite = "ExplorerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(FolderViewStore(defaults: defaults))
    }

    @Test func unknownFolderGetsDefaults() {
        withStore { store in
            #expect(store.options(for: URL(fileURLWithPath: "/a")) == FolderViewOptions())
        }
    }

    @Test func savedOptionsComeBackForTheSameFolderOnly() {
        withStore { store in
            var options = FolderViewOptions()
            options.mode = .icons
            options.sortKey = .size
            options.ascending = false
            options.columnWidths = ["Name": 420]
            store.save(options, for: URL(fileURLWithPath: "/a/b"))

            #expect(store.options(for: URL(fileURLWithPath: "/a/b/")) == options)
            #expect(store.options(for: URL(fileURLWithPath: "/a")) == FolderViewOptions())
        }
    }

    @Test func applyToAllBecomesTheDefaultAndClearsFolders() {
        withStore { store in
            var custom = FolderViewOptions()
            custom.sortKey = .kind
            store.save(custom, for: URL(fileURLWithPath: "/a"))

            var all = FolderViewOptions()
            all.mode = .icons
            store.applyToAll(all)

            #expect(store.options(for: URL(fileURLWithPath: "/a")) == all)
            #expect(store.options(for: URL(fileURLWithPath: "/elsewhere")) == all)
        }
    }
}

@Suite struct DateAddedSortTests {
    private func file(_ name: String, added: TimeInterval?, created: TimeInterval? = nil) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/d/\(name)"), name: name, isDirectory: false, isPackage: false,
                 size: nil, modified: nil, isHidden: false, kind: nil,
                 added: added.map(Date.init(timeIntervalSince1970:)),
                 created: created.map(Date.init(timeIntervalSince1970:)))
    }

    @Test func sortsByDateAddedAsFinderDoes() {
        let items = [file("b", added: 30), file("a", added: 10), file("c", added: 20)]
        #expect(FileSorter.sorted(items, by: .added, ascending: true).map(\.name) == ["a", "c", "b"])
        #expect(FileSorter.sorted(items, by: .added, ascending: false).map(\.name) == ["b", "c", "a"])
    }

    @Test func sortsByDateCreated() {
        let items = [file("b", added: nil, created: 5), file("a", added: nil, created: 9)]
        #expect(FileSorter.sorted(items, by: .created, ascending: true).map(\.name) == ["b", "a"])
    }
}

@Suite struct FoldersFirstTests {
    private func entry(_ name: String, folder: Bool = false, toFolder: Bool = false, added: TimeInterval) -> FileItem {
        var item = FileItem(url: URL(fileURLWithPath: "/d/\(name)"), name: name, isDirectory: folder, isPackage: false,
                            size: nil, modified: nil, isHidden: false, kind: nil, isAlias: toFolder,
                            added: Date(timeIntervalSince1970: added))
        item.pointsToFolder = toFolder
        return item
    }

    /// The desktop of 2026-11-24, as Finder showed it with Keep folders on top: aliases to folders with them.
    @Test func aliasesToFoldersStayWithFoldersAsFinderKeepsThem() {
        let items = [entry("EAFC.docx", added: 50), entry("Anne", folder: true, added: 30),
                     entry("JLM", folder: true, added: 20), entry("EN", toFolder: true, added: 10),
                     entry("WIP", toFolder: true, added: 60)]
        #expect(FileSorter.sorted(items, by: .added, ascending: false).map(\.name)
                == ["WIP", "Anne", "JLM", "EN", "EAFC.docx"])
        #expect(FileSorter.sorted(items, by: .added, ascending: false, foldersFirst: false).map(\.name)
                == ["WIP", "EAFC.docx", "Anne", "JLM", "EN"])
    }
}

@Suite struct DisplayModeTests {
    @Test func foldersFirstFollowsFinderUnlessChosen() {
        #expect(FoldersFirst.asFinder.sorts(finder: true))
        #expect(!FoldersFirst.asFinder.sorts(finder: false))
        #expect(FoldersFirst.always.sorts(finder: false))
        #expect(!FoldersFirst.never.sorts(finder: true))
    }
}
