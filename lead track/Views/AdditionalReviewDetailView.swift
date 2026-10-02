import SwiftData
import SwiftUI

struct AdditionalReviewDetailView: View {
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @AppStorage(AdditionalReviewStore.key) private var encodedReviews = Data()
    @State private var periodsBack = 0

    let reviewID: UUID

    private var review: AdditionalReview? {
        AdditionalReviewStore.decode(encodedReviews).first { $0.id == reviewID }
    }

    var body: some View {
        Group {
            if let review {
                report(review)
            } else {
                ContentUnavailableView(
                    "Review Removed",
                    systemImage: "calendar.badge.minus",
                    description: Text("This additional review is no longer configured.")
                )
            }
        }
        .background(Theme.washedScreen)
        .navigationTitle(review?.name ?? "Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func report(_ review: AdditionalReview) -> some View {
        let summary = AdditionalReviewSummary.build(
            review: review,
            metrics: metrics,
            periodsBack: periodsBack
        )
        return ScrollView {
            VStack(spacing: 18) {
                AdditionalReviewPeriodNavigator(period: summary.period, periodsBack: $periodsBack)
                NavigationLink {
                    RetrospectiveView(period: summary.period)
                } label: {
                    Label("Explore this period", systemImage: "book")
                }
                MomentRediscoverySection(period: summary.period)
                AdditionalReviewStats(
                    totalDuration: summary.totalDuration, sessionCount: summary.sessionCount,
                    activeDays: summary.activeDays
                )
                AdditionalReviewMetricTotals(metrics: summary.metrics)
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AdditionalReviewPeriodNavigator: View {
    let period: DateInterval
    @Binding var periodsBack: Int

    var body: some View {
        HStack {
            Button { periodsBack += 1 } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Earlier period")
            Spacer()
            VStack(spacing: 2) {
                Text("Completed Period")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(periodDescription(period))
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button { periodsBack = max(0, periodsBack - 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(periodsBack == 0)
            .accessibilityLabel("Later period")
        }
    }

    private func periodDescription(_ period: DateInterval) -> String {
        let calendar = Calendar.current
        let finalDay = calendar.date(byAdding: .day, value: -1, to: period.end) ?? period.end
        return "\(period.start.formatted(date: .abbreviated, time: .omitted)) – "
            + finalDay.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct AdditionalReviewStats: View {
    let totalDuration: TimeInterval
    let sessionCount: Int
    let activeDays: Int

    var body: some View {
        HStack(spacing: 10) {
            stat(
                title: "Tracked",
                value: DurationFormatter.format(totalDuration)
            )
            stat(title: "Sessions", value: sessionCount.formatted())
            stat(title: "Active Days", value: activeDays.formatted())
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardShape())
    }
}

private struct AdditionalReviewMetricTotals: View {
    let metrics: [AdditionalReviewSummary.MetricTotal]

    var body: some View {
        if metrics.isEmpty {
            ContentUnavailableView {
                Label("No Sessions", systemImage: "chart.bar")
            } description: {
                Text("Nothing was recorded during this review period.")
            }
            .padding(.top, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(metrics) { metric in
                    VStack(spacing: 0) {
                        AdditionalReviewMetricRow(metric: metric)
                        if metric.id != metrics.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.cardShape())
        }
    }
}

private struct AdditionalReviewMetricRow: View {
    let metric: AdditionalReviewSummary.MetricTotal

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: metric.icon)
                .foregroundStyle(MetricColor.color(named: metric.colorName))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.subheadline)
                Text("\(ValueFormatter.sessions(metric.sessionCount)) · \(ValueFormatter.days(metric.activeDays))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(ValueFormatter.format(
                metric.total,
                type: metric.measurementType,
                unit: metric.unit
            ))
            .numeralStyle(.stat)
            .lineLimit(1)
        }
        .padding(.vertical, 11)
    }
}
