import AppKit
import SuiteFilesCore
import SuiteCore

/// One Undo history for every app of the suite that changes files, as Windows has: Ctrl+Z undoes the last
/// file operation wherever it was made (an Explorer window, the desktop, Bar, Viewer), kept in the shared
/// journal (`FileUndoJournal`).
public enum FileUndo {
    /// Posted in this app after the history changed here or in another app, so views reload and menus
    /// say what Undo and Redo would do.
    public static let didChange = Notification.Name("FileUndoDidChange")

    nonisolated(unsafe) public static var journal = FileUndoJournal.shared

    public static func record(_ operation: FileOperation?) {
        guard let operation else { return }
        journal.record(operation)
        changed()
    }

    public static func undo() { step(journal.undo) }

    public static func redo() { step(journal.redo) }

    public static var canUndo: Bool { journal.nextUndo != nil }
    public static var canRedo: Bool { journal.nextRedo != nil }

    /// "Undo Move", as the Edit menu says it; "Undo" when there is nothing to undo.
    public static var undoMenuItemTitle: String {
        journal.nextUndo.map { String(format: FL("Undo %@"), FL($0.name)) } ?? FL("Undo")
    }

    public static var redoMenuItemTitle: String {
        journal.nextRedo.map { String(format: FL("Redo %@"), FL($0.name)) } ?? FL("Redo")
    }

    private static func step(_ run: ((FileOperation) throws -> FileOperation) throws -> FileUndoJournal.Entry?) {
        do {
            guard try run({ try $0.undo() }) != nil else { return NSSound.beep() }
        } catch {
            FileActions.showError(error.localizedDescription)
        }
        changed()
    }

    private static func changed() {
        FileUndoJournal.announceChange()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static var observers: [NSObjectProtocol] = []

    /// At launch, in every app with file views: the history changed in another app (menus and views
    /// follow), and what another app (Viewer, Bar) moved to the Trash keeps its origin for Restore.
    public static func recordTrashingInOtherApps() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        let me = String(ProcessInfo.processInfo.processIdentifier)
        observers.append(center.addObserver(forName: FileUndoJournal.didChangeNotification, object: nil,
                                            queue: .main) { note in
            guard (note.object as? String) != me else { return }
            NotificationCenter.default.post(name: didChange, object: nil)
        })
        observers.append(center.addObserver(forName: SuiteTrash.didTrashNotification, object: nil,
                                            queue: .main) { note in
            for item in SuiteTrash.items(of: note) {
                TrashLedger.shared.record(original: item.original, trashed: item.trashed)
            }
        })
    }
}

/// Copy, Cut and Paste of files through the system pasteboard, so they also paste into Finder, Mail or
/// any app, and files copied elsewhere paste here. Cut marks the files; pasting them moves them.
public enum FileClipboard {
    private static let cutMarker = NSPasteboard.PasteboardType("local.suite.files.cut")

    public static func copy(_ urls: [URL]) { write(urls, cut: false) }
    public static func cut(_ urls: [URL]) { write(urls, cut: true) }

    private static func write(_ urls: [URL], cut: Bool) {
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        if cut { pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: cutMarker) }
    }

    public static var urls: [URL] {
        NSPasteboard.general.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    public static var canPaste: Bool { !urls.isEmpty }

    /// The URLs Cut marked, if the pasteboard still holds them.
    private static var isCut: Bool {
        guard let marked = NSPasteboard.general.string(forType: cutMarker) else { return false }
        return marked == urls.map(\.path).joined(separator: "\n")
    }

    /// Pastes into `folder`: cut files move, copied files copy (`moving` forces a move, Cmd+Option+V).
    /// Returns where they are now.
    @discardableResult
    public static func paste(into folder: URL, moving: Bool = false) -> [URL] {
        let sources = urls
        guard !sources.isEmpty else { return [] }
        let move = moving || isCut
        let created = TransferRunner.run(sources, into: folder, operation: move ? .move : .copy)
        // Cut files can only be pasted once, as in Windows.
        if move && !created.isEmpty { NSPasteboard.general.clearContents() }
        return created
    }
}

