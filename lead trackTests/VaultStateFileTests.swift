import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultStateFileTests {
    @Test
    func switchingDestinationsRetainsEachReconciliationBaseline() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = "owner/vault@main:LeadStone"
        let second = "owner/vault@archive:LeadStone"
        let firstFile = VaultStateFile.forDestination(first, in: directory)
        let secondFile = VaultStateFile.forDestination(second, in: directory)
        let record = VaultRecord(id: UUID(), kind: .aspiration, body: "Already acknowledged")
        var state = VaultSyncState(destination: first)
        state.baseline.records[record.id] = record
        try firstFile.save(state)
        try secondFile.save(VaultSyncState(destination: second))
        #expect(try firstFile.load(destination: first).baseline.records[record.id] == record)
        #expect(try secondFile.load(destination: second).baseline.records.isEmpty)
        #expect(throws: VaultError.self) { try firstFile.load(destination: second) }
    }

    @Test
    func corruptJournalNeverBecomesAnEmptyFirstSync() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = VaultStateFile.forDestination("owner/repo@main:folder", in: directory)
        try file.save(VaultSyncState(destination: "owner/repo@main:folder"))
        let corrupt = Data("unfinished journal".utf8)
        try corrupt.write(to: file.url)
        #expect(throws: (any Error).self) { try file.load(destination: "owner/repo@main:folder") }
        #expect(try Data(contentsOf: file.url) == corrupt)
    }
}
