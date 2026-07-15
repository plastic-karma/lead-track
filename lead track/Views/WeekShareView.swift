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
            header
            heroLine
            WeekBarsView(
                values: review.sessionSeries,
                labels: WeekBarsView.weekdayLabels(
                    from: review.start, count: WeeklyReview.periodDays
                )
            )
            .frame(height: 72)
            metricRows
        }
        .padding(24)
        .frame(width: 400)
        .background(Theme.cardBackground)
    }
}

// MARK: - Pieces

extension WeekShareView {
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Weekly Review")
                .font(.title3.bold())
            Spacer()
            Text(formattedRange)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedRange: String {
        review.formattedRange
    }

    private var heroLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heroText)
                .numeralStyle(.value)
            Text(heroCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var heroText: String {
        review.heroText
    }

    private var heroCaption: String {
        review.heroCaption()
    }

    private var metricRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(review.metricWeeks) { week in
                metricRow(week)
            }
        }
    }

    private func metricRow(_ week: WeeklyReview.MetricWeek) -> some View {
        HStack(spacing: 10) {
            Image(systemName: week.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.chipFill))
            Text(week.name)
                .font(.subheadline)
            Spacer()
            changeGlyph(week)
            Text(
                ValueFormatter.format(
                    week.total,
                    type: week.measurementType,
                    unit: week.unit
                )
            )
            .numeralStyle(.stat)
        }
    }

    @ViewBuilder
    private func changeGlyph(_ week: WeeklyReview.MetricWeek) -> some View {
        switch week.change {
        case let .up(ratio):
            glyphLabel("arrow.up.right", percent(ratio), tint: week)
        case let .down(ratio):
            glyphLabel("arrow.down.right", percent(ratio), tint: week)
        case .flat, .noBaseline:
            EmptyView()
        }
    }

    private func glyphLabel(
        _ symbol: String,
        _ text: String,
        tint week: WeeklyReview.MetricWeek
    ) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MetricColor.color(named: week.colorName))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ ratio: Double) -> String {
        "\(Int((abs(ratio) * 100).rounded()))%"
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
