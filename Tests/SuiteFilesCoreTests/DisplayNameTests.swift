import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct DisplayNameTests {
    private func item(_ name: String, folder: Bool = false, package: Bool = false) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/tmp/" + name), name: name, isDirectory: folder || package,
                 isPackage: package, size: nil, modified: nil, isHidden: false, kind: nil)
    }

    @Test func extensionsHideOnFilesOnly() {
        #expect(item("Report.pdf").displayName(showingExtension: false) == "Report")
        #expect(item("Report.pdf").displayName(showingExtension: true) == "Report.pdf")
        #expect(item("archive.tar.gz").displayName(showingExtension: false) == "archive.tar")
        #expect(item(".zshrc").displayName(showingExtension: false) == ".zshrc")
        #expect(item("Photos 2026.v2", folder: true).displayName(showingExtension: false) == "Photos 2026.v2")
        #expect(item("Safari.app", package: true).displayName(showingExtension: false) == "Safari")
    }

    @Test func renamingKeepsTheHiddenExtension() {
        #expect(item("Report.pdf").fullName(fromEdited: "Final", showingExtension: false) == "Final.pdf")
        #expect(item("Report.pdf").fullName(fromEdited: "Final.pdf", showingExtension: true) == "Final.pdf")
        #expect(item(".zshrc").fullName(fromEdited: ".bashrc", showingExtension: false) == ".bashrc")
        #expect(item("Folder.v2", folder: true).fullName(fromEdited: "Other", showingExtension: false) == "Other")
    }
}
