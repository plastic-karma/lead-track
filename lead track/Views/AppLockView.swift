import SwiftUI

struct AppLockView: View {
    let service: AppLockService
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(.tint)
            Text("LeadStone")
                .font(.title.bold())
            Button {
                Task { await service.authenticate() }
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task { await service.authenticate() }
    }
}

struct AppSwitcherCover: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 50

    var body: some View {
        ZStack {
            Color(.systemBackground)
            Image(systemName: "lock.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(.tint)
        }
        .ignoresSafeArea()
    }
}
