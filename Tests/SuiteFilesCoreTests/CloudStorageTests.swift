import Foundation
import Testing
@testable import SuiteFilesCore

@Suite struct CloudStorageTests {
    @Test func providersAreNamedAsFinderDoes() {
        #expect(CloudStorage.displayName(ofFolderNamed: "GoogleDrive-me@example.com") == "Google Drive")
        #expect(CloudStorage.displayName(ofFolderNamed: "ProtonDrive-me@example.com-folder") == "Proton Drive")
        #expect(CloudStorage.displayName(ofFolderNamed: "OneDrive-Personal") == "OneDrive")
        #expect(CloudStorage.displayName(ofFolderNamed: "Dropbox") == "Dropbox")
        #expect(CloudStorage.displayName(ofFolderNamed: "MacDroid-S21") == "MacDroid")
    }

    @Test func plainFoldersAreNotAccounts() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("CloudStorage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: storage.appendingPathComponent("Stale-me (old copy)"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storage) }
        #expect(CloudStorage.folders(in: storage).isEmpty)
    }
}
