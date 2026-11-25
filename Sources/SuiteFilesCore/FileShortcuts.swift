import Foundation

/// What a key press asks for in a file view, Windows style first (Ctrl+C, Delete, F2, Enter…), with the
/// Mac equivalents (Cmd+C, Cmd+Backspace, Cmd+Down…) working too.
public enum FileCommand: Equatable, Sendable {
    case copy, cut, paste, pasteMoving
    case moveToTrash
    case rename, open, goUp, goBack, goForward
    case selectAll, undo, redo, newFolder
}

/// A key press, without AppKit, so the mapping can be tested.
public struct KeyChord: Equatable, Sendable {
    public var keyCode: UInt16
    /// The characters ignoring modifiers, lowercased.
    public var characters: String
    public var command = false
    public var control = false
    public var option = false
    public var shift = false

    public init(keyCode: UInt16, characters: String, command: Bool = false, control: Bool = false,
                option: Bool = false, shift: Bool = false) {
        self.keyCode = keyCode
        self.characters = characters.lowercased()
        self.command = command
        self.control = control
        self.option = option
        self.shift = shift
    }
}

public enum FileShortcuts {
    // Key codes of the keys that have no character of their own.
    static let returnKey: UInt16 = 36, enter: UInt16 = 76, backspace: UInt16 = 51, forwardDelete: UInt16 = 117
    static let f2: UInt16 = 120, up: UInt16 = 126, down: UInt16 = 125, left: UInt16 = 123, right: UInt16 = 124

    /// `returnRenames`: Return renames, as in Finder, instead of opening, as Enter does in Windows.
    public static func command(for key: KeyChord, returnRenames: Bool = false) -> FileCommand? {
        let plain = !key.command && !key.control && !key.option && !key.shift
        // Ctrl is Windows' Cmd: Ctrl+C and Cmd+C both copy.
        let primary = (key.command != key.control) && !key.option

        switch key.keyCode {
        case returnKey where plain: return returnRenames ? .rename : .open
        case enter where plain: return .open
        case f2 where plain: return .rename
        case backspace where plain: return .goUp
        case backspace where key.command && !key.shift && !key.option && !key.control: return .moveToTrash
        case forwardDelete where plain: return .moveToTrash
        case down where key.command && !key.shift && !key.option && !key.control: return .open
        case returnKey where key.command && !key.shift && !key.option && !key.control: return .open
        case up where key.command && !key.shift && !key.option && !key.control: return .goUp
        case up where key.option && !key.command && !key.shift && !key.control: return .goUp
        case left where key.option && !key.command && !key.shift && !key.control: return .goBack
        case right where key.option && !key.command && !key.shift && !key.control: return .goForward
        default: break
        }

        guard primary || (key.command && key.option) else { return nil }
        switch (key.characters, key.shift, key.option) {
        case ("c", false, false): return .copy
        case ("x", false, false): return .cut
        case ("v", false, false): return .paste
        case ("v", false, true): return .pasteMoving      // Finder's Cmd+Option+V moves
        case ("a", false, false): return .selectAll
        case ("z", false, false): return .undo
        case ("z", true, false), ("y", false, false): return .redo
        case ("n", true, false): return .newFolder
        default: return nil
        }
    }
}

/// Type-to-select: letters typed quickly one after the other select the first item starting with them,
/// as in Explorer and Finder.
public struct TypeSelect {
    public private(set) var typed = ""
    private var last = Date.distantPast
    /// Typing after this pause starts a new search.
    public var pause: TimeInterval = 1

    public init() {}

    /// Adds what was typed and returns the text to look for.
    public mutating func add(_ characters: String, at time: Date = Date()) -> String {
        if time.timeIntervalSince(last) > pause { typed = "" }
        last = time
        typed += characters
        return typed
    }

    /// The first name starting with `prefix`, ignoring case and accents.
    public static func match(_ prefix: String, in names: [String]) -> Int? {
        guard !prefix.isEmpty else { return nil }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .anchored]
        return names.firstIndex { $0.range(of: prefix, options: options) != nil }
    }
}
