import SwiftUI

struct ActiveSessionBanner: View {
    let session: Session

    private var tint: Color {
        session.metric?.displayColor ?? .accentColor
    }

    var body: some View {
        HStack {
            Image(systemName: "record.circle")
                .foregroundStyle(tint)
                .symbolEffect(.pulse)
            Text("Active")
                .font(.subheadline.bold())
            Spacer()
            TimerDisplay(startedAt: session.startedAt, tint: tint)
        }
        .padding(.vertical, 4)
    }
}
