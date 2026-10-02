import Foundation

struct VaultSyncPlan {
    var changes: [VaultFileChange]
    var files: [String: VaultRemoteFile]

    init(graph: VaultGraph, remoteGraph: VaultGraph, snapshot: VaultRemoteSnapshot) throws {
        var encoded = try ObsidianVaultCodec.encode(graph)
        for record in graph.records.values where record == remoteGraph.records[record.id] {
            encoded[record.path] = snapshot.files[record.path]?.data ?? encoded[record.path]
        }
        let owned = Set(remoteGraph.records.values.map(\.path)).union(remoteGraph.attachments.keys)
        let deleted = owned.subtracting(encoded.keys)
        for (path, content) in ObsidianVaultCodec.bases() where snapshot.files[path] == nil {
            encoded[path] = content
        }
        try Self.validateDestinations(encoded, owned: owned, deleted: deleted, snapshot: snapshot)
        var changes = deleted.sorted().map { VaultFileChange(path: $0, data: nil) }
        var files = snapshot.files
        for path in deleted {
            files[path] = nil
        }
        for path in encoded.keys.sorted() {
            guard let data = encoded[path], data != snapshot.files[path]?.data else { continue }
            changes.append(VaultFileChange(path: path, data: data))
            files[path] = VaultRemoteFile(sha: "", data: data)
        }
        self.changes = changes
        self.files = files
    }

    private static func validateDestinations(
        _ encoded: [String: Data], owned: Set<String>, deleted: Set<String>, snapshot: VaultRemoteSnapshot
    ) throws {
        var names: [String: String] = [:]
        for path in snapshot.files.keys where !deleted.contains(path) {
            names[path.lowercased()] = path
        }
        for (path, data) in encoded {
            try VaultConfiguration.validatePath(path)
            if let existing = snapshot.files[path], !owned.contains(path), existing.data != data {
                throw VaultError.invalid("Sync would overwrite an unrelated vault file: \(path).")
            }
            if let existing = names[path.lowercased()], existing != path {
                throw VaultError.invalid("Vault filenames differ only in letter case: \(existing), \(path).")
            }
            names[path.lowercased()] = path
        }
    }
}
