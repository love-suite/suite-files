import AppKit
import SuiteFilesCore
import SuiteCore

/// File actions shared by the desktop and Explorer windows: opening, renaming, new folders, the Trash.
public enum FileActions {
    /// After Put Back, with where the items are now: the app showing the Trash may open the folder they
    /// went back to (Explorer does, when chosen in its settings). Nothing by default.
    nonisolated(unsafe) public static var didPutBack: ([URL]) -> Void = { _ in }

    /// Erases Trash items the user may not erase, which needs root: the app holding the Suite Trash
    /// helper (Explorer) sets it. By default they are reported as not deleted.
    nonisolated(unsafe) public static var eraseNeedingRoot: ([URL]) -> Void = { urls in
        report(Dictionary(uniqueKeysWithValues: urls.map { ($0, CocoaError(.fileWriteNoPermission) as Error) }))
    }

    /// Folders, and shortcuts to folders, open in an Explorer window; files and apps open as usual.
    public static func open(_ item: FileItem, inFolder openFolder: (URL) -> Void) {
        if item.isFolder {
            openFolder(item.url)
        } else if let target = ShortcutResolver.folderTarget(of: item.url) {
            openFolder(target)
        } else {
            openFile(item.url)
        }
    }

    /// Pictures and PDFs open in Explorer's viewer; other files in their app.
    public static func openFile(_ url: URL) {
        if ViewerHandoff.shows(url) {
            ViewerHandoff.open(url)
        } else if ViewerHandoff.showsPDF(url) {
            ViewerHandoff.openPDF(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Asks for a new name in a dialog and renames; returns the new URL, or nil if cancelled or failed.
    @discardableResult
    public static func rename(_ url: URL) -> URL? {
        guard let name = askForName(initial: url.lastPathComponent) else { return nil }
        return rename(url, to: name)
    }

    /// Renames, for Undo too; returns the new URL, or nil after showing why it failed.
    @discardableResult
    public static func rename(_ url: URL, to name: String) -> URL? {
        guard !name.contains("/") else {
            showError(FL("A file name can't contain \u{201C}/\u{201D}."))
            return nil
        }
        do {
            let renamed = try FileRenamer.rename(url, to: name)
            FileUndo.record(.renamed(from: url, to: renamed))
            return renamed
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }

    /// Like Explorer: the new folder or file gets a default name; the view then offers it for renaming.
    @discardableResult
    public static func create(_ template: FileTemplate, in folder: URL) -> URL? {
        do {
            let created = try template.create(in: folder)
            FileUndo.record(.created([created]))
            return created
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }

    public static func moveToTrash(_ urls: [URL]) {
        var originals: [URL] = [], trashed: [URL] = []
        do {
            for url in urls {
                trashed.append(try FileTrash.moveToTrash(url))
                originals.append(url)
            }
        } catch {
            showError(error.localizedDescription)
        }
        if !trashed.isEmpty {
            FileUndo.record(.trashed(originals: originals, trashed: trashed))
            FinderSounds.play(.moveToTrash)
        }
    }

    // MARK: Open With, compress

    /// The apps that can open `url`, the default one first.
    public static func applications(toOpen url: URL) -> [URL] {
        let all = NSWorkspace.shared.urlsForApplications(toOpen: url)
        guard let preferred = NSWorkspace.shared.urlForApplication(toOpen: url) else { return all }
        return [preferred] + all.filter { $0.standardizedFileURL != preferred.standardizedFileURL }
    }

    public static func open(_ urls: [URL], with app: URL) {
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    /// "Always open with": makes `app` the default for files of this type.
    public static func makeDefault(_ app: URL, for url: URL) {
        guard let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType else { return }
        NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { error in
            if let error { DispatchQueue.main.async { showError(error.localizedDescription) } }
        }
    }

    /// Lets the user pick any app to open `urls` with.
    public static func chooseApplication(for urls: [URL]) {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.prompt = FL("Open")
        panel.message = String(format: FL("Choose an app to open \u{201C}%@\u{201D}."), urls.first?.lastPathComponent ?? "")
        guard panel.runModal() == .OK, let app = panel.url else { return }
        open(urls, with: app)
    }

    @discardableResult
    public static func compress(_ urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }
        do {
            let archive = try Archiver.compress(urls)
            FileUndo.record(.created([archive]))
            return archive
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    public static func extract(_ archive: URL) -> URL? {
        do {
            let folder = try Archiver.extract(archive)
            FileUndo.record(.created([folder]))
            return folder
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }

    // MARK: Trash

    /// Moves trashed items back where they came from; returns where they are now.
    @discardableResult
    public static func putBack(_ urls: [URL]) -> [URL] {
        var trashed: [URL] = [], restored: [URL] = []
        for url in urls where TrashLedger.shared.canPutBack(url) {
            do {
                restored.append(try TrashLedger.shared.putBack(url))
                trashed.append(url)
            } catch {
                showError(error.localizedDescription)
            }
        }
        if !restored.isEmpty { FileUndo.record(.moved(from: trashed, to: restored)) }
        if !restored.isEmpty { didPutBack(restored) }
        return restored
    }

    /// Erases items for good, after asking, as Delete does in Windows' Recycle Bin. Only items already in
    /// the Trash are erased: anything else is moved to the Trash instead, so nothing is ever lost in one step.
    public static func deletePermanently(_ requested: [URL]) {
        let (urls, outside) = TrashFolder.partition(requested)
        if !outside.isEmpty { moveToTrash(outside) }
        guard !urls.isEmpty else { return }
        let message = urls.count == 1
            ? String(format: FL("Are you sure you want to permanently delete \u{201C}%@\u{201D}?"), urls[0].lastPathComponent)
            : String(format: FL("Are you sure you want to permanently delete these %d items?"), urls.count)
        guard confirm(message, FL("You can't undo this action."), button: FL("Delete")) else { return }
        FinderSounds.play(.emptyTrash)
        let (denied, other) = splitByPermission(TrashFolder.erase(urls))
        if !other.isEmpty { report(other) }
        if !denied.isEmpty { eraseAsAdmin(denied) }
    }

    public static func emptyTrash() {
        guard confirm(FL("Are you sure you want to permanently erase the items in the Trash?"),
                      FL("You can't undo this action."), button: FL("Empty Trash")) else { return }
        do {
            let (denied, other) = splitByPermission(try TrashFolder.empty())
            FinderSounds.play(.emptyTrash)
            if !other.isEmpty { report(other) }
            if !denied.isEmpty { eraseAsAdmin(denied) }
        } catch {
            if TrashFolder.needsFullDiskAccess(error) {
                askForFullDiskAccess()
            } else {
                showError(error.localizedDescription)
            }
        }
    }

    /// Explains why, and leads to the setting.
    public static func askForFullDiskAccess() {
        let alert = NSAlert()
        alert.messageText = FL("Explorer needs Full Disk Access to see the Trash.")
        alert.informativeText = TrashFolder.accessMessage(for: CocoaError(.fileReadNoPermission))
        alert.addButton(withTitle: FL("Open Settings"))
        alert.addButton(withTitle: FL("Cancel"))
        alert.addButton(withTitle: FL("Quit & Reopen"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: TrashFolder.openFullDiskAccessSettings()
        case .alertThirdButtonReturn: AppRelauncher.relaunch()
        default: break
        }
    }

    private static func splitByPermission(_ failed: [URL: Error]) -> ([URL], [URL: Error]) {
        var denied: [URL] = []
        var other: [URL: Error] = [:]
        for (url, error) in failed {
            if isPermissionError(error) { denied.append(url) } else { other[url] = error }
        }
        return (denied, other)
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           ns.code == NSFileWriteNoPermissionError || ns.code == NSFileReadNoPermissionError { return true }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(EACCES) || ns.code == Int(EPERM) { return true }
        return false
    }

    private static func eraseAsAdmin(_ urls: [URL]) {
        eraseNeedingRoot(urls)
    }

    private static func report(_ failed: [URL: Error]) {
        guard !failed.isEmpty else { return }
        if failed.count == 1, let entry = failed.first {
            showError(String(format: FL("\u{201C}%@\u{201D} couldn't be deleted.\n%@"),
                             entry.key.lastPathComponent, entry.value.localizedDescription))
        } else {
            let names = failed.keys.map(\.lastPathComponent).sorted().joined(separator: ", ")
            showError(String(format: FL("Some items couldn't be deleted: %@"), names))
        }
    }

    private static func confirm(_ message: String, _ detail: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: FL("Cancel"))
        alert.buttons[0].hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    public static func askForName(initial: String) -> String? {
        let field = NSTextField(string: initial)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        let alert = NSAlert()
        alert.messageText = FL("Rename")
        alert.accessoryView = field
        alert.addButton(withTitle: FL("Rename"))
        alert.addButton(withTitle: FL("Cancel"))
        alert.window.initialFirstResponder = field
        // Select the name without its extension, as Explorer does.
        DispatchQueue.main.async {
            let base = (initial as NSString).deletingPathExtension as NSString
            field.currentEditor()?.selectedRange = NSRange(location: 0, length: base.length)
        }
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name == initial { return nil }
        if name.contains("/") {
            showError(FL("A file name can't contain \u{201C}/\u{201D}."))
            return nil
        }
        return name
    }

    public static func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

extension TrashFolder {
    public static func needsFullDiskAccess(_ error: Error) -> Bool {
        (error as NSError).code == NSFileReadNoPermissionError
    }

    /// macOS only shows the Trash to apps with Full Disk Access, which only the user can grant.
    public static func accessMessage(for error: Error) -> String {
        guard needsFullDiskAccess(error) else { return error.localizedDescription }
        return FL("macOS only shows the Trash to apps with Full Disk Access, and only you can turn it on.\nOpen the setting and turn on Explorer. If it isn't in the list, drag Explorer there from the window that opens next to it. Then choose Quit & Reopen.")
    }

    /// System Settings › Privacy & Security › Full Disk Access, with Explorer.app shown in a window so it
    /// can be dragged into the list (macOS only lists apps the user adds).
    public static func openFullDiskAccessSettings() {
        FileViewer.reveal([Bundle.main.bundleURL])
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

