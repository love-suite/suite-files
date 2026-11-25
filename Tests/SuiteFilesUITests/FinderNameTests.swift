import AppKit
import Testing
@testable import SuiteFilesUI

@Suite struct FinderNameTests {
    let font = NSFont.boldSystemFont(ofSize: 12)

    private func lines(_ name: String, _ width: CGFloat) -> [String] {
        FinderName.layout(name, font: font, width: width).components(separatedBy: "\n")
    }

    @Test func aShortNameStaysOnOneLine() {
        #expect(lines("Anne", 110) == ["Anne"])
    }

    @Test func aLongNameWrapsAfterABreakAndKeepsItsExtension() {
        let result = lines("EAFC-Protection-enfance-Mod2.docx", 112)
        #expect(result.count == 2)
        #expect(result[0].hasSuffix("-"))
        #expect(result[1].hasSuffix("docx"))
        #expect(result[1].contains("\u{2026}"))
    }

    @Test func aNameThatFitsOnTwoLinesIsWholeWithoutEllipsis() {
        let result = lines("Holiday photos 2026", 80)
        #expect(result.joined() == "Holiday photos 2026")
    }
}
