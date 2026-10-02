import Foundation

/// A lost acknowledgment does not prove a push failed. If Git has moved since
/// the attempted target, require a choice rather than resurrecting remote deletes.
struct VaultUncertainPublication {
    let baseline: VaultGraph
    let target: VaultGraph
    let resolutions: [String: VaultResolution]

    func reconcile(_ result: VaultMergeResult, local: VaultGraph, remote: VaultGraph) -> VaultMergeResult {
        var result = result
        for id in Set(baseline.records.keys).union(target.records.keys) {
            guard baseline.records[id] != target.records[id], remote.records[id] != target.records[id],
                  local.records[id] != remote.records[id] else { continue }
            let record = local.records[id] ?? remote.records[id] ?? target.records[id]
            let conflict = VaultConflict(
                id: "publication:\(id)", label: "Unconfirmed upload — \(record?.label ?? "record")",
                local: local.records[id].map(VaultConflictContent.record),
                remote: remote.records[id].map(VaultConflictContent.record)
            )
            result.conflicts.removeAll { $0.id == "record:\(id)" || $0.id.hasPrefix("\(id):") }
            if let choice = choice(for: conflict) {
                result.graph.records[id] = choice == .local ? local.records[id] : remote.records[id]
            } else {
                result.conflicts.append(conflict)
            }
        }
        reconcileAttachments(&result, local: local, remote: remote)
        return result
    }

    private func reconcileAttachments(_ result: inout VaultMergeResult, local: VaultGraph, remote: VaultGraph) {
        for path in Set(baseline.attachments.keys).union(target.attachments.keys) {
            guard baseline.attachments[path] != target.attachments[path],
                  remote.attachments[path] != target.attachments[path],
                  local.attachments[path] != remote.attachments[path] else { continue }
            let conflict = VaultConflict(
                id: "publication-attachment:\(path)", label: "Unconfirmed upload — \(path)",
                local: local.attachments[path].map(VaultConflictContent.attachment),
                remote: remote.attachments[path].map(VaultConflictContent.attachment)
            )
            result.conflicts.removeAll { $0.id == "attachment:\(path)" }
            if let choice = choice(for: conflict) {
                result.graph.attachments[path] = choice == .local ? local.attachments[path] : remote.attachments[path]
            } else {
                result.conflicts.append(conflict)
            }
        }
    }

    private func choice(for conflict: VaultConflict) -> VaultResolution.Choice? {
        guard let resolution = resolutions[conflict.id], resolution.conflict == conflict else { return nil }
        return resolution.choice
    }
}
