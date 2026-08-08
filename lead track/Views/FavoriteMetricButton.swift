import SwiftData
import SwiftUI
import WidgetKit

/// The one-tap collection action in metric detail. It saves immediately so
/// the shared Control Center picker does not wait for SwiftData autosave.
struct FavoriteMetricButton: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric

    var body: some View {
        Button(action: toggleFavorite) {
            Label(
                metric.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: metric.isFavorite ? "star.fill" : "star"
            )
        }
        .accessibilityIdentifier("Favorite Metric")
    }

    private func toggleFavorite() {
        let previousValue = metric.isFavorite
        metric.isFavorite.toggle()
        do {
            try modelContext.save()
            ControlCenter.shared.reloadControls(
                ofKind: WidgetKinds.favoriteMetricControl
            )
        } catch {
            metric.isFavorite = previousValue
            StoreLog.error("Favorite save failed: \(error)")
        }
    }
}
