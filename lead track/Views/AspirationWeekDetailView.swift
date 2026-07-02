import SwiftData
import SwiftUI

/// The route behind an aspiration's review card: the aspiration plus which
/// week the review was showing, so the drill-in renders that same window.
struct AspirationWeekRoute: Hashable {
    let aspiration: Aspiration
    let weeksBack: Int
}

/// The detail behind an aspiration's review card: the week's day-by-day
/// distribution with the busiest day called out, where the effort landed,
/// the live intentions, and the doorway to the aspiration itself. All figures
/// are recomputed fresh on every render — the `AspirationRollup` doctrine.
struct AspirationWeekDetailView: View {
    let aspiration: Aspiration
    let weeksBack: Int
    @State private var showingSetIntention = false

    private var tint: Color {
        aspiration.displayColor
    }

    var body: some View {
        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration, weeksBack: weeksBack)
        return ScrollView {
            VStack(spacing: 16) {
                weekCard(detail)
                sourcesCard(detail.sources)
                intentionsCard
                lifetimeCard(detail.week)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.screenBackground)
        .navigationTitle(aspiration.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSetIntention) {
            IntentionFormView(aspiration: aspiration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - The week

extension AspirationWeekDetailView {
    private func weekCard(_ detail: WeeklyReview.AspirationWeekDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(periodTitle(detail.weeksBack))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formattedRange(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            heroTotals(detail.week)
            WeekBarsView(
                values: detail.week.dailySeries,
                labels: WeekBarsView.weekdayLabels(
                    from: detail.start, count: WeeklyReview.periodDays
                ),
                tint: tint
            )
            .frame(height: 72)
            busiestDayRow(detail)
        }
        .cardSurface()
    }

    @ViewBuilder
    private func heroTotals(_ week: WeeklyReview.AspirationWeek) -> some View {
        if week.totals.isEmpty {
            Text("Quiet this week")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(week.totals.map(\.text).joined(separator: " · "))
                    .numeralStyle(.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(ValueFormatter.sessions(week.sessionCount)) · \(week.activeDays) days active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func busiestDayRow(_ detail: WeeklyReview.AspirationWeekDetail) -> some View {
        if let offset = detail.busiestDayOffset {
            HStack(spacing: 8) {
                Image(systemName: "trophy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(busiestDayText(detail, offset: offset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func busiestDayText(
        _ detail: WeeklyReview.AspirationWeekDetail,
        offset: Int
    ) -> String {
        let weekday = detail.day(at: offset).formatted(.dateTime.weekday(.wide))
        let sessions = Int(detail.week.dailySeries[offset])
        return "Busiest day \(weekday) · \(ValueFormatter.sessions(sessions))"
    }

    private func periodTitle(_ weeksBack: Int) -> String {
        switch weeksBack {
        case 0: "This Week"
        case 1: "Last Week"
        default: "\(weeksBack) Weeks Ago"
        }
    }

    private func formattedRange(_ detail: WeeklyReview.AspirationWeekDetail) -> String {
        "\(detail.start.formatted(.dateTime.month().day()))"
            + " — \(detail.end.formatted(.dateTime.month().day()))"
    }
}

// MARK: - Where it landed

extension AspirationWeekDetailView {
    @ViewBuilder
    private func sourcesCard(_ sources: [WeeklyReview.AspirationWeekSource]) -> some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where it landed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(sources) { source in
                    sourceRow(source)
                }
            }
            .cardSurface()
        }
    }

    private func sourceRow(_ source: WeeklyReview.AspirationWeekSource) -> some View {
        HStack(spacing: 10) {
            Image(systemName: source.isProject ? "folder" : "chart.bar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(source.name)
                .font(.subheadline)
            Spacer()
            Text(source.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Intentions & doorway

extension AspirationWeekDetailView {
    /// The live intention rows — tickable, renamable, releasable — shown only
    /// on the current week: earlier weeks carry no intention machinery.
    @ViewBuilder
    private var intentionsCard: some View {
        if weeksBack == 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Intentions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(openIntentions) { intention in
                    IntentionRowView(intention: intention)
                }
                Button {
                    showingSetIntention = true
                } label: {
                    Label("Set an intention", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
            .cardSurface()
        }
    }

    private var openIntentions: [Intention] {
        aspiration.intentions
            .filter { $0.isOpen && $0.isInCurrentWeek() }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The lifetime headline doubling as the doorway to the aspiration's own
    /// screen — the week is a slice; the whole story lives one tap further.
    private func lifetimeCard(_ week: WeeklyReview.AspirationWeek) -> some View {
        NavigationLink(value: aspiration) {
            HStack(spacing: 12) {
                MetricIcon(systemName: week.icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(week.lifetimeSummary.isEmpty ? "Nothing logged yet" : week.lifetimeSummary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("poured in all-time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
