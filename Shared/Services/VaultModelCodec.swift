import Foundation

struct VaultModels {
    var aspirations: [Aspiration] = []
    var metrics: [Metric] = []
    var projects: [Project] = []
    var sessions: [Session] = []
    var principles: [Principle] = []
    var intentions: [Intention] = []
    var checkIns: [AspirationCheckIn] = []
    var moments: [Moment] = []
    var photos: [MomentPhoto] = []

    var all: [any VaultModel] {
        var result: [any VaultModel] = aspirations
        result.append(contentsOf: metrics)
        result.append(contentsOf: projects)
        result.append(contentsOf: sessions)
        result.append(contentsOf: principles)
        result.append(contentsOf: intentions)
        result.append(contentsOf: checkIns)
        result.append(contentsOf: moments)
        result.append(contentsOf: photos)
        return result
    }

    mutating func append(_ model: any VaultModel) {
        switch model {
        case let value as Aspiration: aspirations.append(value)
        case let value as Metric: metrics.append(value)
        case let value as Project: projects.append(value)
        case let value as Session: sessions.append(value)
        case let value as Principle: principles.append(value)
        case let value as Intention: intentions.append(value)
        case let value as AspirationCheckIn: checkIns.append(value)
        case let value as Moment: moments.append(value)
        case let value as MomentPhoto: photos.append(value)
        default: break
        }
    }
}

enum VaultModelCodec {
    static func export(_ models: VaultModels) throws -> VaultGraph {
        let objects = models.all
        for model in objects where model.stableID == nil {
            model.stableID = UUID()
        }
        var graph = VaultGraph()
        for model in objects {
            var record = model.vaultRecord()
            guard graph.records[record.id] == nil else { throw VaultError.invalid("Duplicate model identity") }
            try VaultModelRelations.encode(model, record: &record, graph: &graph)
            graph.records[record.id] = record
        }
        try VaultModelValidation.validate(models)
        return graph
    }

    static func validate(_ graph: VaultGraph) throws {
        _ = try materialize(graph)
    }

    static func materialize(_ graph: VaultGraph) throws -> VaultModels {
        var models = VaultModels()
        var paths = Set<String>()
        for (id, record) in graph.records {
            guard id == record.id, paths.insert(record.path).inserted else {
                throw VaultError.invalid("Duplicate path or inconsistent identity")
            }
            let model = make(record.kind)
            model.stableID = id
            try model.applyVaultFields(record)
            if let aliases = record.fields["aliases"] {
                _ = try [String].decodeVault(aliases)
            }
            models.append(model)
        }
        try VaultModelRelations.apply(graph, to: models)
        try VaultModelValidation.validate(models)
        return models
    }

    /// Validates before touching existing objects; returning only desired objects makes deletions explicit.
    /// A persistence adapter must provide rollback if its subsequent save fails.
    static func apply(_ graph: VaultGraph, to existing: VaultModels) throws -> VaultModels {
        let staged = try materialize(graph)
        return try reconcile(graph, staged: staged, existing: existing)
    }

    static func reconcile(_ graph: VaultGraph, staged: VaultModels, existing: VaultModels) throws -> VaultModels {
        var indexed: [UUID: any VaultModel] = [:]
        for model in existing.all {
            guard let id = model.stableID else { throw VaultError.invalid("Snapshot must backfill identities first") }
            guard indexed.updateValue(model, forKey: id) == nil else {
                throw VaultError.invalid("Duplicate existing identity")
            }
            if let record = graph.records[id], record.kind != type(of: model).vaultKind {
                throw VaultError.invalid("An existing identity cannot change type")
            }
            try preserveLocalCapabilities(model, incoming: graph.records[id])
        }
        var desired = VaultModels()
        for fresh in staged.all {
            guard let id = fresh.stableID, let record = graph.records[id] else { continue }
            let model = indexed[id] ?? fresh
            try model.applyVaultFields(record)
            desired.append(model)
        }
        VaultModelRelations.detach(existing)
        try VaultModelRelations.apply(graph, to: desired)
        return desired
    }

    private static func preserveLocalCapabilities(_ model: any VaultModel, incoming: VaultRecord?) throws {
        guard let metric = model as? Metric, metric.isHealthLinked, let incoming else { return }
        guard incoming.fields["measurement_type"] == metric.measurementType.vaultValue else {
            throw VaultError.invalid("Disconnect the local Health link before changing this metric’s measurement type.")
        }
    }

    private static func make(_ kind: VaultKind) -> any VaultModel {
        switch kind {
        case .aspiration: Aspiration.emptyVaultModel()
        case .metric: Metric.emptyVaultModel()
        case .project: Project.emptyVaultModel()
        case .session: Session.emptyVaultModel()
        case .principle: Principle.emptyVaultModel()
        case .intention: Intention.emptyVaultModel()
        case .checkIn: AspirationCheckIn.emptyVaultModel()
        case .moment: Moment.emptyVaultModel()
        case .photo: MomentPhoto.emptyVaultModel()
        }
    }
}
