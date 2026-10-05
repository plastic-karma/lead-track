import Foundation
import Testing
@testable import lead_track

struct ObsidianVaultCodecTests {
    private let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

    private func note(_ properties: String = "", body: String = "", newline: String = "\n") -> Data {
        let header = """
        ---
        leadstone_id: \(id.uuidString)
        leadstone_type: aspiration
        leadstone_version: 1
        """ + "\n" + properties + "---\n"
        return Data((header.replacingOccurrences(of: "\n", with: newline) + body).utf8)
    }

    private func decode(_ data: Data) throws -> VaultRecord {
        let graph = try ObsidianVaultCodec.decode(["Aspirations/test.md": data])
        return try #require(graph.records[id])
    }

    @Test
    func proseAndLinksRoundTripWithoutNewlineChanges() throws {
        let body = "\r\n# My prose\r\n[[Other note|label]]\n\n- [ ] write\r\n\r\n"
        let record = try decode(note("title: 'A writer''s life'\n", body: body, newline: "\r\n"))
        #expect(record.body == body)
        #expect(record.fields["title"] == .string("A writer's life"))
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        let restored = try #require(ObsidianVaultCodec.decode(files).records[id])
        #expect(restored.body == body)
        #expect(restored.fields["aliases"] == .array([.string("A writer's life")]))
    }

    @Test(arguments: ["", "text", "text\n", "text\n\n", "---\nprose\n---"])
    func entireBodyIsEditable(_ body: String) throws {
        let record = try decode(note(body: body))
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        #expect(try ObsidianVaultCodec.decode(files).records[id]?.body == body)
    }

    @Test
    func propertyEditorScalarAndListFormats() throws {
        let properties = """
        title: Plain words # comment
        enabled: true
        amount: -1.25e2
        missing: null
        links:
          - "[[abc|A, B]]"
          - '[[folder/note]]'
        aliases: ["one, two", 'it''s fine', plain]
        empty: []
        """ + "\n"
        let record = try decode(note(properties))
        #expect(record.fields["title"] == .string("Plain words"))
        #expect(record.fields["enabled"] == .bool(true))
        #expect(record.fields["amount"] == .number(-125))
        #expect(record.fields["missing"] == .null)
        #expect(record.fields["links"] == .array([.string("[[abc|A, B]]"), .string("[[folder/note]]")]))
        #expect(record.fields["aliases"] == .array([.string("one, two"), .string("it's fine"), .string("plain")]))
        #expect(record.fields["empty"] == .array([]))
    }

    @Test
    func indentlessSequenceAndWikilinkScalars() throws {
        let record = try decode(note("links:\n- [[abc]]\n- \"[[def|Friend]]\"\nrelation: [[abc]]\n"))
        #expect(record.fields["links"] == .array([.string("[[abc]]"), .string("[[def|Friend]]")]))
        #expect(record.fields["relation"] == .string("[[abc]]"))
    }

    @Test
    func literalAndFoldedBlocksHaveYamlChomping() throws {
        let properties = "literal: |-\n  first\n  ---\n  last\nfolded: >\n  first\n  second\n\n  next\nkept: |+\n  a\n\n"
        let record = try decode(note(properties))
        #expect(record.fields["literal"] == .string("first\n---\nlast"))
        #expect(record.fields["folded"] == .string("first second\nnext\n"))
        #expect(record.fields["kept"] == .string("a\n\n"))
    }

    @Test
    func unknownStructuredNodesSurviveRoundTrip() throws {
        let raw = " &custom\n  nested: {key: [one, two]}\n  other: !custom value\n"
        let record = try decode(note("plugin:" + raw + "title: Example\n"))
        #expect(record.fields["plugin"] == .raw(raw))
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        #expect(try ObsidianVaultCodec.decode(files).records[id]?.fields["plugin"] == .raw(raw))
    }

