import SwiftUI

/// The metric form's Apple Health section for timer metrics: choose whether
/// completed sessions are written back to Health, and as which record —
/// mindful minutes or workout minutes. Off by default.
struct MetricFormHealthExportSection: View {
    @Binding var selection: HealthExportTarget?

    var body: some View {
        Section {
            Picker("Send to Apple Health", selection: $selection) {
                Text("Off").tag(HealthExportTarget?.none)
                ForEach(HealthExportTarget.allCases, id: \.self) { target in
                    Text(target.displayName).tag(HealthExportTarget?.some(target))
                }
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        guard let selection else {
            return "Optionally save each completed session to Apple Health."
        }
        return selection.explanation
            + " LeadStone will ask permission to write only this record type."
            + " Sessions recorded while this is on are sent; older ones stay put."
    }
}
