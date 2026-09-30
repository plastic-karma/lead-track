import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The fixed-width composition rendered into the shareable week image: the
/// week's title and range, the headline stats, the combined pulse, and one
/// compact row per metric. Rendered in light mode at a fixed width so the
/// export looks the same from either appearance.
struct WeekShareView: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WeekShareHeader(formattedRange: review.formattedRange)
            WeekShareHero(text: review.heroText, caption: review.heroCaption())
            WeekBarsView(
                values: review.sessionSeries,
                labels: WeekBarsView.weekdayLabels(
                    from: review.start, count: WeeklyReview.periodDays
                )
            )
            .frame(height: 72)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(review.metricWeeks) { week in
                    WeekShareMetricRow(
                        icon: week.icon, name: week.name, colorName: week.colorName, change: week.change,
                        totalText: ValueFormatter.format(week.total, type: week.measurementType, unit: week.unit)
                    )
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Theme.cardBackground)
    }
}

// MARK: - Pieces

private struct WeekShareHeader: View {
    let formattedRange: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Weekly Review")
                .font(.title3.bold())
            Spacer()
            Text(formattedRange)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeekShareHero: View {
    let text: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .numeralStyle(.value)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeekShareMetricRow: View {
    let icon: String
    let name: String
    let colorName: String?
    let change: WeeklyReview.WeekChange
    let totalText: String
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.chipFill))
            Text(name)
                .font(.subheadline)
            Spacer()
            changeGlyph
            Text(totalText)
                .numeralStyle(.stat)
        }
    }

    @ViewBuilder
    private var changeGlyph: some View {
        switch change {
        case let .up(ratio):
            glyphLabel("arrow.up.right", percent(ratio))
        case let .down(ratio):
            glyphLabel("arrow.down.right", percent(ratio))
        case .flat, .noBaseline:
            EmptyView()
        }
    }

    private func glyphLabel(
        _ symbol: String,
        _ text: String
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MetricColor.color(named: colorName))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ ratio: Double) -> String {
        abs(ratio)
            .formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero).locale(locale))
    }
}

// MARK: - Export

/// A weekly review export that renders the share view to a PNG when the
/// share sheet asks for the data.
struct WeekImageExport: Transferable {
    let review: WeeklyReview

    enum ExportError: Error {
        case renderFailed
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            try await export.pngData()
        }
    }

    @MainActor
    private func pngData() throws -> Data {
        let renderer = ImageRenderer(
            content: WeekShareView(review: review)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            throw ExportError.renderFailed
        }
        return data
    }
}