    @Test
    func anchoredUnknownPropertiesKeepOriginalOrderAfterManagedEdit() throws {
        let anchor = " &shared\n  nested: {key: [one, two]}\n"
        let alias = " *shared\n"
        var record = try decode(note("z_defaults:" + anchor + "title: Before\na_copy:" + alias))
        let originalOrder = [
            "leadstone_id", "leadstone_type", "leadstone_version", "z_defaults", "title", "a_copy"
        ]
        #expect(record.propertyOrder == originalOrder)
        record.fields["title"] = .string("After")
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        let restored = try #require(ObsidianVaultCodec.decode(files).records[id])
        #expect(restored.propertyOrder == originalOrder + ["aliases"])
        #expect(restored.fields["z_defaults"] == .raw(anchor))
        #expect(restored.fields["a_copy"] == .raw(alias))
        #expect(restored.fields["title"] == .string("After"))
        let source = try String(decoding: #require(files[record.path]), as: UTF8.self)
        #expect(source.contains("z_defaults:" + anchor + "title: \"After\"\na_copy:" + alias))
    }

    @Test(arguments: [[], ["z_defaults"], ["z_defaults", "a_copy", "a_copy"]])
    func incompleteOrDuplicateRawPropertyOrderFailsSafely(_ order: [String]) throws {
        var record = try decode(note("z_defaults: &shared {value: 1}\na_copy: *shared\n"))
        record.propertyOrder = order
        #expect(throws: VaultError.self) {
            try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        }
    }

    @Test
    func removedAndNewPropertyOrderingIsDeterministic() throws {
        let fields: [String: VaultValue] = ["z": .number(1), "b": .number(2), "a": .number(3)]
        #expect(try VaultFrontmatter.encode(fields) == "a: 3\nb: 2\nz: 1\n")
        #expect(try VaultFrontmatter.encode(fields, propertyOrder: ["deleted", "z"]) == "z: 1\na: 3\nb: 2\n")
    }

    @Test(arguments: [">+", ">", ">-"], ["", "\n", "  \n", "\n\n"])
    func foldedBlockTrailingBreaksFollowChomping(_ header: String, _ ending: String) throws {
        let keptBreaks = 1 + ending.filter { $0 == "\n" }.count
        let breaks = header == ">+" ? keptBreaks : (header == ">" ? 1 : 0)
        let expected = VaultValue.string("first second" + String(repeating: "\n", count: breaks))
        for following in ["", "next: value\n"] {
            for newline in ["\n", "\r\n"] {
                let properties = "folded: \(header)\n  first\n  second\n" + ending + following
                let record = try decode(note(properties, newline: newline))
                #expect(record.fields["folded"] == expected)
                let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
                #expect(try ObsidianVaultCodec.decode(files).records[id]?.fields["folded"] == expected)
            }
        }
    }

    @Test
    func foldedWhitespaceAndMoreIndentedParagraphsArePreserved() throws {
        let properties = "folded: >+\n\n  ordinary\n\n    indented\n\n  ordinary\n    \n  end\n\n"
        let expected = "\nordinary\n\n  indented\n\nordinary\n  \nend\n\n"
        #expect(try decode(note(properties)).fields["folded"] == .string(expected))
        #expect(try decode(note("folded: >+\n  \n  \n")).fields["folded"] == .string("\n\n"))
        #expect(try decode(note("folded: >\n  \n  \n")).fields["folded"] == .string(""))
        #expect(try decode(note("folded: >-\n  \n  \n")).fields["folded"] == .string(""))
        #expect(throws: VaultError.self) { try decode(note("folded: >\n    \n  text\n")) }
    }

