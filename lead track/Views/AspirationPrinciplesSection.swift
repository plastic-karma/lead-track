import SwiftData
import SwiftUI

/// The "Held as principles" card of the aspiration detail — the why distilled
/// into short vows, each set as a serif sentence wearing its own lived record
/// beneath the words: a twelve-week dot underline, the lived-week count, and
/// the last day it was lived (see `PrincipleLiving`). Hollow dots are
/// silence, never debt; the quiet plus row is the only doorway for holding a
/// new vow, and the eyebrow collapses the card like its siblings.
extension AspirationDetailView {
    var principlesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsibleCardHeader("Held as principles", isExpanded: $principlesExpanded)
            if principlesExpanded {
                ForEach(heldPrinciples) { principle in
                    principleRow(principle)
                    cardDivider()
                }
                plusRow("Hold a principle") { showingHoldPrinciple = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, principlesExpanded ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardShape())
        .alert("Hold a Principle", isPresented: $showingHoldPrinciple) {
            TextField("The vow, in your words", text: $principleDraft)
            Button("Hold", action: holdPrinciple)
            Button("Cancel", role: .cancel) { principleDraft = "" }
        }
    }

    /// The creed in the order it was written.
    private var heldPrinciples: [Principle] {
        aspiration.principles.sorted { $0.createdAt < $1.createdAt }
    }

    private func holdPrinciple() {
        let text = principleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        principleDraft = ""
        guard !text.isEmpty else { return }
        withAnimation {
            modelContext.insert(Principle(text: text, aspiration: aspiration))
        }
    }
}

// MARK: - Rows

extension AspirationDetailView {
    private func principleRow(_ principle: Principle) -> some View {
        let record = PrincipleLiving.record(for: principle, in: aspiration.intentions)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(principle.text)
                    .font(.system(size: 20, design: .serif))
                Spacer(minLength: 8)
                Text("\(record.livedCount) of \(PrincipleLiving.historyWeeks)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            livedUnderline(record)
                .padding(.top, 7)
            lastLivedLine(record)
        }
        .padding(.top, 13)
        .padding(.bottom, 14)
        .contentShape(Rectangle())
        .principleRowActions(principle)
    }

    /// The sentence's own underline — one dot per trailing week, oldest
    /// first, filled when lived, hollow when not.
    private func livedUnderline(_ record: PrincipleLiving.Record) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(record.weeks.enumerated()), id: \.offset) { _, lived in
                livedDot(lived)
            }
        }
        .accessibilityLabel(
            "Lived \(record.livedCount) of the last \(PrincipleLiving.historyWeeks) weeks"
        )
    }

    @ViewBuilder
    private func livedDot(_ lived: Bool) -> some View {
        if lived {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
        } else {
            Circle()
                .strokeBorder(Theme.inactive, lineWidth: 1)
                .frame(width: 7, height: 7)
        }
    }

    /// The recency caption — absent until the principle has ever been lived.
    @ViewBuilder
    private func lastLivedLine(_ record: PrincipleLiving.Record) -> some View {
        if let date = record.lastLived, let via = record.lastLivedVia {
            Text("last lived \(date.formatted(.dateTime.month(.abbreviated).day())) · via \(via)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - Row actions

/// The context menu and reword alert every principle row carries. Deleting a
/// principle leaves its intentions and moments standing untagged (nullify);
/// only the vow and its lived record go.
private struct PrincipleRowActions: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let principle: Principle
    @State private var showingReword = false
    @State private var rewordText = ""

    func body(content: Content) -> some View {
        content
            .contextMenu { actions }
            .alert("Reword Principle", isPresented: $showingReword) {
                TextField("The vow, in your words", text: $rewordText)
                Button("Save", action: reword)
                Button("Cancel", role: .cancel) {}
            }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Reword", systemImage: "pencil") {
            rewordText = principle.text
            showingReword = true
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation { modelContext.delete(principle) }
        }
    }

    private func reword() {
        let trimmed = rewordText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        principle.text = trimmed
    }
}

private extension View {
    /// Attaches the shared principle context menu and reword alert.
    func principleRowActions(_ principle: Principle) -> some View {
        modifier(PrincipleRowActions(principle: principle))
    }
}
