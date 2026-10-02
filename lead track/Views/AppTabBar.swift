import SwiftUI

/// A hand-rolled stand-in for the stock `TabView` chrome: `ContentView`'s
/// pager can't sit inside a real `TabView` (its selection change can't
/// animate), so this drives the same `selectedTab` state directly — a tap
/// here slides the pager exactly like a finished swipe does.
struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.today, label: "Today", systemImage: "square.stack.3d.up")
            tabButton(.week, label: "Week", systemImage: "calendar")
            tabButton(.aspirations, label: "Aspirations", systemImage: "mountain.2")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .sensoryFeedback(.selection, trigger: selectedTab)
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
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.title3.weight(.medium))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 32)
                    .background(isSelected ? Theme.chipFill : .clear, in: Capsule())
                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
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
