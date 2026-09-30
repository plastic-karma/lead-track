import SwiftUI

struct AppLockSettingsView: View {
    @AppStorage(
        AppPrivacySettings.appLockEnabledKey,
        store: AppPrivacySettings.store
    )
    private var enabled = false

    var body: some View {
        Form {
            AppLockToggleSection(enabled: $enabled)
            if enabled {
                AppLockGraceSection()
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppLockToggleSection: View {
    @Binding var enabled: Bool

    var body: some View {
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
}

private struct AppLockGraceSection: View {
    @AppStorage(
        AppPrivacySettings.appLockGracePeriodKey,
        store: AppPrivacySettings.store
    )
    private var gracePeriodRaw = AppLockGracePeriod.immediately.rawValue

    var body: some View {
        Section("Lock") {
            Picker("Lock", selection: $gracePeriodRaw) {
                ForEach(AppLockGracePeriod.allCases) { period in
                    Text(period.label).tag(period.rawValue)
                }
            }
        }
    }
}
