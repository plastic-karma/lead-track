import Foundation
import Testing
@testable import lead_track

struct VaultMergeTests {
    @Test
    func mergesIndependentDescriptionAndTitleEdits() throws {
        let original = note()
        var local = original
        local.fields["title"] = .string("New title")
        var remote = original
        remote.body = "Edited in Obsidian.\n"
        var merger = VaultMerge()
        let result = try merger.merge(base: graph(original), local: graph(local), remote: graph(remote))
        #expect(result.conflicts.isEmpty)
        #expect(result.graph.records[original.id]?.body == remote.body)
        #expect(result.graph.records[original.id]?.fields["title"] == local.fields["title"])
    }

    @Test
    func firstConnectionUnionsUnrelatedRecords() throws {
        let local = note()
        let remote = note()
        var merger = VaultMerge()
        let result = try merger.merge(base: VaultGraph(), local: graph(local), remote: graph(remote))
        #expect(result.graph.records[local.id] == local)
        #expect(result.graph.records[remote.id] == remote)
        #expect(result.conflicts.isEmpty)
    }

    @Test
    func deletionCompetesWithAnOfflineEdit() throws {
        let original = note()
        var local = original
        local.body = "Not yet pushed."
        var merger = VaultMerge()
        let result = try merger.merge(base: graph(original), local: graph(local), remote: VaultGraph())
        let conflict = try #require(result.conflicts.first)
        #expect(conflict.local == .record(local))
        #expect(conflict.remote == nil)
        var resolving = VaultMerge(resolutions: [conflict.id: VaultResolution(conflict: conflict, choice: .remote)])
        let resolved = try resolving.merge(base: graph(original), local: graph(local), remote: VaultGraph())
        #expect(resolved.conflicts.isEmpty)
        #expect(resolved.graph.records[original.id] == nil)
    }

    @Test
    func staleResolutionCannotDiscardANewerRemoteEdit() throws {
        let original = note()
        var local = original
        local.body = "Offline edit"
        var remote = original
        remote.body = "Obsidian edit"
        var merger = VaultMerge()
        let result = try merger.merge(base: graph(original), local: graph(local), remote: graph(remote))
        let conflict = try #require(result.conflicts.first)
        var resolving = VaultMerge(resolutions: [conflict.id: VaultResolution(conflict: conflict, choice: .local)])
        remote.body = "A newer Obsidian edit"
        let resolved = try resolving.merge(base: graph(original), local: graph(local), remote: graph(remote))
        #expect(resolved.conflicts.first?.remote == .text(remote.body))
    }

    @Test
    func remoteDeletionRemovesAnUnchangedLocalRecord() throws {
        let original = note()
        var merger = VaultMerge()
        let result = try merger.merge(base: graph(original), local: graph(original), remote: VaultGraph())
        #expect(result.graph.records[original.id] == nil)
        #expect(result.conflicts.isEmpty)
    }

    @Test
    func localProjectionPreservesVaultMetadataAndRenames() {
        let projected = note()
        var baseline = projected
        baseline.path = "Aspirations/My renamed aspiration.md"
        baseline.fields["custom"] = .raw("\n  nested: user-owned")
        baseline.body = "Unnormalized Markdown.\n\n"
        var snapshot = projected
        snapshot.fields["title"] = .string("Changed in app")
        let result = VaultLocalChanges.overlay(
            snapshot: graph(snapshot),
            base: graph(baseline),
            projection: graph(projected)
        )
        #expect(result.records[baseline.id]?.path == baseline.path)
        #expect(result.records[baseline.id]?.fields["custom"] == baseline.fields["custom"])
        #expect(result.records[baseline.id]?.body == baseline.body)
        #expect(result.records[baseline.id]?.fields["title"] == snapshot.fields["title"])
    }

    @Test
    func competingPhotoEditsRequireAChoice() throws {
        let path = "Attachments/photo.jpg"
        var merger = VaultMerge()
        let result = try merger.merge(
            base: VaultGraph(attachments: [path: Data([1])]),
            local: VaultGraph(attachments: [path: Data([2])]),
            remote: VaultGraph(attachments: [path: Data([3])])
        )
        #expect(result.conflicts.first?.local == .attachment(Data([2])))
        #expect(result.conflicts.first?.remote == .attachment(Data([3])))
    }

    private func note() -> VaultRecord {
        VaultRecord(
            id: UUID(),
            kind: .aspiration,
            fields: ["title": .string("Read widely")],
            body: "Original description"
        )
    }

    private func graph(_ record: VaultRecord) -> VaultGraph {
        VaultGraph(records: [record.id: record])
    }
}
