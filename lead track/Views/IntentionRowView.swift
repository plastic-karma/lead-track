import SwiftData
import SwiftUI

/// One open intention row — aspiration accent, the title, and a kind-specific
/// right side. Shared by the weekly review and the aspiration detail's "This
/// week" block; Today's cluster cards re-skin the same anatomy with a dot
/// (see `ClusterIntentionRow`), so the pieces below are shared.
///
/// Two skins: the classic row wears the aspiration's glyph; with
/// `showsPrinciple` (the aspiration detail, where the page is the
/// aspiration) the glyph goes and a serif "serves …" line beneath the title
/// carries the identity instead — the why threaded through the row.
///
/// Reflective rows deliberately carry no completion control of any kind, and
/// no row ever wears a red state, an overdue style, or a badge — progress is
/// only ever accumulation.
struct IntentionRowView: View {
    let intention: Intention
    var showsPrinciple = false

    var body: some View {
        HStack(alignment: servesLine == nil ? .center : .top, spacing: 12) {
            if !showsPrinciple {
                Image(systemName: intention.aspiration?.displayIcon ?? "mountain.2")
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .frame(width: 24)
            }
            titleBlock
            Spacer()
            IntentionRowTrailing(intention: intention, accent: accent)
        }
        .contentShape(Rectangle())
        .intentionRowActions(intention)
    }

    private var servesLine: String? {
        guard showsPrinciple else { return nil }
        return intention.principle?.text
    }

    @ViewBuilder
    private var titleBlock: some View {
        if let serves = servesLine {
            VStack(alignment: .leading, spacing: 3) {
                Text(intention.title)
                    .font(.subheadline)
                Text("serves \(serves)")
                    .font(.system(size: 12.5, design: .serif))
                    .italic()
                    .foregroundStyle(accent)
            }
        } else {
            Text(intention.title)
                .font(.subheadline)
        }
    }

    private var accent: Color {
        MetricColor.color(named: intention.aspiration?.colorName)
    }
}

// MARK: - Kind-specific right side

/// The intention row's right side, shared by every skin: tick control and
/// progress for counted intentions, progress alone for derived ones, and
/// nothing at all for reflective ones.
struct IntentionRowTrailing: View {
    let intention: Intention
    let accent: Color

    var body: some View {
        switch intention.kind {
        case .reflective:
            EmptyView()
        case .counted:
            progressLabel
            tickButton
        case .derived:
            if intention.isSourceRemoved {
                Text("source removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                progressLabel
            }
        }
    }

    @ViewBuilder
    private var progressLabel: some View {
        if let progress = IntentionProgress.compute(for: intention) {
            Text(progress.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Shows today's tick state; a tap always appends — extra same-day ticks
    /// are recorded, they just don't advance a per-day count.
    private var tickButton: some View {
        Button {
            withAnimation(.snappy) { _ = intention.tick() }
        } label: {
            Image(systemName: intention.hasTick() ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tick \(intention.title)")
    }
}

// MARK: - Actions

/// The context menu and rename alert every intention row skin carries, so
/// undo/rename/let-go/delete never drift between surfaces.
private struct IntentionRowActions: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let intention: Intention
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingQuestion = false

    func body(content: Content) -> some View {
        content
            .contextMenu { actions }
            .alert("Rename Intention", isPresented: $showingRename) {
                TextField("Title", text: $renameText)
                Button("Save") { rename() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingQuestion) {
                IntentionQuestionSheet(intention: intention)
            }
    }

    @ViewBuilder
    private var actions: some View {
        if intention.kind == .counted, intention.hasTick() {
            Button("Undo Tick", systemImage: "arrow.uturn.backward") {
                withAnimation(.snappy) { _ = intention.undoTick() }
            }
        }
        Button("Rename", systemImage: "pencil") {
            renameText = intention.title
            showingRename = true
        }
        if intention.isOpen, intention.isInCurrentWeek() {
            Button("Daily Question", systemImage: "questionmark.bubble") {
                showingQuestion = true
            }
        }
        servesMenu
        Button("Let Go", systemImage: "leaf") {
            NotificationService.cancelQuestion(for: intention)
            withAnimation { intention.letGo() }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            NotificationService.cancelQuestion(for: intention)
            withAnimation { modelContext.delete(intention) }
        }
    }

    /// Retags which of the aspiration's principles this intention serves —
    /// present only once any are held, so pre-principle rows stay quiet.
    @ViewBuilder
    private var servesMenu: some View {
        let held = (intention.aspiration?.principles ?? []).sorted { $0.createdAt < $1.createdAt }
        if !held.isEmpty {
            Menu {
                Picker("Serves", selection: servesSelection) {
                    Text("The why itself").tag(Principle?.none)
                    ForEach(held) { principle in
                        Text(principle.text).tag(Principle?.some(principle))
                    }
                }
            } label: {
                Label("Serves", systemImage: "text.quote")
            }
        }
    }

    private var servesSelection: Binding<Principle?> {
        Binding(
            get: { intention.principle },
            set: { principle in withAnimation { intention.principle = principle } }
        )
    }

    private func rename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        intention.title = trimmed
    }
}

extension View {
    /// Attaches the shared intention context menu and rename alert.
    func intentionRowActions(_ intention: Intention) -> some View {
        modifier(IntentionRowActions(intention: intention))
    }
}
