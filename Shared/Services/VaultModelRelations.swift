import Foundation

enum VaultModelRelations {
    static func encode(_ model: any VaultModel, record: inout VaultRecord, graph: inout VaultGraph) throws {
        switch model {
        case let value as Aspiration:
            record.fields["metrics"] = try .array(value.metrics.map { try VaultModelLinks.link($0) })
            record.fields["projects"] = try .array(value.projects.map { try VaultModelLinks.link($0) })
            attach(value.imageData, key: "cover", suffix: "-cover", record: &record, graph: &graph)
        case let value as Project:
            record.fields["metric"] = try VaultModelLinks.link(value.metric)
        case let value as Session:
            record.fields["metric"] = try VaultModelLinks.link(value.metric ?? value.project?.metric)
            record.fields["project"] = try VaultModelLinks.link(value.project)
        case let value as Principle:
            record.fields["aspiration"] = try VaultModelLinks.link(value.aspiration)
        case let value as Intention:
            record.fields["aspiration"] = try VaultModelLinks.link(value.aspiration)
            record.fields["metric"] = try VaultModelLinks.link(value.metric)
            record.fields["principle"] = try VaultModelLinks.link(value.principle)
            record.fields["predecessor"] = VaultModelLinks.linkID(value.predecessorID)
        case let value as AspirationCheckIn:
            record.fields["aspiration"] = try VaultModelLinks.link(value.aspiration)
        case let value as Moment:
            record.fields["aspiration"] = try VaultModelLinks.link(value.aspiration)
            record.fields["metric"] = try VaultModelLinks.link(value.metric)
            record.fields["project"] = try VaultModelLinks.link(value.project)
            record.fields["principle"] = try VaultModelLinks.link(value.principle)
        case let value as MomentPhoto:
            record.fields["moment"] = try VaultModelLinks.link(value.moment)
            attach(value.data, key: "file", suffix: "", record: &record, graph: &graph)
        default: break
        }
    }

    private static func attach(
        _ data: Data?,
        key: String,
        suffix: String,
        record: inout VaultRecord,
        graph: inout VaultGraph
    ) {
        guard let data else { record.fields[key] = .null; return }
        let path = "Attachments/\(record.id.uuidString.lowercased())\(suffix).\(VaultModelLinks.imageExtension(data))"
        graph.attachments[path] = data
        record.fields[key] = .string("[[\(path)]]")
    }

    static func apply(_ graph: VaultGraph, to models: VaultModels) throws {
        let links = VaultModelLinks(graph: graph, models: models)
        for model in models.all {
            guard let id = model.stableID, let record = graph.records[id] else {
                throw VaultError.invalid("Missing model identity")
            }
            guard VaultModelLinks.safePath(record.path), record.path.hasSuffix(".md") else {
                throw VaultError.invalid("Invalid record path")
            }
            try applyOwner(model, record: record, links: links)
        }
        rebuildInverses(models)
    }

    private static func applyOwner(_ model: any VaultModel, record: VaultRecord, links: VaultModelLinks) throws {
        switch model {
        case let value as Aspiration:
            value.metrics = try links.many(record, "metrics")
            value.projects = try links.many(record, "projects")
            value.imageData = try links.attachment(record, "cover")
        case let value as Project:
            value.metric = try links.one(record, "metric", required: true)
        case let value as Session:
            value.metric = try links.one(record, "metric", required: true)
            value.project = try links.one(record, "project")
        case let value as Principle:
            value.aspiration = try links.one(record, "aspiration", required: true)
        case let value as Intention:
            try applyIntention(value, record: record, links: links)
        case let value as AspirationCheckIn:
            value.aspiration = try links.one(record, "aspiration", required: true)
        case let value as Moment:
            value.aspiration = try links.one(record, "aspiration", required: true)
            value.metric = try links.one(record, "metric")
            value.project = try links.one(record, "project")
            value.principle = try links.one(record, "principle")
        case let value as MomentPhoto:
            value.moment = try links.one(record, "moment", required: true)
            guard let bytes = try links.attachment(record, "file", required: true) else {
                throw VaultError.invalid("Photo attachment is required")
            }
            value.data = bytes
        default: break
        }
    }

