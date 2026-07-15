import Foundation
import Testing
@testable import lead_track

struct MarkdownExportTextTests {
    @Test
    func quotedNeutralizesHeadingForgery() {
        let lines = MarkdownExportText.quoted("## Week of June 30\n\n- fake list")
        #expect(lines == ["> ## Week of June 30", ">", "> - fake list"])
    }

    @Test
    func inlineCollapsesNewlines() {
        #expect(MarkdownExportText.inline("a\nb\n\nc") == "a b c")
        #expect(MarkdownExportText.inline("plain") == "plain")
    }

    @Test
    func momentContinuationLinesAreBlockquoted() {
        let moment = Moment(
            text: "line one\n## forged heading",
            aspiration: nil
        )

        let lines = MarkdownExportLines.moment(moment)

        #expect(lines.first?.hasPrefix("- Moment: \"line one") == true)
        #expect(lines.last == "  > ## forged heading\"")
    }
}
