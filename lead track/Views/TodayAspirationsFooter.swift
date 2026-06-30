import SwiftUI

/// The quiet closing line of the Today screen: the aspirations today's effort
/// poured into, as tappable chips that lead up to the "why" above the metrics.
/// This is the one place the daily overview names an aspiration at all.
///
/// Renders nothing until at least one aspiration has been touched today, so a
/// day with no attached effort — or no aspirations yet — leaves Today exactly
/// as it was.
struct TodayAspirationsFooter: View {
    let aspirations: [Aspiration]

    var body: some View {
        let touched = aspirations.filter { AspirationRollup.receivedEffortToday($0) }
        if !touched.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                Text("Poured Into")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                AspirationChipsRow(aspirations: touched)
            }
            .padding(.top, 4)
        }
    }
}
