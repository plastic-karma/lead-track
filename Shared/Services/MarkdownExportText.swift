import Foundation

/// Keeps free-form user text inert inside the export's markdown structure.
/// The artifact is written to be pasted into an LLM conversation, so a note
/// line like "## Week of June 30" must not forge a section heading, and an
/// embedded instruction must read as quoted testimony rather than a
/// document-level directive.
enum MarkdownExportText {
    /// Multi-line user text rendered as a blockquote: every line is marked
    /// as quoted material and none can open a heading, list, or fence.
    static func quoted(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { line in
            line.isEmpty ? ">" : "> \(line)"
        }
    }

    /// User text flattened for interpolation into a single structural line
    /// (a heading, a list item): newlines collapse to spaces so the text
    /// cannot break out of the line that quotes it.
    static func inline(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
