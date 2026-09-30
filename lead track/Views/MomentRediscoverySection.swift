import SwiftData
import SwiftUI

/// Self-contained for the Week tab and additional reviews. Off and sparse
/// histories render nothing: rediscovery never becomes a prompt to fill a gap.
struct MomentRediscoverySection: View {
    @Query(sort: \Aspiration.createdAt) private var aspirations: [Aspiration]
    @Query(sort: \Metric.createdAt) private var metrics: [Metric]
    @AppStorage(MomentRediscoveryPreferences.enabledKey) private var enabled = false
    @AppStorage(MomentRediscoveryPreferences.stateKey) private var encodedPreferences = Data()

    let period: DateInterval

    private var history: RetrospectiveHistory {
        RetrospectiveHistory(aspirations: aspirations, metrics: metrics)
    }

    private var rediscoveredMoment: Moment? {
        guard enabled,
              let preferences = MomentRediscoveryPreferences.decode(encodedPreferences)
        else { return nil }
        return MomentRediscovery.selected(
            history: history, period: period, preferences: preferences, enabled: enabled
        )
    }

    var body: some View {
        if enabled {
            // Keep a real task host before a pinned Moment exists. An empty
            // Group has no child to receive its task and cannot prepare one.
            VStack(alignment: .leading, spacing: 0) {
                if let moment = rediscoveredMoment {
                    MomentRediscoveryCard(
                        moment: moment,
                        onHide: { updatePreferences { $0.dismiss(period: period) } },
                        onExclude: { updatePreferences { $0.exclude(moment, period: period) } }
                    )
                }
            }
            .task(id: MomentRediscoveryPreferences.periodKey(period)) { prepare() }
        }
    }

    private func prepare() {
        guard enabled else { return }
        updatePreferences {
            MomentRediscovery.prepare(history: history, period: period, preferences: &$0, enabled: enabled)
        }
    }

    private func updatePreferences(_ update: (inout MomentRediscoveryPreferences) -> Void) {
        guard var preferences = MomentRediscoveryPreferences.decode(encodedPreferences) else { return }
        update(&preferences)
        guard let data = preferences.encoded(), data != encodedPreferences else { return }
        encodedPreferences = data
    }
}

private struct MomentRediscoveryCard: View {
    let moment: Moment
    let onHide: () -> Void
    let onExclude: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("From earlier").font(.headline)
                Spacer()
                Button("Hide for this period", systemImage: "xmark", action: onHide)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
            }
            Text("An older Moment you kept under an aspiration in this period.")
                .font(.caption).foregroundStyle(.secondary)
            RetrospectiveMomentRow(moment: moment)
            Button("Don’t rediscover this Moment", systemImage: "eye.slash", action: onExclude)
                .font(.caption)
                .buttonStyle(.plain)
            Text("Hiding or excluding leaves your saved Moment and photos untouched.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.cardShape())
    }
}
