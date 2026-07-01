import SwiftUI

/// A hand-rolled stand-in for the stock `TabView` chrome: `ContentView`'s
/// pager can't sit inside a real `TabView` (its selection change can't
/// animate), so this drives the same `selectedTab` state directly — a tap
/// here slides the pager exactly like a finished swipe does.
struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.today, label: "Today", systemImage: "square.stack.3d.up.fill")
            tabButton(.aspirations, label: "Aspirations", systemImage: "mountain.2")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .padding(.top, 8)
        .background(alignment: .top) {
            Divider()
        }
        .background(.bar, ignoresSafeAreaEdges: .bottom)
    }
}

private extension AppTabBar {
    func tabButton(_ tab: AppTab, label: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 21))
                    .frame(maxWidth: .infinity)
                Text(label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            // The icon+label are geometrically centered in each slot (verified to
            // sub-point precision), but both tabs still read as slightly left of
            // center, so nudge the content right to balance them by eye.
            .offset(x: 8)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack {
        Spacer()
        AppTabBar(selectedTab: .constant(.today))
    }
}
