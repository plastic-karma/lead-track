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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let aspiration: Aspiration
    @State private var showingEdit = false
    @State private var showingCalendar = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AspirationCoverBanner(aspiration: aspiration)
                AspirationDetailContent(aspiration: aspiration)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background { Theme.screenBackground.ignoresSafeArea() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .confirmationDialog(
            "Delete \(aspiration.title)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Aspiration", role: .destructive, action: deleteAspiration)
        } message: {
            Text(
                """
                Its metrics and projects stay in your library. Its intentions, moments, \
                and photos go with it.
                """
            )
        }
        .sheet(isPresented: $showingEdit) {
            AspirationFormView(aspiration: aspiration)
        }
        .sheet(isPresented: $showingCalendar) {
            GoalCalendarView(filter: .aspiration(aspiration))
        }
    }
}

private struct AspirationDetailContent: View {
    let aspiration: Aspiration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !aspiration.detail.isEmpty {
                Text(aspiration.detail)
                    .font(.title3)
                    .fontDesign(.serif)
                    .lineSpacing(5)
                    .padding(.bottom, 12)
            }
            if aspiration.isArchived {
                AspirationSetAsideNotice(aspiration: aspiration)
            }
            AspirationPrinciplesCard(aspiration: aspiration)
            AspirationIntentionsCard(aspiration: aspiration)
            AspirationStoryCard(aspiration: aspiration)
            AspirationDisclosureCard(aspiration: aspiration)
            if !aspiration.isArchived {
                AspirationShelvingControl(aspiration: aspiration)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

private struct AspirationSetAsideNotice: View {
    let aspiration: Aspiration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set aside")
                .font(.headline)
            Text("Your history stays here. Existing commitments can still be kept or let go.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            AspirationShelvingControl(aspiration: aspiration)
        }
        .padding(.bottom, 8)
    }
}

/// Shared visual grammar for the independently observed narrative cards.
struct AspirationCardHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.2)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")
    }
}

struct AspirationPlusRow: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.primary)
            .tint(tint)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AspirationDisclosureCard: View {
    let aspiration: Aspiration

    var body: some View {
        let pastWeekCount = Set(
            AspirationPastIntentionsView.pastIntentions(of: aspiration).map(\.weekStart)
        ).count
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                AspirationAttachedListView(aspiration: aspiration)
            } label: {
                AspirationDisclosureLabel(title: "Attached", detail: attachedSummary)
            }
            if pastWeekCount > 0 {
                Divider()
                NavigationLink {
                    AspirationPastIntentionsView(aspiration: aspiration)
                } label: {
                    AspirationDisclosureLabel(
                        title: "Past intentions",
                        detail: pastWeekCount == 1 ? "1 week" : "\(pastWeekCount) weeks"
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Theme.cardShape() }
    }

    private var attachedSummary: String {
        let names = aspiration.metrics.inDisplayOrder.map(\.name)
            + aspiration.projects.inDisplayOrder.map(\.name)
        return names.isEmpty ? "None yet" : names.joined(separator: ", ")
    }
}

private struct AspirationDisclosureLabel: View {
    let title: String
    let detail: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).font(.subheadline)
                Spacer(minLength: 8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
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