    private static func applyIntention(_ value: Intention, record: VaultRecord, links: VaultModelLinks) throws {
        value.aspiration = try links.one(record, "aspiration", required: true)
        value.metric = try links.one(record, "metric")
        value.principle = try links.one(record, "principle")
        value.predecessorID = nil
        if let predecessor = record.fields["predecessor"], predecessor != .null {
            // Historical renewal IDs survive deletion of their predecessor.
            let target = try VaultModelLinks.target(predecessor)
            if let id = UUID(uuidString: target), links.graph.records[id] == nil {
                value.predecessorID = id
            } else {
                let prior: Intention? = try links.one(record, "predecessor")
                value.predecessorID = prior?.stableID
            }
        }
    }

    /// Clear cascade edges on both sides before deleting anything. Surviving children
    /// are reattached to their desired parents before the persistence adapter deletes.
    static func detach(_ models: VaultModels) {
        for value in models.aspirations {
            value.metrics = []; value.projects = []; value.principles = []
            value.intentions = []; value.checkIns = []; value.moments = []
        }
        for value in models.metrics {
            value.projects = []; value.sessions = []; value.aspirations = []
            value.intentions = []; value.moments = []
        }
        for value in models.projects {
            value.metric = nil; value.sessions = []; value.aspirations = []; value.moments = []
        }
        for value in models.sessions {
            value.metric = nil; value.project = nil
        }
        for value in models.principles {
            value.aspiration = nil; value.intentions = []; value.moments = []
        }
        for value in models.intentions {
            value.aspiration = nil; value.metric = nil; value.principle = nil
        }
        for value in models.checkIns {
            value.aspiration = nil
        }
        for value in models.moments {
            value.aspiration = nil; value.metric = nil; value.project = nil
            value.principle = nil; value.photos = []
        }
        for value in models.photos {
            value.moment = nil
        }
    }

    private static func rebuildInverses(_ models: VaultModels) {
        inverse(models.aspirations, children: models.principles, owner: \.aspiration, array: \.principles)
        inverse(models.aspirations, children: models.intentions, owner: \.aspiration, array: \.intentions)
        inverse(models.aspirations, children: models.checkIns, owner: \.aspiration, array: \.checkIns)
        inverse(models.aspirations, children: models.moments, owner: \.aspiration, array: \.moments)
        inverse(models.metrics, children: models.projects, owner: \.metric, array: \.projects)
        inverse(models.metrics, children: models.sessions, owner: \.metric, array: \.sessions)
        inverse(models.metrics, children: models.intentions, owner: \.metric, array: \.intentions)
        inverse(models.metrics, children: models.moments, owner: \.metric, array: \.moments)
        inverse(models.projects, children: models.sessions, owner: \.project, array: \.sessions)
        inverse(models.projects, children: models.moments, owner: \.project, array: \.moments)
        inverse(models.principles, children: models.intentions, owner: \.principle, array: \.intentions)
        inverse(models.principles, children: models.moments, owner: \.principle, array: \.moments)
        inverse(models.moments, children: models.photos, owner: \.moment, array: \.photos)
        for value in models.moments {
            value.photos.sort { $0.sortIndex < $1.sortIndex }
        }
        rebuildMembership(models)
    }

    private static func inverse<Parent: AnyObject, Child>(
        _ parents: [Parent], children: [Child],
        owner: KeyPath<Child, Parent?>, array: ReferenceWritableKeyPath<Parent, [Child]>
    ) {
        var grouped: [ObjectIdentifier: [Child]] = [:]
        for child in children {
            if let parent = child[keyPath: owner] {
                grouped[ObjectIdentifier(parent), default: []].append(child)
            }
        }
        for parent in parents {
            parent[keyPath: array] = grouped[ObjectIdentifier(parent)] ?? []
        }
    }

    private static func rebuildMembership(_ models: VaultModels) {
        var metrics: [ObjectIdentifier: [Aspiration]] = [:]
        var projects: [ObjectIdentifier: [Aspiration]] = [:]
        for aspiration in models.aspirations {
            for metric in aspiration.metrics {
                metrics[ObjectIdentifier(metric), default: []].append(aspiration)
            }
            for project in aspiration.projects {
                projects[ObjectIdentifier(project), default: []].append(aspiration)
            }
        }
        for metric in models.metrics {
            metric.aspirations = metrics[ObjectIdentifier(metric)] ?? []
        }
        for project in models.projects {
            project.aspirations = projects[ObjectIdentifier(project)] ?? []
        }
    }
}
