import SwiftData
import SwiftUI

/// Read-only period browsing. It never starts a review, closes an intention,
/// edits a check-in, or offers a new reflection cadence.
struct RetrospectiveView: View {
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Query(sort: \Project.startedAt) private var projects: [Project]
    @Query(sort: \Principle.createdAt) private var principles: [Principle]
    @State private var start: Date
    @State private var end: Date
    @State private var aspirationID: PersistentIdentifier?
    @State private var principleID: PersistentIdentifier?
    @State private var projectID: PersistentIdentifier?

    init(period: DateInterval, aspiration: Aspiration? = nil) {
        _start = State(initialValue: period.start)
        _end = State(initialValue: period.end)
        _aspirationID = State(initialValue: aspiration?.persistentModelID)
    }

    private var period: DateInterval {
        DateInterval(start: start, end: end)
    }

    private var filter: RetrospectiveFilter {
        RetrospectiveFilter(
            aspiration: aspirations.first { $0.persistentModelID == aspirationID },
            principle: principles.first { $0.persistentModelID == principleID },
            project: projects.first { $0.persistentModelID == projectID }
        )
    }

    var body: some View {
        let snapshot = RetrospectiveReader.read(
            history: RetrospectiveHistory(aspirations: aspirations, metrics: metrics, projects: projects),
            period: period, filter: filter
        )
        List {
            RetrospectiveDateControls(start: $start, end: $end)
            RetrospectiveFilters(
                aspirations: aspirations, principles: principles, projects: projects,
                aspirationID: $aspirationID, principleID: $principleID, projectID: $projectID
            )
            RetrospectiveNarrativeSections(
                moments: snapshot.moments, intentions: snapshot.intentions,
                checkIns: snapshot.checkIns, period: period
            )
            RetrospectiveEffortSection(effort: snapshot.effort, filtersPrinciple: filter.principle != nil)
            if snapshot.isEmpty {
                Text("No saved history matches this period and these filters.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .navigationTitle("Explore this period")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.washedScreen)
        .onChange(of: aspirationID) { _, _ in
            principleID = nil
            projectID = nil
        }
    }
}

private struct RetrospectiveDateControls: View {
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        Section {
            DatePicker("From", selection: $start, in: ...end)
            DatePicker("Until", selection: $end, in: start...)
        } header: {
            Text("Period")
        } footer: {
            Text("From is included; Until is not. Moments use when they happened; effort uses session start. "
                + "Intentions use their saved week-start or closure date; "
                + "check-in notes use their saved week-start date.")
        }
    }
}

private struct RetrospectiveFilters: View {
    let aspirations: [Aspiration]
    let principles: [Principle]
    let projects: [Project]
    @Binding var aspirationID: PersistentIdentifier?
    @Binding var principleID: PersistentIdentifier?
    @Binding var projectID: PersistentIdentifier?

    var body: some View {
        Section {
            RetrospectiveAspirationPicker(aspirations: aspirations, selection: $aspirationID)
            RetrospectivePrinciplePicker(principles: principles, aspirationID: aspirationID, selection: $principleID)
            RetrospectiveProjectPicker(projects: projects, selection: $projectID)
        } header: {
            Text("Browse by")
        } footer: {
            Text("Includes set-aside aspirations and archived metrics. Effort follows current attachments. "
                + "A principle shows only explicitly tagged Moments and intentions, not effort or check-ins. "
                + "A project shows its Moments and effort, not intentions or check-ins.")
        }
    }
}

private struct RetrospectiveAspirationPicker: View {
    let aspirations: [Aspiration]
    @Binding var selection: PersistentIdentifier?

    var body: some View {
        Picker("Aspiration", selection: $selection) {
            Text("All aspirations").tag(nil as PersistentIdentifier?)
            ForEach(aspirations) { aspiration in
                Text(aspiration.title + (aspiration.isArchived ? " (set aside)" : ""))
                    .tag(Optional(aspiration.persistentModelID))
            }
        }
    }
}

private struct RetrospectivePrinciplePicker: View {
    let principles: [Principle]
    let aspirationID: PersistentIdentifier?
    @Binding var selection: PersistentIdentifier?

    var body: some View {
        let choices = principles.filter { aspirationID == nil || $0.aspiration?.persistentModelID == aspirationID }
        Picker("Principle", selection: $selection) {
            Text("All principles").tag(nil as PersistentIdentifier?)
            ForEach(choices) {
                Text($0.text).tag(Optional($0.persistentModelID))
            }
        }
    }
}

private struct RetrospectiveProjectPicker: View {
    let projects: [Project]
    @Binding var selection: PersistentIdentifier?

    var body: some View {
        Picker("Project", selection: $selection) {
            Text("All projects").tag(nil as PersistentIdentifier?)
            ForEach(projects) { project in
                Text(project.name).tag(Optional(project.persistentModelID))
            }
        }
    }
}

private struct RetrospectiveEffortSection: View {
    let effort: [RetrospectiveEffort]
    let filtersPrinciple: Bool

    var body: some View {
        Section {
            if filtersPrinciple {
                Text("Sessions do not carry principle tags, so no effort is attributed to this principle.")
                    .foregroundStyle(.secondary)
            }
            ForEach(effort) { row in
                RetrospectiveEffortGroup(
                    name: row.name, text: row.text, sessions: row.sessions, unit: row.metric?.unit
                )
            }
        } header: {
            Text("Recorded effort")
        } footer: {
            Text("Completed sessions only. Values stay in each metric’s own unit; no unlike units are added together.")
        }
    }
}

private struct RetrospectiveEffortGroup: View {
    let name: String
    let text: String
    let sessions: [Session]
    let unit: String?

    var body: some View {
        DisclosureGroup {
            ForEach(sessions) { session in
                RetrospectiveSessionRow(session: session, unit: unit)
            }
        } label: {
            LabeledContent(name, value: text)
                .monospacedDigit()
        }
    }
}

private struct RetrospectiveSessionRow: View {
    let session: Session
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            LabeledContent(
                session.startedAt.formatted(date: .abbreviated, time: .shortened),
                value: session.displayValue(unit: unit)
            )
            .monospacedDigit()
            if let project = session.project {
                Text(project.name).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
