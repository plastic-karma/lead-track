import SwiftData
import SwiftUI

/// The metric detail's fold rows, one white card: Activity (the heatmap),
/// History (recent sessions, with the full list behind "Show all"), the
/// Apple Health link for mirrored metrics, and Projects. Each row expands in
/// place, so the page stays a single calm column until asked for more.
struct MetricFoldsCard: View {
    let metric: Metric
    let dailyTotals: [DailyTotal]
    /// Completed sessions without a project, newest first.
    let directSessions: [Session]
    let onMoveSession: (Session) -> Void
    @State private var activityOpen = false
    @State private var historyOpen = false
    @State private var healthOpen = false
    @State private var projectsOpen = false

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
            .background { Theme.cardShape() }
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
        case .activity:
            MetricActivityFold(dailyTotals: dailyTotals, tint: tint, activityOpen: $activityOpen)
        case .history:
            MetricHistoryFold(
                metric: metric, dailyTotals: dailyTotals,
                directSessions: directSessions, onMoveSession: onMoveSession, historyOpen: $historyOpen
            )
        case .health:
            MetricHealthFold(metric: metric, dailyTotals: dailyTotals, healthOpen: $healthOpen)
        case .projects: MetricProjectsFold(metric: metric, projectsOpen: $projectsOpen)
        }
    }
}

private struct MetricFoldHeader<Icon: View>: View {
    let title: String
    let detail: String
    @Binding var isOpen: Bool
    @ViewBuilder var icon: Icon

    var body: some View {
        Button {
            withAnimation(.snappy) { isOpen.toggle() }
        } label: {
            HStack(spacing: 12) {
                icon
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
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isOpen ? "Collapse" : "Expand")
    }
}

private struct MetricFoldSymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Activity

private struct MetricActivityFold: View {
    let dailyTotals: [DailyTotal]
    let tint: Color
    @Binding var activityOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricFoldHeader(
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

private struct MetricHistoryFold: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let dailyTotals: [DailyTotal]
    let directSessions: [Session]
    let onMoveSession: (Session) -> Void
    @Binding var historyOpen: Bool

    private static let historyPreviewLimit = 5
    private var tint: Color {
        metric.displayColor
    }

    var body: some View {
        VStack(spacing: 0) {
            MetricFoldHeader(
                title: "History",
                detail: historyDetail,
                isOpen: $historyOpen
            ) {
                MetricFoldSymbol(name: "clock")
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
            ? "\(min(dailyTotals.count, 14)) days"
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
        session.displayValue(unit: metric.unit)
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
        NavigationLink {
            MetricSessionsListView(metric: metric)
        } label: {
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

private struct MetricHealthFold: View {
    let metric: Metric
    let dailyTotals: [DailyTotal]
    @Binding var healthOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricFoldHeader(
                title: "Apple Health",
                detail: metric.healthSource?.displayName ?? "Apple Health",
                isOpen: $healthOpen
            ) {
                MetricFoldSymbol(name: "heart")
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

private struct MetricProjectsFold: View {
    let metric: Metric
    @Binding var projectsOpen: Bool

    var body: some View {
        VStack(spacing: 0) {
            MetricFoldHeader(
                title: "Projects",
                detail: projectsDetail,
                isOpen: $projectsOpen
            ) {
                MetricFoldSymbol(name: "folder")
            }
            if projectsOpen {
                VStack(spacing: 0) {
                    ForEach(metric.activeProjects + metric.finishedProjects) { project in
                        MetricProjectRow(project: project, tint: metric.displayColor)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var projectsDetail: String {
        var parts: [String] = []
        let active = metric.projects.count { $0.status == .active }
        let finished = metric.projects.count { $0.status == .finished }
        if active > 0 { parts.append("\(active) active") }
        if finished > 0 { parts.append("\(finished) finished") }
        return parts.joined(separator: " · ")
    }
}
