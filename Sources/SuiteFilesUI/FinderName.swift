import AppKit

/// A name under an icon as Finder lays it out: on one line if it fits, otherwise wrapped onto two lines
/// (at a space, hyphen, underscore or dot when one fits), the second cut in the middle so its end (the
/// extension) still shows.
public enum FinderName {
    public static func layout(_ name: String, font: NSFont, width: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func fits(_ text: String) -> Bool { (text as NSString).size(withAttributes: attributes).width <= width }
        if fits(name) { return name }
        let characters = Array(name)
        // The first line: the longest start that fits, ended after a break character when there is one.
        var fitting = 0, afterBreak = 0
        for end in 1...characters.count {
            guard fits(String(characters[0..<end])) else { break }
            fitting = end
            if " -_.".contains(characters[end - 1]) { afterBreak = end }
        }
        guard fitting > 0 else { return name }
        let firstEnd = afterBreak > 0 ? afterBreak : fitting
        let first = String(characters[0..<firstEnd])
        let rest = Array(characters[firstEnd...])
        if fits(String(rest)) { return first + "\n" + String(rest) }
        return first + "\n" + cutInTheMiddle(rest, fits: fits)
    }

    /// Keeps the end after the last dot (the extension), then as much of the start as fits, then more of
    /// the end, around an ellipsis.
    static func cutInTheMiddle(_ characters: [Character], fits: (String) -> Bool) -> String {
        let ellipsis = "\u{2026}"
        let dot = characters.lastIndex(of: ".").map { characters.distance(from: $0, to: characters.endIndex) - 1 } ?? 0
        var tail = min(dot, characters.count - 1)
        var head = 0
        func text(_ h: Int, _ t: Int) -> String {
            String(characters.prefix(h)) + ellipsis + String(characters.suffix(t))
        }
        while tail > 0 && !fits(text(head, tail)) { tail -= 1 }
        while head + tail < characters.count - 1 && fits(text(head + 1, tail)) { head += 1 }
        while head + tail < characters.count - 1 && fits(text(head, tail + 1)) { tail += 1 }
        return text(head, tail)
    }
}
