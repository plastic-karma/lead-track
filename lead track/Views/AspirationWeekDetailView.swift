import SwiftData
import SwiftUI

/// Keeps the reviewed week anchored when opening the aspiration drill-in.
struct AspirationWeekRoute: Hashable {
    let aspiration: Aspiration
    let weeksBack: Int
}

/// A live week slice, with lifetime effort remaining behind the doorway.
struct AspirationWeekDetailView: View {
    let aspiration: Aspiration
    let weeksBack: Int

    var body: some View {
        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration, weeksBack: weeksBack)
        ScrollView {
            VStack(spacing: 16) {
                AspirationWeekSummaryCard(
                    start: detail.start, end: detail.end, weeksBack: detail.weeksBack,
                    values: detail.week.dailySeries,
                    totals: detail.week.totals.map(\.text).joined(separator: " · "),
                    activity: "\(ValueFormatter.sessions(detail.week.sessionCount)) · \(ValueFormatter.days(detail.week.activeDays)) active",
                    busiestDay: busiestDayText(detail), tint: aspiration.displayColor
                )
                AspirationWeekSourcesCard(sources: detail.sources)
                if weeksBack == 0 {
                    AspirationWeekIntentionsCard(aspiration: aspiration)
                }
                AspirationWeekDoorway(aspiration: aspiration)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.screenBackground)
        .navigationTitle(aspiration.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func busiestDayText(_ detail: WeeklyReview.AspirationWeekDetail) -> String? {
        guard let offset = detail.busiestDayOffset else { return nil }
        let weekday = detail.day(at: offset).formatted(.dateTime.weekday(.wide))
        let sessions = Int(detail.week.dailySeries[offset])
        return "Busiest day \(weekday) · \(ValueFormatter.sessions(sessions))"
    }
}

private struct AspirationWeekSummaryCard: View {
    let start: Date
    let end: Date
    let weeksBack: Int
    let values: [Double]
    let totals: String
    let activity: String
    let busiestDay: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(periodTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(start.formatted(.dateTime.month().day())) — \(end.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if totals.isEmpty {
                Text("Quiet this week")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(totals)
                        .numeralStyle(.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(activity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            WeekBarsView(
                values: values,
                labels: WeekBarsView.weekdayLabels(from: start, count: WeeklyReview.periodDays),
                tint: tint
            )
            .frame(height: 72)
            if let busiestDay {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(busiestDay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardSurface()
    }

    private var periodTitle: String {
        switch weeksBack {
        case 0: "This Week"
        case 1: "Last Week"
        default: "\(weeksBack) Weeks Ago"
        }
    }
}

private struct AspirationWeekSourcesCard: View {
    let sources: [WeeklyReview.AspirationWeekSource]

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where it landed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(sources) { source in
                    AspirationWeekSourceRow(
                        name: source.name, isProject: source.isProject, text: source.text
                    )
                }
            }
            .cardSurface()
        }
    }
}

private struct AspirationWeekSourceRow: View {
    let name: String
    let isProject: Bool
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isProject ? "folder" : "chart.bar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct AspirationWeekIntentionsCard: View {
    let aspiration: Aspiration
    @State private var showingSetIntention = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intentions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(openIntentions) { intention in
                IntentionRowView(intention: intention)
            }
            if aspiration.isArchived {
                Text("Set aside — existing commitments remain available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button { showingSetIntention = true } label: {
                    Label("Set an intention", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .cardSurface()
        .sheet(isPresented: $showingSetIntention) {
            IntentionFormView(aspiration: aspiration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var openIntentions: [Intention] {
        aspiration.intentions
            .filter { $0.isOpen && $0.isInCurrentWeek() }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

private struct AspirationWeekDoorway: View {
    let aspiration: Aspiration

    var body: some View {
        NavigationLink(value: aspiration) {
            HStack(spacing: 12) {
                MetricIcon(systemName: aspiration.displayIcon, tint: aspiration.displayColor)
                Text(aspiration.isArchived ? "View aspiration · Bring back" : "View aspiration")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
