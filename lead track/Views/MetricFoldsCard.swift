import SwiftData
import SwiftUI

/// The metric detail's fold rows, one white card: Activity (the heatmap),
/// History (recent sessions, with the full list behind "Show all"), the
/// Apple Health link for mirrored metrics, and Projects. Each row expands in
/// place, so the page stays a single calm column until asked for more.
struct MetricFoldsCard: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let dailyTotals: [DailyTotal]
    /// Completed sessions without a project, newest first.
    let directSessions: [Session]
    let onMoveSession: (Session) -> Void
    @State private var activityOpen = false
    @State private var historyOpen = false
    @State private var healthOpen = false
    @State private var projectsOpen = false

    private static let historyPreviewLimit = 5

    var body: some View {
        if !visibleFolds.isEmpty {
            VStack(spacing: 0) {
                ForEach(visibleFolds, id: \.self) { fold in
                    if fold != visibleFolds.first {
                        Divider().padding(.leading, 46)
                    }
                    foldView(fold)
                }
            }
            .padding(.vertical, 4)
            .background(Theme.cardShape())
        }
    }

    private var tint: Color {
        metric.displayColor
    }
}

// MARK: - Folds

extension MetricFoldsCard {
    private enum Fold: Hashable {
        case activity
        case history
        case health
        case projects
    }

    private var visibleFolds: [Fold] {
        var folds: [Fold] = []
        if !dailyTotals.isEmpty { folds.append(.activity) }
        if metric.isHealthLinked || !directSessions.isEmpty { folds.append(.history) }
        if metric.isHealthLinked { folds.append(.health) }
        if !metric.projects.isEmpty { folds.append(.projects) }
        return folds
    }

    @ViewBuilder
    private func foldView(_ fold: Fold) -> some View {
        switch fold {
        case .activity: activityFold
        case .history: historyFold
        case .health: healthFold
        case .projects: projectsFold
        }
    }

    private func foldRow(
        title: String,
        detail: String,
        isOpen: Binding<Bool>,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        Button {
            withAnimation(.snappy) { isOpen.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 12) {
                icon()
                    .frame(width: 22)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isOpen.wrappedValue ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen.wrappedValue ? "Collapse" : "Expand")
    }

    private func sfIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Activity

extension MetricFoldsCard {
    private var activityFold: some View {
        VStack(spacing: 0) {
            foldRow(
                title: "Activity",
                detail: "\(CalendarHeatmapView.weekCount) weeks",
                isOpen: $activityOpen
            ) {
                activityGlyph
            }
            if activityOpen {
                CalendarHeatmapView(dailyTotals: dailyTotals, tint: tint)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    /// The heatmap in miniature: four squares in the metric's color.
    private var activityGlyph: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                glyphSquare(0.8)
                glyphSquare(0.35)
            }
            GridRow {
                glyphSquare(0.5)
                glyphSquare(0.95)
            }
        }
    }

    private func glyphSquare(_ opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(tint.opacity(opacity))
            .frame(width: 7.5, height: 7.5)
    }
}

// MARK: - History

extension MetricFoldsCard {
    private var historyFold: some View {
        VStack(spacing: 0) {
            foldRow(
                title: "History",
                detail: historyDetail,
                isOpen: $historyOpen
            ) {
                sfIcon("clock")
            }
            if historyOpen {
                VStack(spacing: 0) {
                    historyContent
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var historyDetail: String {
        metric.isHealthLinked
            ? "\(HealthHistoryRows.days(from: dailyTotals).count) days"
            : ValueFormatter.sessions(directSessions.count)
    }

    @ViewBuilder
    private var historyContent: some View {
        if metric.isHealthLinked {
            HealthHistoryRows(metric: metric, dailyTotals: dailyTotals)
        } else {
            ForEach(directSessions.prefix(Self.historyPreviewLimit)) { session in
                sessionRow(session)
            }
            if directSessions.count > Self.historyPreviewLimit {
                showAllLink
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            Text(sessionLabel(session))
                .font(.subheadline)
            Spacer()
            Text(sessionValue(session))
                .numeralStyle(.stat)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .contextMenu { sessionMenu(session) }
    }

    private func sessionLabel(_ session: Session) -> String {
        let day = SessionDayGrouping.label(for: session.startedAt)
        let time = session.startedAt.formatted(date: .omitted, time: .shortened)
        return "\(day) \(time)"
    }

    private func sessionValue(_ session: Session) -> String {
        if metric.measurementType == .binary { return "Done" }
        if let count = session.value {
            return ValueFormatter.format(count, type: .count, unit: metric.unit)
        }
        return DurationFormatter.format(session.duration)
    }

    @ViewBuilder
    private func sessionMenu(_ session: Session) -> some View {
        if !metric.projects.isEmpty {
            Button("Move to Project", systemImage: "folder") {
                onMoveSession(session)
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation { modelContext.delete(session) }
        }
    }

    private var showAllLink: some View {
        NavigationLink(destination: MetricSessionsListView(metric: metric)) {
            Text("Show all \(directSessions.count) →")
                .font(.footnote.weight(.medium))
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Apple Health

extension MetricFoldsCard {
    private var healthFold: some View {
        VStack(spacing: 0) {
            foldRow(
                title: "Apple Health",
                detail: metric.healthSource?.displayName ?? "Apple Health",
                isOpen: $healthOpen
            ) {
                sfIcon("heart")
            }
            if healthOpen {
                HealthFoldContent(
                    metric: metric,
                    hasRecentData: SessionStatistics.windowedTotal(days: 30, from: dailyTotals) > 0
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }
}

// MARK: - Projects

extension MetricFoldsCard {
    private var projectsFold: some View {
        VStack(spacing: 0) {
            foldRow(
                title: "Projects",
                detail: projectsDetail,
                isOpen: $projectsOpen
            ) {
                sfIcon("folder")
            }
            if projectsOpen {
                VStack(spacing: 0) {
                    ForEach(metric.activeProjects + metric.finishedProjects) { project in
                        MetricProjectRow(project: project, tint: tint)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var projectsDetail: String {
        var parts: [String] = []
        let active = metric.activeProjects.count
        let finished = metric.finishedProjects.count
        if active > 0 { parts.append("\(active) active") }
        if finished > 0 { parts.append("\(finished) finished") }
        return parts.joined(separator: " · ")
    }
}
