import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultLinkAttachmentTests {
    private let folder = "Notes/My Vault"
    private let bytes = Data([1, 2, 3])
    private let replacement = Data([4, 5, 6])

    @Test
    func newPointAfterObsidianRenamePublishesActualDestination() throws {
        let metric = Metric(name: "Reading")
        let initial = try VaultModelCodec.export(VaultModels(metrics: [metric]))
        let metricID = try #require(metric.stableID)
        var remote = initial
        remote.records[metricID]?.path = "Metrics/Reading practice.md"
        remote.records[metricID]?.fields["custom"] = .raw(" {source: Obsidian}\n")
        remote.records[metricID]?.propertyOrder = ["custom"]
        let imported = try VaultModelCodec.materialize(remote)
        let projection = try VaultModelCodec.export(imported)
        let point = Session(metric: imported.metrics[0], startedAt: Date(timeIntervalSince1970: 10))
        let snapshot = try VaultModelCodec.export(VaultModels(metrics: imported.metrics, sessions: [point]))
        let pointID = try #require(point.stableID)
        let overlaid = VaultLocalChanges.overlay(snapshot: snapshot, base: remote, projection: projection)
        let published = try VaultPublicationLinks.rewrite(overlaid, folder: folder)
        let link = "[[Notes/My Vault/Metrics/Reading practice.md]]"
        #expect(published.records[pointID]?.fields["metric"] == .string(link))
        #expect(published.records[metricID]?.fields["custom"] == remote.records[metricID]?.fields["custom"])
        let files = try ObsidianVaultCodec.encode(published)
        let path = try #require(published.records[pointID]?.path)
        #expect(try String(decoding: #require(files[path]), as: UTF8.self).contains(link))
        #expect(try VaultModelCodec.materialize(published).sessions[0].metric?.stableID == metricID)
    }

    @Test
    func rewrittenRelationsKeepLabelsAndUserPaths() throws {
        let target = VaultRecord(id: UUID(), kind: .metric, path: "Metrics/Read.md")
        let aspiration = VaultRecord(id: UUID(), kind: .aspiration, fields: [
            "metrics": .array([.string("[[\(target.id.uuidString)|Reading label]]")]),
            "custom": .string("[[\(target.id.uuidString)]]")
        ])
        let intention = VaultRecord(id: UUID(), kind: .intention, fields: [
            "metric": .string("[[Metrics/Read|My user label]]")
        ])
        let generated = VaultRecord(id: UUID(), kind: .intention, fields: [
            "metric": VaultModelLinks.linkID(target.id)
        ])
        let graph = VaultGraph(records: [
            target.id: target, aspiration.id: aspiration, intention.id: intention, generated.id: generated
        ])
        let rewritten = try VaultPublicationLinks.rewrite(graph, folder: folder)
        #expect(rewritten.records[aspiration.id]?.fields["metrics"] ==
            .array([.string("[[Notes/My Vault/Metrics/Read.md|Reading label]]")]))
        #expect(rewritten.records[aspiration.id]?.fields["custom"] == aspiration.fields["custom"])
        #expect(rewritten.records[intention.id] == intention)
        #expect(rewritten.records[generated.id]?.fields["metric"] == .string("[[Notes/My Vault/Metrics/Read.md]]"))
    }

    @Test
    func duplicateUUIDFilenamesRequireQualifiedLinks() throws {
        let metric = VaultRecord(id: UUID(), kind: .metric)
        let duplicate = VaultRecord(
            id: UUID(),
            kind: .project,
            path: "Projects/\(metric.id.uuidString.lowercased()).md"
        )
        let point = VaultRecord(id: UUID(), kind: .session, fields: ["metric": VaultModelLinks.linkID(metric.id)])
        let graph = VaultGraph(records: [metric.id: metric, duplicate.id: duplicate, point.id: point])
        let rewritten = try VaultPublicationLinks.rewrite(graph, folder: folder)
        #expect(rewritten.records[point.id]?.fields["metric"] == .string("[[\(folder)/\(metric.path)]]"))
    }

    @Test
    func removingSharedCoverKeepsOtherOwnerAndMetadata() {
        let fixture = sharedCovers()
        var snapshot = fixture.projection
        snapshot.records[fixture.first]?.fields["cover"] = .null
        snapshot.attachments[canonical(fixture.first)] = nil
        let result = VaultLocalChanges.overlay(snapshot: snapshot, base: fixture.base, projection: fixture.projection)
        #expect(result.attachments == fixture.base.attachments)
        #expect(result.records[fixture.first]?.fields["cover"] == .null)
        #expect(result.records[fixture.second] == fixture.base.records[fixture.second])
        #expect(result.records[fixture.first]?.fields["custom"] == fixture.base.records[fixture.first]?
            .fields["custom"])
    }

    @Test
    func replacingSharedCoverWritesOnlyChangedOwnersFile() throws {
        let fixture = sharedCovers()
        var snapshot = fixture.projection
        snapshot.attachments[canonical(fixture.first)] = replacement
        let result = VaultLocalChanges.overlay(snapshot: snapshot, base: fixture.base, projection: fixture.projection)
        let first = try #require(result.records[fixture.first])
        let path = try #require(try VaultAttachmentLinks.path(first.fields["cover"], graph: result))
        #expect(path == canonical(fixture.first))
        #expect(result.attachments[path] == replacement)
        #expect(result.attachments["Attachments/shared.bin"] == bytes)
        #expect(result.records[fixture.second] == fixture.base.records[fixture.second])
        #expect(first.path == fixture.base.records[fixture.first]?.path)
        #expect(first.fields["custom"] == fixture.base.records[fixture.first]?.fields["custom"])
    }

    @Test
    func replacingAlreadyCanonicalSharedCoverAvoidsOverwrite() throws {
        var fixture = sharedCovers()
        let shared = canonical(fixture.first)
        fixture.base.attachments = [shared: bytes]
        for id in [fixture.first, fixture.second] {
            fixture.base.records[id]?.fields["cover"] = .string("[[\(shared)]]")
        }
        var snapshot = fixture.projection
        snapshot.attachments[shared] = replacement
        let result = VaultLocalChanges.overlay(snapshot: snapshot, base: fixture.base, projection: fixture.projection)
        let first = try #require(result.records[fixture.first])
        let path = try #require(try VaultAttachmentLinks.path(first.fields["cover"], graph: result))
        #expect(path != shared)
        #expect(path.contains(fixture.first.uuidString.lowercased()))
        #expect(result.attachments[path] == replacement)
        #expect(result.attachments[shared] == bytes)
        #expect(result.records[fixture.second]?.fields["cover"] == .string("[[\(shared)]]"))
    }

    @Test
    func removedOwnersKeepBodyAndCustomPropertyImages() {
        let references: [(String, VaultValue)] = [
            ("![[shared.bin|200]]", .null),
            ("![Cover](Notes/My%20Vault/Attachments/shared.bin)", .null),
            ("![Cover][image]\n[image]: <Notes/My Vault/Attachments/shared.bin>\n", .null),
            ("", .raw("nested:\n  image: '[[shared.bin]]'\n"))
        ]
        for (reference, custom) in references {
            var fixture = sharedCovers()
            fixture.base.records[fixture.second] = nil
            fixture.projection.records[fixture.second] = nil
            fixture.projection.attachments[canonical(fixture.second)] = nil
            fixture.base.records[fixture.first]?.body = reference
            fixture.base.records[fixture.first]?.fields["custom"] = custom
            var snapshot = fixture.projection
            snapshot.records[fixture.first]?.fields["cover"] = .null
            snapshot.attachments = [:]
            let result = VaultLocalChanges.overlay(
                snapshot: snapshot,
                base: fixture.base,
                projection: fixture.projection
            )
            #expect(result.attachments["Attachments/shared.bin"] == bytes)
            #expect(result.records[fixture.first]?.body == reference)
            #expect(result.records[fixture.first]?.fields["custom"] == fixture.base.records[fixture.first]?
                .fields["custom"])
        }
    }

    @Test
    func lastOwnerRemovalDeletesOnlyUnreferencedManagedAsset() {
        let fixture = sharedCovers()
        var snapshot = fixture.projection
        snapshot.records = [:]
        snapshot.attachments = [:]
        var base = fixture.base
        base.attachments["Attachments/unowned.bin"] = replacement
        let result = VaultLocalChanges.overlay(snapshot: snapshot, base: base, projection: fixture.projection)
        #expect(result.attachments == ["Attachments/unowned.bin": replacement])
    }

    @Test
    func importsUniqueShortRelativeAndVaultRootAttachments() throws {
        for target in ["shared.bin", "Attachments/shared.bin", "Notes/My Vault/Attachments/shared.bin"] {
            let record = VaultRecord(id: UUID(), kind: .aspiration, fields: ["cover": .string("[[\(target)|Cover]]")])
            let files = try ObsidianVaultCodec.encode(VaultGraph(records: [record.id: record], attachments: [
                "Attachments/shared.bin": bytes, "Attachments/ignored.bin": replacement
            ]))
            let decoded = try ObsidianVaultCodec.decode(files, folder: folder)
            #expect(decoded.attachments == ["Attachments/shared.bin": bytes])
            #expect(decoded.records[record.id]?.fields == record.fields)
            let links = VaultModelLinks(graph: decoded, models: VaultModels())
            #expect(try links.attachment(record, "cover") == bytes)
        }
    }

    @Test
    func unsafeOutsideAndAmbiguousAttachmentsFail() throws {
        for target in [
            "../Attachments/shared.bin",
            "Elsewhere/Attachments/shared.bin",
            "/Attachments/shared.bin",
            "Attachments/../shared.bin",
            "shared.bin"
        ] {
            let record = VaultRecord(id: UUID(), kind: .aspiration, fields: ["cover": .string("[[\(target)]]")])
            let files = try ObsidianVaultCodec.encode(VaultGraph(records: [record.id: record], attachments: [
                "Attachments/shared.bin": bytes, "Attachments/nested/shared.bin": replacement
            ]))
            #expect(throws: (any Error).self) { try ObsidianVaultCodec.decode(files, folder: folder) }
        }
    }

    @Test
    func bodyAndCustomImagesAreDiscoveredWithoutCoverOwnership() throws {
        let record = VaultRecord(id: UUID(), kind: .metric, fields: [
            "custom": .raw("\n  nested:\n    image: '[[Notes/My Vault/Attachments/shared.bin|Custom]]'\n")
        ], body: "![Diagram](Attachments/diagram.png)\n", propertyOrder: ["custom"])
        let files = try ObsidianVaultCodec.encode(VaultGraph(records: [record.id: record], attachments: [
            "Attachments/shared.bin": bytes, "Attachments/diagram.png": replacement
        ]))
        let decoded = try ObsidianVaultCodec.decode(files, folder: folder)
        #expect(decoded.attachments.count == 2)
        #expect(decoded.records[record.id]?.body == record.body)
        #expect(decoded.records[record.id]?.fields["custom"] == record.fields["custom"])
    }

    @Test
    func optionalListsAcceptMissingOrNullButRequiredLinksStayStrict() throws {
        let aspiration = Aspiration(title: "Read")
        var graph = try VaultModelCodec.export(VaultModels(aspirations: [aspiration]))
        let id = try #require(aspiration.stableID)
        graph.records[id]?.fields["metrics"] = nil
        graph.records[id]?.fields["projects"] = .null
        let imported = try VaultModelCodec.materialize(graph)
        #expect(imported.aspirations[0].metrics.isEmpty)
        #expect(imported.aspirations[0].projects.isEmpty)
        let metric = Metric(name: "Reading")
        let point = Session(metric: metric, startedAt: Date(timeIntervalSince1970: 10))
        var required = try VaultModelCodec.export(VaultModels(metrics: [metric], sessions: [point]))
        let pointID = try #require(point.stableID)
        required.records[pointID]?.fields["metric"] = .null
        #expect(throws: (any Error).self) { try VaultModelCodec.materialize(required) }
    }

    private func canonical(_ id: UUID) -> String {
        "Attachments/\(id.uuidString.lowercased())-cover.bin"
    }

    private func sharedCovers() -> (base: VaultGraph, projection: VaultGraph, first: UUID, second: UUID) {
        let first = UUID(), second = UUID()
        let records = [first, second].map { id in
            VaultRecord(id: id, kind: .aspiration, fields: [
                "cover": .string("[[Notes/My Vault/Attachments/shared.bin|Shared cover]]"),
                "custom": .raw("{source: Obsidian, reviewed: true}")
            ], path: "Aspirations/\(id == first ? "First renamed" : "Second renamed").md")
        }
        var base = VaultGraph(
            records: Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }),
            attachments: ["Attachments/shared.bin": bytes]
        )
        base.attachmentRoot = folder
        var projection = VaultGraph()
        for record in records {
            var projected = VaultRecord(id: record.id, kind: .aspiration)
            projected.fields["cover"] = .string("[[\(canonical(record.id))]]")
            projection.records[record.id] = projected
            projection.attachments[canonical(record.id)] = bytes
        }
        return (base, projection, first, second)
    }
}
