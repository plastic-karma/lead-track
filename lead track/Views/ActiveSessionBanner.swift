import SwiftUI

struct ActiveSessionBanner: View {
    let session: Session

    var body: some View {
        HStack {
            Image(systemName: "record.circle")
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
            Text("Active")
                .font(.subheadline.bold())
            Spacer()
            TimerDisplay(startedAt: session.startedAt)
        }
        .padding(.vertical, 4)
    }
}