/// Runs a move or copy: asks what to do with names already taken (Replace, Skip, Keep Both, for all
/// the items if wanted), shows a progress window when it takes a while, records it for Undo.
public enum TransferRunner {
    @discardableResult
    public static func run(_ sources: [URL], into folder: URL, operation: TransferOperation) -> [URL] {
        var choiceForAll: ConflictChoice?
        var progressWindow: TransferProgressWindow?
        let started = Date()
        do {
            let result = try FileTransfer.run(
                sources, into: folder, operation: operation,
                onConflict: { existing, incoming in
                    if let choiceForAll { return choiceForAll }
                    let (choice, forAll) = askAboutConflict(existing: existing, incoming: incoming,
                                                            remaining: sources.count > 1)
                    if forAll { choiceForAll = choice }
                    return choice
                },
                progress: { done, next in
                    // Only long operations get a window, as in Windows.
                    if progressWindow == nil, Date().timeIntervalSince(started) > 0.5 {
                        progressWindow = TransferProgressWindow(operation: operation, total: sources.count,
                                                                folder: folder)
                    }
                    return progressWindow?.update(done: done, next: next) ?? true
                })
            progressWindow?.close()
            FileUndo.record(result.operation(operation))
            return result.created
        } catch {
            progressWindow?.close()
            FileActions.showError(error.localizedDescription)
            return []
        }
    }

    private static func askAboutConflict(existing: URL, incoming: URL, remaining: Bool) -> (ConflictChoice, Bool) {
        let alert = NSAlert()
        alert.messageText = String(format: FL("The destination already has an item named \u{201C}%@\u{201D}."), existing.lastPathComponent)
        alert.informativeText = FL("Replace it (the old one goes to the Trash), skip this item, or keep both?")
        alert.addButton(withTitle: FL("Replace"))
        alert.addButton(withTitle: FL("Skip"))
        alert.addButton(withTitle: FL("Keep Both"))
        if remaining {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = FL("Do this for all conflicts")
        }
        NSApp.activate(ignoringOtherApps: true)
        let choice: ConflictChoice
        switch alert.runModal() {
        case .alertFirstButtonReturn: choice = .replace
        case .alertSecondButtonReturn: choice = .skip
        default: choice = .keepBoth
        }
        return (choice, alert.suppressionButton?.state == .on)
    }
}

/// "Copying 3 of 120 items to Pictures", with a bar and Stop.
final class TransferProgressWindow {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private var stopped = false
    private let verb: String
    private let total: Int
    private let folderName: String

    init(operation: TransferOperation, total: Int, folder: URL) {
        verb = operation == .copy ? FL("Copying") : FL("Moving")
        self.total = total
        folderName = FileManager.default.displayName(atPath: folder.path)
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 110),
                        styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = verb
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = Double(total)
        let stop = NSButton(title: FL("Stop"), target: nil, action: nil)
        let stack = NSStackView(views: [label, bar, stop])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        bar.widthAnchor.constraint(equalToConstant: 380).isActive = true
        panel.contentView = stack
        stop.target = StopTarget.shared
        stop.action = #selector(StopTarget.stop)
        StopTarget.shared.onStop = { [weak self] in self?.stopped = true }
        panel.center()
        panel.orderFront(nil)
    }

    /// Shows the next item; false once Stop was pressed.
    func update(done: Int, next: URL) -> Bool {
        label.stringValue = String(format: FL("%@ %d of %d items to \u{201C}%@\u{201D}: %@"),
                                   verb, done + 1, total, folderName, next.lastPathComponent)
        bar.doubleValue = Double(done)
        // Let the window draw and the Stop button be pressed between items.
        RunLoop.current.run(mode: .default, before: Date())
        return !stopped
    }

    func close() { panel.orderOut(nil) }

    private final class StopTarget: NSObject {
        static let shared = StopTarget()
        var onStop: (() -> Void)?
        @objc func stop() { onStop?() }
    }
}

