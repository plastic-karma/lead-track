import SwiftData
import SwiftUI

/// The Week tab, laid out like Today one timescale up: a header strip whose
/// weekly-goal dial and day-by-day flame graph sit beside the headline number,
/// then the metrics grouped into one compact card per aspiration — each folded
/// to its header by default for a calmer, more focused screen, tap to expand
/// its weeks with the quiet ones dimmed at the foot — then the goal seasons
/// due, and the resting aspirations closing the screen as one centered line.
/// Chevrons on the header strip browse earlier weeks; the metric rows drill
/// into their screens.
///
/// Formerly a notification-triggered sheet; it now anchors the middle
/// timescale of the app's three tabs (day / week / lifetime), and the review
/// notification simply switches to this tab. Hosted in `ContentView`'s
/// navigation stack, so the shared drill-in destinations apply.
struct WeeklyReviewView: View {
    /// The metrics themselves — grouped by aspiration into the compact cards
    /// that fill the tab (see `WeeklyReview.metricGroups`).
    @Query(sort: \Metric.createdAt) var metrics: [Metric]
    /// The aspirations the metric groups sort under, in the app's canonical
    /// creation order.
    @Query(sort: \Aspiration.createdAt) var aspirations: [Aspiration]
    /// Feeds the aspiration partition so a wholly quiet aspiration still reads
    /// as resting rather than active.
    @Query(sort: \Intention.createdAt) var intentions: [Intention]
    /// This week's alignment pulses — part of the same partition input.
    @Query(sort: \AspirationCheckIn.createdAt) var checkIns: [AspirationCheckIn]
    /// Every kept moment, windowed per aspiration into the reviewed week (see
    /// `WeeklyReview.build`). Empty until the feature is used — additive.
    @Query(sort: \Moment.occurredAt) var moments: [Moment]
    @State private var showingSettings = false
    @State private var weeksBack = 0
    /// The aspiration group cards the user has expanded from their default
    /// folded state — per-card, transient, never persisted, like the Today
    /// tab's cluster stubs. Empty (the default) means every card is folded to
    /// its header line for a calmer, more focused screen.
    @State private var expandedGroups: Set<String> = []
    /// The goal-settings route shared by measure-health insights and season
    /// adjustments — hoisted here so it works with or without goal seasons due.
    @State var goalSettingsRoute: GoalSettingsRoute?
    /// The metric whose goal season a Retire tap is confirming, if any.
    @State var retiringSeasonMetric: Metric?

    var body: some View {
        let review = WeeklyReview.build(
            metrics: metrics, aspirations: aspirations, intentions: intentions,
            checkIns: checkIns, moments: moments, weeksBack: weeksBack
        )
        return content(review)
            .background(Theme.washedScreen)
            .navigationTitle("Week")
            .toolbar { toolbarItems(review) }
            .sheet(isPresented: $showingSettings) {
                WeeklyReviewSettingsView()
            }
            .sheet(item: $goalSettingsRoute) { route in
                GoalSettingsView(metric: route.metric, prefillWeeklyGoal: route.prefillWeekly)
            }
    }

    @ViewBuilder
    private func content(_ review: WeeklyReview) -> some View {
        if metrics.unarchived.isEmpty {
            emptyState
        } else {
            reviewScroll(review)
        }
    }

    @ToolbarContentBuilder
    private func toolbarItems(_ review: WeeklyReview) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !review.metricWeeks.isEmpty {
                ShareLink(
                    item: WeekImageExport(review: review),
                    preview: SharePreview("Weekly Review")
                )
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "bell")
            }
            .accessibilityLabel("Weekly Review Notification")
        }
    }
}

// MARK: - Layout

extension WeeklyReviewView {
    private func reviewScroll(_ review: WeeklyReview) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                WeekHeaderStrip(
                    review: review,
                    weeksBack: $weeksBack,
                    goalSegments: WeeklyReview.weeklyGoalSegments(metrics: metrics, weeksBack: weeksBack)
                )
                .padding(.horizontal)
                metricGroupsSection(review)
                oversubscriptionSection(review)
                goalSeasonSection(review)
                restingLine(review.quietAspirations)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
    }

    /// The metrics grouped by the aspiration they serve, each aspiration one
    /// compact card of its metrics' weeks — the Week tab's answer to Today's
    /// clusters. Hidden when nothing logged effort this week (the resting line
    /// and header still speak).
    @ViewBuilder
    private func metricGroupsSection(_ review: WeeklyReview) -> some View {
        let groups = WeeklyReview.metricGroups(
            metrics: metrics, aspirations: aspirations,
            weeks: review.metricWeeks, quiet: review.quietMetrics
        )
        if !groups.isEmpty {
            VStack(spacing: 16) {
                ForEach(groups) { group in
                    groupCard(group)
                }
            }
            .padding(.horizontal)
        }
    }

    private func groupCard(_ group: WeeklyReview.MetricGroup) -> some View {
        MetricLedgerCard(
            header: MetricLedgerCard.Header(
                title: group.title, icon: group.icon, colorName: group.colorName
            ),
            weeks: group.weeks,
            quiet: group.quiet,
            metric: metric(for:),
            collapse: collapseBinding(group.id)
        )
    }

    /// The transient fold flag for one group card, backed by the set above so
    /// sibling cards fold independently. Cards start collapsed, so a card reads
    /// as folded unless the user has expanded it.
    private func collapseBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !expandedGroups.contains(id) },
            set: { collapsed in
                if collapsed {
                    expandedGroups.remove(id)
                } else {
                    expandedGroups.insert(id)
                }
            }
        )
    }

    /// The labeled seam between the review's zones — a hairline rule with the
    /// zone's name, so the metric groups and the goal seasons read as distinct
    /// bands of one screen. Internal (not private) because the goal-seasons
    /// block in its own file opens with the same seam.
    func sectionBreak(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Resting aspirations close the review as one centered breath — names
    /// only; their numbers live on their own screens, the Aspirations tab
    /// the way in.
    @ViewBuilder
    private func restingLine(_ quiet: [WeeklyReview.QuietAspiration]) -> some View {
        if !quiet.isEmpty {
            Text("Resting: \(quiet.map(\.title).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
    }

    /// Shown only when no metrics exist at all; a week without sessions
    /// keeps the header strip so the chevrons can still browse.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Metrics", systemImage: "chart.bar")
        } description: {
            Text("Add a metric and start logging to see weekly insights.")
        }
    }

    /// Maps a ledger row back to its model for navigation. Internal (not
    /// private) for the same reason as the queries above.
    func metric(for id: String) -> Metric? {
        metrics.first { $0.stableID?.uuidString == id }
    }
}
