import SwiftData
import SwiftUI

/// The aspiration detail as an album page: the full-bleed cover wearing the
/// title, the "why" as a serif lede, the "Held as principles" card (the vows
/// with their lived underlines), the "This week" card (open commitments),
/// the "Story so far" card (kept moments and the effort ledger), and two
/// disclosure rows into the attached items and the intention history. Edit
/// sits in the toolbar; delete hides behind the ellipsis menu and a
/// confirmation, so the destructive action is never one accidental tap away.
struct AspirationDetailView: View {
    /// Internal so the card blocks in their own files can write through it.
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    let aspiration: Aspiration
    @State private var showingEdit = false
    @State private var showingCalendar = false
    @State private var showingDeleteConfirmation = false
    /// Internal for the "This week" card in `AspirationIntentionSections`.
    @State var showingSetIntention = false
    /// Internal for the story card in `AspirationMomentsSection`: the "Keep"
    /// composer, the row tapped for editing, and a photo-bearing moment
    /// awaiting its delete confirmation.
    @State var showingKeepMoment = false
    @State var editingMoment: Moment?
    @State var momentPendingDelete: Moment?
    /// Internal for the principles card in `AspirationPrinciplesSection`:
    /// the hold-a-principle alert and its draft.
    @State var showingHoldPrinciple = false
    @State var principleDraft = ""
    /// Whether the three narrative cards are open. All start expanded; the
    /// "Held as principles", "This week", and "The story so far" eyebrows
    /// double as collapse controls.
    @State var principlesExpanded = true
    @State var thisWeekExpanded = true
    @State var storyExpanded = true

    var body: some View {
        page
            .toolbar { toolbar }
            .confirmationDialog(
                "Delete \(aspiration.title)?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Aspiration", role: .destructive, action: deleteAspiration)
            } message: {
                Text("Its metrics and projects stay in your library. Its intentions go with it.")
            }
            .sheet(isPresented: $showingEdit) {
                AspirationFormView(aspiration: aspiration)
            }
            .sheet(isPresented: $showingCalendar) {
                GoalCalendarView(filter: .aspiration(aspiration))
            }
            .sheet(isPresented: $showingSetIntention) {
                IntentionFormView(aspiration: aspiration)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingKeepMoment) {
                MomentFormView(aspiration: aspiration)
            }
            .sheet(item: $editingMoment) { moment in
                MomentFormView(aspiration: aspiration, moment: moment)
            }
            .confirmationDialog(
                "Delete this moment?",
                isPresented: momentDeletePresented,
                presenting: momentPendingDelete
            ) { moment in
                Button("Delete Moment", role: .destructive) { deleteMoment(moment) }
            } message: { _ in
                Text("Its photos are deleted with it. This can't be undone.")
            }
    }

    /// Drives the photo-bearing-moment delete dialog off the optional the
    /// context-menu action sets.
    private var momentDeletePresented: Binding<Bool> {
        Binding(
            get: { momentPendingDelete != nil },
            set: { presented in if !presented { momentPendingDelete = nil } }
        )
    }
}

// MARK: - Page

extension AspirationDetailView {
    /// The cover runs under the status bar; the nav bar carries no title of
    /// its own (the cover wears it) so only the floating glass controls sit
    /// on the photo.
    private var page: some View {
        ScrollView {
            VStack(spacing: 0) {
                AspirationCoverBanner(aspiration: aspiration)
                content
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            whyLede
            principlesCard
            thisWeekCard
            storyCard
            disclosureCard
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    /// The why, set as a serif lede — the one piece of the screen that reads
    /// like a book rather than an instrument.
    @ViewBuilder
    private var whyLede: some View {
        if !aspiration.detail.isEmpty {
            Text(aspiration.detail)
                .font(.system(size: 19, design: .serif))
                .lineSpacing(5)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Card grammar

extension AspirationDetailView {
    /// The aspiration's identity color, worn by every accent on the screen.
    var tint: Color {
        aspiration.displayColor
    }

    /// A card's uppercase eyebrow.
    func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    /// The same eyebrow as `cardHeader`, but doubling as a collapse control:
    /// a full-width tap target with a chevron that lies flat when the section
    /// is open and points to it when closed.
    func collapsibleCardHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.2)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
        .accessibilityHint("Double tap to \(isExpanded.wrappedValue ? "collapse" : "expand")")
    }

    /// The hairline between card rows; `inset` pushes it past an icon column
    /// so it starts where the row's text does.
    func cardDivider(inset: CGFloat = 0) -> some View {
        Divider().padding(.leading, inset)
    }

    /// A quiet plus-affordance row in the aspiration's color — the card
    /// grammar for "add one more".
    func plusRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(tint)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Disclosure rows

extension AspirationDetailView {
    /// Everything list-like waits behind these two rows, so the page itself
    /// stays an album: membership on the first, the intention history on the
    /// second (present only once history exists).
    private var disclosureCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            disclosureRow("Attached", detail: attachedSummary) {
                AspirationAttachedListView(aspiration: aspiration)
            }
            if pastWeekCount > 0 {
                cardDivider()
                disclosureRow("Past intentions", detail: weeksText(pastWeekCount)) {
                    AspirationPastIntentionsView(aspiration: aspiration)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardShape())
    }

    private func disclosureRow(
        _ title: String,
        detail: String,
        @ViewBuilder destination: () -> some View
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The attached row's trailing summary: the names in display order, or
    /// the quiet invitation when nothing is attached yet.
    private var attachedSummary: String {
        let names = aspiration.metrics.inDisplayOrder.map(\.name)
            + aspiration.projects.inDisplayOrder.map(\.name)
        return names.isEmpty ? "None yet" : names.joined(separator: ", ")
    }

    /// How many distinct weeks the intention history spans — the disclosure
    /// row's only figure: a span, never a completion count.
    private var pastWeekCount: Int {
        Set(AspirationPastIntentionsView.pastIntentions(of: aspiration).map(\.weekStart)).count
    }

    private func weeksText(_ count: Int) -> String {
        count == 1 ? "1 week" : "\(count) weeks"
    }
}

// MARK: - Toolbar & actions

extension AspirationDetailView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button("Edit") { showingEdit = true }
        }
        ToolbarItem {
            Menu {
                Button("Calendar", systemImage: "calendar") { showingCalendar = true }
                Divider()
                Button("Delete Aspiration", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func deleteAspiration() {
        // The shared delete path cancels the intentions' pending daily
        // questions before the cascade (see `ModelContext.deleteAspiration`).
        modelContext.deleteAspiration(aspiration)
        dismiss()
    }
}