/// Renaming in place (F2 or clicking a selected name): a field over the name, the extension left out of
/// the selection, Return to confirm, Escape to cancel, as in Windows.
public final class InlineRenamer: NSObject, NSTextFieldDelegate {
    private static var current: InlineRenamer?
    private let field = NSTextField()
    private let original: String
    private let completion: (String?) -> Void
    private var finished = false
    /// The name being edited, hidden under the field until it closes.
    private var hidden: [NSView] = []
    private var wraps = false
    private var centered = true
    private var anchor = NSRect.zero

    /// Edits `name` in a field covering `rect` of `view`; `completion` gets the new name, or nil.
    /// `hiding` are the views showing the name, hidden while the field is open. `wraps`: the name wraps
    /// within `rect`'s width and the field grows downwards, as in Finder: centred under an icon, or
    /// left-aligned in a list's Name column (`centered` false), never spilling over other columns.
    public static func begin(in view: NSView, over rect: NSRect, name: String, font: NSFont,
                             hiding: [NSView] = [], wraps: Bool = false, centered: Bool = true,
                             completion: @escaping (String?) -> Void) {
        current?.finish(commit: true)
        let renamer = InlineRenamer(name: name, completion: completion)
        current = renamer
        renamer.hidden = hiding.filter { !$0.isHidden }
        renamer.hidden.forEach { $0.isHidden = true }
        renamer.wraps = wraps
        renamer.centered = centered
        renamer.show(in: view, over: rect, font: font)
    }

    private init(name: String, completion: @escaping (String?) -> Void) {
        original = name
        self.completion = completion
    }

    private func show(in view: NSView, over rect: NSRect, font: NSFont) {
        field.stringValue = original
        field.font = font
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .squareBezel
        field.focusRingType = .exterior
        // Opaque, so nothing under it shows through.
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.delegate = self
        anchor = rect
        if wraps {
            field.cell?.wraps = true
            field.cell?.isScrollable = false
            field.cell?.lineBreakMode = .byCharWrapping
            field.alignment = centered ? .center : .natural
            fitWrappedField()
        } else {
            field.cell?.wraps = false
            field.cell?.isScrollable = true
            let width = max(rect.width, (original as NSString).size(withAttributes: [.font: font]).width + 24)
            field.frame = NSRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: max(rect.height, 22))
                .intersection(view.bounds.insetBy(dx: 2, dy: 0))
        }
        field.wantsLayer = true
        field.layer?.zPosition = 100
        view.addSubview(field)
        view.window?.makeFirstResponder(field)
        let base = (original as NSString).deletingPathExtension as NSString
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: base.length)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): finish(commit: true); return true
        case #selector(NSResponder.cancelOperation(_:)): finish(commit: false); return true
        default: return false
        }
    }

    /// As wide as the icon's cell (or the Name column), as tall as the name needs, at least the row's height.
    private func fitWrappedField() {
        let width = centered ? anchor.width + 8 : anchor.width
        let needed = field.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 1000)).height ?? 22
        let height = max(ceil(needed), centered ? 20 : anchor.height)
        let x = centered ? anchor.midX - width / 2 : anchor.minX
        field.frame = NSRect(x: x, y: anchor.minY, width: width, height: height)
    }

    public func controlTextDidChange(_ notification: Notification) {
        if wraps { fitWrappedField() }
    }

    public func controlTextDidEndEditing(_ notification: Notification) {
        finish(commit: true)
    }

    private func finish(commit: Bool) {
        guard !finished else { return }
        finished = true
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        let window = field.window
        field.removeFromSuperview()
        hidden.forEach { $0.isHidden = false }
        hidden = []
        if Self.current === self { Self.current = nil }
        window?.makeFirstResponder(window?.contentView)
        completion(commit && !name.isEmpty && name != original ? name : nil)
    }
}
