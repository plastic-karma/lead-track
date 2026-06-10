import SwiftData
import SwiftUI

/// The weekly review: one overview card for the whole week, then a swipeable
/// page of insights per metric, with the metrics that stayed quiet listed at
/// the end. Pages snap like the dashboard cards they echo; the dots between
/// them wear each metric's identity color.
struct WeeklyReviewView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var currentPage: String?

    var body: some View {
        NavigationStack {
            content
                .background(Theme.screenBackground)
                .navigationTitle("Weekly Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .sheet(isPresented: $showingSettings) {
                    WeeklyReviewSettingsView()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let review = WeeklyReview.build(metrics: metrics)
        if review.metricWeeks.isEmpty {
            emptyState
        } else {
            reviewScroll(review)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
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
                WeekOverviewCard(review: review)
                    .padding(.horizontal)
                metricPager(review)
                if review.metricWeeks.count > 1 {
                    pageDots(review)
                }
                quietCard(review.quietMetrics)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                "No Sessions This Week",
                systemImage: "calendar.badge.exclamationmark"
            )
        } description: {
            Text("Log a session and your weekly insights will appear here.")
        }
    }
}

// MARK: - Metric Pager

extension WeeklyReviewView {
    /// One full-width card per metric; swiping snaps from page to page with
    /// the neighbors peeking in at the edges.
    private func metricPager(_ review: WeeklyReview) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(review.metricWeeks) { week in
                    MetricWeekCard(week: week, weekStart: review.start)
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

    private func quietRow(_ metric: WeeklyReview.QuietMetric) -> some View {
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
    }
}
