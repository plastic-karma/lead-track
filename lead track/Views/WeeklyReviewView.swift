import SwiftData
import SwiftUI

/// The Week tab: one overview card for the whole week, the aspiration lens,
/// the intentions to close and set, then a swipeable page of insights per
/// metric, with the metrics that stayed quiet listed at the end. Chevrons on
/// the overview card browse earlier weeks, and tapping a page drills into
/// that metric's detail screen. Pages snap like the dashboard cards they
/// echo; the dots between them wear each metric's identity color.
///
/// Formerly a notification-triggered sheet; it now anchors the middle
/// timescale of the app's three tabs (day / week / lifetime), and the review
/// notification simply switches to this tab. Hosted in `ContentView`'s
/// navigation stack, so the shared drill-in destinations apply.
struct WeeklyReviewView: View {
    /// Internal (not private, like `aspirations`) so the intentions section in
    /// its own file can pick an identity color for a promoted metric.
    @Query(sort: \Metric.createdAt) var metrics: [Metric]
    /// Internal (not private) so the aspiration section in its own file can read
    /// it to map a card back to its aspiration for navigation.
    @Query(sort: \Aspiration.createdAt) var aspirations: [Aspiration]
    /// Internal so the intentions section can map a closure decision back to
    /// its model.
    @Query(sort: \Intention.createdAt) var intentions: [Intention]
    @Environment(\.modelContext) var modelContext
    @State private var showingSettings = false
    @State private var currentPage: String?
    @State private var weeksBack = 0
    /// The aspiration a new intention is being set under, if any.
    @State var settingIntentionFor: Aspiration?
    /// The goal-settings route an accepted goal promotion opens.
    @State var promotionGoal: PromotionGoalRoute?

    var body: some View {
        let review = WeeklyReview.build(
            metrics: metrics, aspirations: aspirations, intentions: intentions, weeksBack: weeksBack
        )
        return content(review)
            .background(Theme.screenBackground)
            .navigationTitle("Week")
            .toolbar { toolbarItems(review) }
            .sheet(isPresented: $showingSettings) {
                WeeklyReviewSettingsView()
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
                WeekOverviewCard(review: review, weeksBack: $weeksBack)
                    .padding(.horizontal)
                aspirationSection(review)
                intentionsSection(review)
                if review.metricWeeks.isEmpty {
                    emptyWeekCard
                        .padding(.horizontal)
                } else {
                    metricPager(review)
                    if review.metricWeeks.count > 1 {
                        pageDots(review)
                    }
                }
                quietCard(review.quietMetrics)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .onChange(of: weeksBack) {
            currentPage = nil
        }
    }

    /// Shown only when no metrics exist at all; a week without sessions
    /// keeps the overview card so the chevrons can still browse.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Metrics", systemImage: "chart.bar")
        } description: {
            Text("Add a metric and start logging to see weekly insights.")
        }
    }

    private var emptyWeekCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Nothing logged this week")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardSurface(alignment: .center)
    }
}

// MARK: - Metric Pager

extension WeeklyReviewView {
    /// One full-width card per metric; swiping snaps from page to page with
    /// the neighbors peeking in at the edges, and a tap opens the metric.
    private func metricPager(_ review: WeeklyReview) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(review.metricWeeks) { week in
                    page(for: week, in: review)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $currentPage)
        .safeAreaPadding(.horizontal, 16)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func page(
        for week: WeeklyReview.MetricWeek,
        in review: WeeklyReview
    ) -> some View {
        if let metric = metric(for: week.id) {
            NavigationLink(value: metric) {
                MetricWeekCard(week: week, weekStart: review.start)
            }
            .buttonStyle(.plain)
        } else {
            MetricWeekCard(week: week, weekStart: review.start)
        }
    }

    private func metric(for id: String) -> Metric? {
        metrics.first { $0.stableID?.uuidString == id }
    }

    private func pageDots(_ review: WeeklyReview) -> some View {
        HStack(spacing: 6) {
            ForEach(review.metricWeeks) { week in
                Circle()
                    .fill(MetricColor.color(named: week.colorName))
                    .opacity(week.id == currentPageID(review) ? 1 : 0.25)
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.snappy, value: currentPage)
        .accessibilityHidden(true)
    }

    private func currentPageID(_ review: WeeklyReview) -> String? {
        currentPage ?? review.metricWeeks.first?.id
    }
}

// MARK: - Quiet Metrics

extension WeeklyReviewView {
    @ViewBuilder
    private func quietCard(_ quiet: [WeeklyReview.QuietMetric]) -> some View {
        if !quiet.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quiet this week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(quiet) { metric in
                    quietRow(metric)
                }
            }
            .cardSurface()
        }
    }

    @ViewBuilder
    private func quietRow(_ quiet: WeeklyReview.QuietMetric) -> some View {
        if let metric = metric(for: quiet.id) {
            NavigationLink(value: metric) {
                quietRowContent(quiet)
            }
            .buttonStyle(.plain)
        } else {
            quietRowContent(quiet)
        }
    }

    private func quietRowContent(_ metric: WeeklyReview.QuietMetric) -> some View {
        HStack(spacing: 10) {
            Image(systemName: metric.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(metric.name)
                .font(.subheadline)
            Spacer()
            Text("no sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
