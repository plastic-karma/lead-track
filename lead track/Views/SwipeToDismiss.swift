import SwiftUI

/// Wraps a section so a mostly-horizontal swipe throws it off screen and fires
/// `onDismiss` — the ScrollView-tab answer to a `List` row's swipe action,
/// which those pages can't use. The drag engages only once it reads as more
/// horizontal than vertical, so an ordinary up/down scroll still falls through
/// to the enclosing scroll view and the page keeps scrolling over the section.
///
/// Purely presentational: it fades and flings the content and reports the
/// commit, leaving the caller to actually remove the section (and to offer an
/// `accessibilityAction` alongside, since a swipe alone is unreachable by
/// assistive technologies).
struct SwipeToDismiss<Content: View>: View {
    private let onDismiss: () -> Void
    private let content: Content
    @State private var offset: CGFloat = 0

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDismiss = onDismiss
        self.content = content()
    }

    /// Release past this many points to commit; shorter drags spring back.
    private static var commitDistance: CGFloat {
        100
    }

    var body: some View {
        content
            .offset(x: offset)
            .opacity(contentOpacity)
            .gesture(swipe)
    }

    /// Fades with the drag so the section is invisible by the time a committed
    /// fling clears the screen; a spring-back restores it.
    private var contentOpacity: Double {
        Double(max(0, 1 - abs(offset) / 320))
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    offset = value.translation.width
                }
            }
            .onEnded { value in release(value.translation.width) }
    }

    private func release(_ width: CGFloat) {
        guard abs(width) > Self.commitDistance else {
            withAnimation(.spring(duration: 0.3)) { offset = 0 }
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            offset = width > 0 ? 600 : -600
        } completion: {
            onDismiss()
        }
    }
}
