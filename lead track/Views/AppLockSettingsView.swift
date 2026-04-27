import SwiftUI

struct AppLockSettingsView: View {
    @AppStorage(AppLockService.enabledKey)
    private var enabled = false
    @AppStorage(AppLockService.gracePeriodKey)
    private var gracePeriodRaw = AppLockGracePeriod.immediately.rawValue

    var body: some View {
        Form {
            toggleSection
            if enabled {
                graceSection
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var toggleSection: some View {
        Section {
            Toggle("Require Face ID", isOn: $enabled)
        } footer: {
            Text(
                """
                Face ID (or your device passcode) is required to open \
                LeadStone. Live Activities and notifications continue to \
                work while the app is locked.
                """
            )
        }
    }

    private var graceSection: some View {
        Section("Lock") {
            Picker("Lock", selection: $gracePeriodRaw) {
                ForEach(AppLockGracePeriod.allCases) { period in
                    Text(period.label).tag(period.rawValue)
                }
            }
        }
    }
}
