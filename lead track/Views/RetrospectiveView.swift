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
            dateControls
            filters
            RetrospectiveNarrativeSections(snapshot: snapshot, period: period)
            effortSection(snapshot.effort)
            if snapshot.isEmpty {
                Text("No saved history matches this period and these filters.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Explore this period")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.washedScreen)
        .onChange(of: aspirationID) { _, _ in
            principleID = nil
            projectID = nil
        }
    }

    private var dateControls: some View {
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

    private var filters: some View {
        Section {
            aspirationPicker
            principlePicker
            projectPicker
        } header: {
            Text("Browse by")
        } footer: {
            Text("Includes set-aside aspirations and archived metrics. Effort follows current attachments. "
                + "A principle shows only explicitly tagged Moments and intentions, not effort or check-ins. "
                + "A project shows its Moments and effort, not intentions or check-ins.")
        }
    }

    private var aspirationPicker: some View {
        Picker("Aspiration", selection: $aspirationID) {
            Text("All aspirations").tag(nil as PersistentIdentifier?)
            ForEach(aspirations) { aspiration in
                Text(aspiration.title + (aspiration.isArchived ? " (set aside)" : ""))
                    .tag(Optional(aspiration.persistentModelID))
            }
        }
    }

    private var principlePicker: some View {
        Picker("Principle", selection: $principleID) {
            Text("All principles").tag(nil as PersistentIdentifier?)
            ForEach(principles.filter { aspirationID == nil || $0.aspiration?.persistentModelID == aspirationID }) {
                Text($0.text).tag(Optional($0.persistentModelID))
            }
        }
    }

    private var projectPicker: some View {
        Picker("Project", selection: $projectID) {
            Text("All projects").tag(nil as PersistentIdentifier?)
            ForEach(projects) { project in
                Text(project.name).tag(Optional(project.persistentModelID))
            }
        }
    }

    private func effortSection(_ effort: [RetrospectiveEffort]) -> some View {
        Section {
            if filter.principle != nil {
                Text("Sessions do not carry principle tags, so no effort is attributed to this principle.")
                    .foregroundStyle(.secondary)
            }
            ForEach(effort) { row in
                DisclosureGroup {
                    ForEach(row.sessions) { session in
                        sessionRow(session, unit: row.metric?.unit)
                    }
                } label: {
                    LabeledContent(row.name, value: row.text)
                }
            }
        } header: {
            Text("Recorded effort")
        } footer: {
            Text("Completed sessions only. Values stay in each metric’s own unit; no unlike units are added together.")
        }
    }

    private func sessionRow(_ session: Session, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            LabeledContent(
                session.startedAt.formatted(date: .abbreviated, time: .shortened),
                value: session.displayValue(unit: unit)
            )
            if let project = session.project {
                Text(project.name).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
