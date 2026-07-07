import SwiftData
import SwiftUI

/// The Week tab: the week's headline folded into a bare header strip, then
/// the aspiration cards at center stage — each carrying its week, its
/// intentions, and one calm action row of chips (moment · intention ·
/// check-in), each foldable to its header line — then every metric as one
/// row of a single ledger card, the quiet ones dimmed at its foot, with the
/// resting aspirations closing the screen as one centered line. Chevrons on
/// the header strip browse earlier weeks; the aspiration cards and ledger
/// rows drill into their screens.
///
/// Formerly a notification-triggered sheet; it now anchors the middle
/// timescale of the app's three tabs (day / week / lifetime), and the review
/// notification simply switches to this tab. Hosted in `ContentView`'s
/// navigation stack, so the shared drill-in destinations apply.
struct WeeklyReviewView: View {
    /// Internal (not private, like `aspirations`) so the intention decisions
    /// in their own file can pick an identity color for a promoted metric.
    @Query(sort: \Metric.createdAt) var metrics: [Metric]
    /// Internal (not private) so the aspiration section in its own file can read
    /// it to map a card back to its aspiration for navigation.
    @Query(sort: \Aspiration.createdAt) var aspirations: [Aspiration]
    /// Internal so the intention decisions can map a closure made on a card
    /// back to its model.
    @Query(sort: \Intention.createdAt) var intentions: [Intention]
    /// This week's alignment pulses, so cards offer the check-in only where
    /// it is still open.
    @Query(sort: \AspirationCheckIn.createdAt) var checkIns: [AspirationCheckIn]
    /// Every kept moment, windowed per aspiration into the reviewed week (see
    /// `WeeklyReview.build`). Empty until the feature is used — additive.
    @Query(sort: \Moment.occurredAt) var moments: [Moment]
    @Environment(\.modelContext) var modelContext
    @State private var showingSettings = false
    @State private var weeksBack = 0
    /// The aspiration a new intention is being set under, if any.
    @State var settingIntentionFor: Aspiration?
    /// The aspiration a new moment is being kept under, if any.
    @State var keepingMomentFor: Aspiration?
    /// The aspiration cards folded to their header line — per-card, transient,
    /// never persisted, like the Today tab's stub expansion. Internal so the
    /// aspiration section in its own file can drive it.
    @State var collapsedAspirations: Set<String> = []
    /// The goal-settings route shared by promotions, measure-health insights,
    /// and season adjustments — hoisted here so it works with or without
    /// aspirations on stage.
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
        if metrics.isEmpty {
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
                WeekHeaderStrip(review: review, weeksBack: $weeksBack)
                    .padding(.horizontal)
                aspirationSection(review)
                goalSeasonSection(review)
                sectionBreak("Metrics")
                    .padding(.horizontal)
                MetricLedgerCard(weeks: review.metricWeeks, quiet: review.quietMetrics) {
                    metric(for: $0)
                }
                .padding(.horizontal)
                restingLine(review.quietAspirations)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
    }

    /// The labeled seam between the review's zones — a hairline rule with the
    /// zone's name, so the week summary, the aspirations, and the metric
    /// ledger read as distinct bands of one screen. Internal (not private)
    /// because the aspiration section in its own file opens with the same seam.
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