    @Test
    func unicodeAndControlEscapesRoundTrip() throws {
        let text = "Quotation \" and \\ and \u{1} and 雪\nnext"
        let record = VaultRecord(id: id, kind: .aspiration, fields: ["title": .string(text)])
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [id: record]))
        #expect(try ObsidianVaultCodec.decode(files).records[id]?.fields["title"] == .string(text))
        #expect(try decode(note("title: \"\\x41\\u0042\\U0001D11E\"\n")).fields["title"] == .string("AB\u{1D11E}"))
    }

    @Test(arguments: [
        "title: first\ntitle: second\n", "leadstone_type: project\n", "leadstone_id: nope\n",
        "title: \"unclosed\n", "title: \"bad\\q\"\n", "aliases: [a,,b]\n"
    ])
    func malformedManagedPropertiesAbort(_ properties: String) {
        #expect(throws: VaultError.self) { try decode(note(properties)) }
    }

    @Test(arguments: [
        "---\nleadstone_id: nope\n---\n",
        "---\nleadstone_type: aspiration\n",
        "---\nleadstone_type: unknown\nleadstone_version: 1\n---\n",
        "---oops\nleadstone_type: aspiration\n---\n",
        "---\nleadstone_type aspiration\n---\n"
    ])
    func invalidManagedHeadersAreNotIgnored(_ source: String) {
        #expect(throws: VaultError.self) { try ObsidianVaultCodec.decode(["note.md": Data(source.utf8)]) }
    }

    @Test
    func unsupportedVersionAbortsWholeGraph() {
        let future = String(decoding: note(), as: UTF8.self)
            .replacingOccurrences(of: "leadstone_version: 1", with: "leadstone_version: 2")
        #expect(throws: VaultError.self) {
            try ObsidianVaultCodec.decode(["valid.md": note(), "future.md": Data(future.utf8)])
        }
    }

    @Test
    func ordinaryNotesDoNotEnterManagedGraph() throws {
        let files = [
            "ordinary.md": Data("---\nunrelated: [invalid\n---\nprose".utf8),
            "README.md": Data("Notes without frontmatter".utf8)
        ]
        #expect(try ObsidianVaultCodec.decode(files).records.isEmpty)
    }

    @Test
    func duplicateRecordIdentitiesAndPathsFail() {
        #expect(throws: VaultError.self) { try ObsidianVaultCodec.decode(["a.md": note(), "b.md": note()]) }
        let secondID = UUID()
        let first = VaultRecord(id: id, kind: .aspiration, path: "same.md")
        let second = VaultRecord(id: secondID, kind: .aspiration, path: "same.md")
        #expect(throws: VaultError.self) {
            try ObsidianVaultCodec.encode(VaultGraph(records: [id: first, secondID: second]))
        }
    }

    @Test(arguments: ["../note.md", "/note.md", "a//note.md", "a/./note.md", "a\\note.md", "a\0.md"])
    func unsafePathsAreRejected(_ path: String) {
        #expect(throws: VaultError.self) { try ObsidianVaultCodec.decode([path: note()]) }
        let record = VaultRecord(id: id, kind: .aspiration, path: path)
        #expect(throws: VaultError.self) { try ObsidianVaultCodec.encode(VaultGraph(records: [id: record])) }
    }

    @Test
    func attachmentsAreManagedOnlyWhenReferenced() throws {
        let photo = Data([0, 1, 2, 255])
        let files = [
            "note.md": note("cover: '[[Attachments/cover.png]]'\n"),
            "Attachments/cover.png": photo,
            "Attachments/unrelated.png": Data([7])
        ]
        let graph = try ObsidianVaultCodec.decode(files)
        #expect(graph.attachments == ["Attachments/cover.png": photo])
        let encoded = try ObsidianVaultCodec.encode(graph)
        #expect(encoded["Attachments/cover.png"] == photo)
        #expect(encoded["Attachments/unrelated.png"] == nil)
    }

    @Test
    func nonFiniteNumbersCannotBeWritten() {
        let record = VaultRecord(id: id, kind: .session, fields: ["value": .number(.infinity)])
        #expect(throws: VaultError.self) { try ObsidianVaultCodec.encode(VaultGraph(records: [id: record])) }
    }

    @Test
    func multilineFlowListsAndCommentsRemainEditable() throws {
        let properties = "aliases: [\n  \"one # not a comment\", # comment\n  two,\n]\n"
        let record = try decode(note(properties))
        #expect(record.fields["aliases"] == .array([.string("one # not a comment"), .string("two")]))
    }

    @Test
    func quotedReservedKeysAndDocumentEndAreRecognized() throws {
        let source = """
        \u{FEFF}---
        "leadstone_id": "\(id.uuidString)"
        'leadstone_type': aspiration
        leadstone_version: 1
        ...
        No newline at end
        """
        #expect(try decode(Data(source.utf8)).body == "No newline at end")
    }

    @Test
    func managedNotesMustBeValidUTF8() {
        var invalid = note(body: "text")
        invalid.append(255)
        #expect(throws: VaultError.self) { try decode(invalid) }
    }

    @Test
    func oversizedFrontmatterFailsRatherThanPartiallyDecoding() {
        let data = note("plugin: " + String(repeating: "x", count: 1_048_576) + "\n")
        #expect(throws: VaultError.self) { try decode(data) }
    }
}
