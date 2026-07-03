import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CompletionAlertSettings.soundKey, store: CompletionAlertSettings.store) private var timerSound = true
    @AppStorage(CompletionAlertSettings.hapticKey, store: CompletionAlertSettings.store) private var timerHaptic = true
    @AppStorage("todayGroupsByAspiration") private var groupsByAspiration = false

    var body: some View {
        NavigationStack {
            List {
                todaySection
                timerCompletionSection
                Section {
                    NavigationLink {
                        AppLockSettingsView()
                    } label: {
                        Label("Privacy & Security", systemImage: "lock")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var todaySection: some View {
        Section {
            Toggle("Group by Aspiration", isOn: $groupsByAspiration)
        } header: {
            Text("Today")
        } footer: {
            Text("Cluster today's cards under the aspiration they serve, so the day opens with the why.")
        }
    }

    private var timerCompletionSection: some View {
        Section {
            Toggle("Sound", isOn: $timerSound)
            Toggle("Vibration", isOn: $timerHaptic)
        } header: {
            Text("Timer Completion")
        } footer: {
            Text("Plays a sound and vibrates when a countdown reaches zero.")
        }
    }
}
