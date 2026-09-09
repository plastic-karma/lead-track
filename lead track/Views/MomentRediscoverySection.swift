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
        Group {
            if let moment = rediscoveredMoment {
                card(moment)
            }
        }
        .task(id: MomentRediscoveryPreferences.periodKey(period)) { prepare() }
        .onChange(of: enabled) { _, _ in prepare() }
    }

    private func card(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("From earlier").font(.headline)
                Spacer()
                Button("Hide for this period", systemImage: "xmark") {
                    updatePreferences { $0.dismiss(period: period) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            }
            Text("An older Moment you kept under an aspiration in this period.")
                .font(.caption).foregroundStyle(.secondary)
            RetrospectiveMomentRow(moment: moment)
            Button("Don’t rediscover this Moment", systemImage: "eye.slash") {
                updatePreferences { $0.exclude(moment, period: period) }
            }
            .font(.caption)
            .buttonStyle(.plain)
            Text("Hiding or excluding leaves your saved Moment and photos untouched.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.cardShape())
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
