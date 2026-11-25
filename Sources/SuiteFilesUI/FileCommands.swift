import AppKit
import SuiteFilesCore

/// A view of files that answers the keyboard and the Edit menu the same way everywhere (the desktop and
/// Explorer windows): Windows keys first, Mac keys too.
public protocol FileCommandHandling: AnyObject {
    /// The selected items.
    var commandSelection: [URL] { get }
    /// Where new and pasted items go.
    var commandFolder: URL? { get }
    func beginInlineRename()
    func openCommandSelection()
    func goUpCommand()
    func goBackCommand()
    func goForwardCommand()
    func selectAllCommand()
    /// Reloads and selects `urls` (pasted, created, renamed).
    func showChanges(selecting urls: [URL])
}

public extension FileCommandHandling {
    func goBackCommand() {}
    func goForwardCommand() {}

    /// Performs a key press's command; false if the key means nothing here.
    @discardableResult
    func handle(_ command: FileCommand) -> Bool {
        let selection = commandSelection
        switch command {
        case .copy:
            guard !selection.isEmpty else { return false }
            FileClipboard.copy(selection)
        case .cut:
            guard !selection.isEmpty else { return false }
            FileClipboard.cut(selection)
        case .paste, .pasteMoving:
            guard let folder = commandFolder, FileClipboard.canPaste else { NSSound.beep(); return true }
            showChanges(selecting: FileClipboard.paste(into: folder, moving: command == .pasteMoving))
        case .moveToTrash:
            guard !selection.isEmpty else { return false }
            // In the Trash, Delete erases, as in the Recycle Bin; elsewhere it moves to the Trash.
            if let folder = commandFolder, TrashFolder.contains(folder) {
                FileActions.deletePermanently(selection)
            } else {
                FileActions.moveToTrash(selection)
            }
            showChanges(selecting: [])
        case .rename:
            guard selection.count == 1 else { return false }
            beginInlineRename()
        case .open:
            guard !selection.isEmpty else { return false }
            openCommandSelection()
        case .goUp: goUpCommand()
        case .goBack: goBackCommand()
        case .goForward: goForwardCommand()
        case .selectAll: selectAllCommand()
        case .undo: FileUndo.undo()
        case .redo: FileUndo.redo()
        case .newFolder:
            guard let folder = commandFolder, let created = FileActions.create(.folder, in: folder) else { return true }
            showChanges(selecting: [created])
            beginInlineRename()
        }
        return true
    }

    /// Keys: Quick Look and Properties, then file commands, else nothing.
    func handleFileKey(_ event: NSEvent) -> Bool {
        switch QuickLook.key(for: event) {
        case .preview: QuickLook.toggle(); return true
        case .properties: PropertiesWindow.show(commandSelection); return true
        case nil: break
        }
        guard let command = FileKeys.command(for: event) else { return false }
        return handle(command)
    }

    /// Edit menu titles and states.
    func validateFileCommand(_ item: NSMenuItem) -> Bool? {
        let inTrash = commandFolder.map { TrashFolder.contains($0) } ?? false
        switch item.action {
        case #selector(NSText.copy(_:)), #selector(NSText.cut(_:)): return !commandSelection.isEmpty
        case #selector(NSText.paste(_:)), Selector(("pasteMoving:")):
            return commandFolder != nil && !inTrash && FileClipboard.canPaste
        // In the Trash, items are restored or erased (Restore, Delete Permanently), not trashed again,
        // renamed or joined by new ones.
        case Selector(("moveToTrash:")), Selector(("renameSelection:")), Selector(("newFolder:")):
            return inTrash ? false : nil
        case Selector(("undo:")):
            item.title = FileUndo.undoMenuItemTitle
            return FileUndo.canUndo
        case Selector(("redo:")):
            item.title = FileUndo.redoMenuItemTitle
            return FileUndo.canRedo
        default: return nil
        }
    }
}

public enum FileKeys {
    public static func command(for event: NSEvent) -> FileCommand? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return FileShortcuts.command(for: KeyChord(
            keyCode: event.keyCode, characters: event.charactersIgnoringModifiers ?? "",
            command: flags.contains(.command), control: flags.contains(.control),
            option: flags.contains(.option), shift: flags.contains(.shift)),
            returnRenames: DisplaySettings.returnKeyRenames)
    }

    /// Letters and digits typed without modifiers, for type-to-select.
    public static func typedText(_ event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty, let text = event.characters, !text.isEmpty,
              text.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-"
                  || $0 == "_" }) else { return nil }
        return text
    }
}
