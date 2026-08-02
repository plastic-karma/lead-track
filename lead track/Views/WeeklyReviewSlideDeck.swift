import SwiftData
import SwiftUI

// MARK: - Deck layout

/// The Week tab's slide deck: the header strip stays pinned as the screen's
/// masthead — its chevrons browse weeks from any slide — while the sections
/// page sideways beneath it, one focus per swipe, closed by the done slide.
/// `WeeklyReviewSlides` decides which slides exist; this file only renders
/// and pages them.
extension WeeklyReviewView {
    /// The whole deck: pinned header, then the pager with the system page
    /// dots as the affordance. The selection is repaired whenever the deck
    /// changes under it — a dismissed or decided-away slide advances to its
    /// neighbor, a week browse keeps the seat wherever it survives.
    func reviewDeck(_ review: WeeklyReview) -> some View {
        let groups = WeeklyReview.metricGroups(
            metrics: metrics, aspirations: aspirations,
            weeks: review.metricWeeks, quiet: review.quietMetrics
        )
        let deck = review.slides(context: slideContext(hasGroups: !groups.isEmpty))
        return VStack(spacing: 0) {
            WeekHeaderStrip(
                review: review,
                weeksBack: $weeksBack,
                goalSegments: WeeklyReview.weeklyGoalSegments(metrics: metrics, weeksBack: weeksBack)
            )
            .padding(.horizontal)
            .padding(.top, 8)
            slidePager(deck, review: review, groups: groups)
        }
    }

    private func slidePager(
        _ deck: [WeekSlide],
        review: WeeklyReview,
        groups: [WeeklyReview.MetricGroup]
    ) -> some View {
        TabView(selection: $slide) {
            ForEach(deck) { item in
                slideBody(item, review: review, groups: groups)
                    .tag(item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear { repairSelection(from: deck, to: deck) }
        .onChange(of: deck) { previous, current in
            repairSelection(from: previous, to: current)
        }
    }

    /// Keeps the pager's seat valid as slides appear and vanish — see
    /// `WeekSlide.repairedSelection` for where it lands.
    private func repairSelection(from previous: [WeekSlide], to current: [WeekSlide]) {
        guard !current.contains(slide) else { return }
        withAnimation(.snappy) {
            slide = WeekSlide.repairedSelection(slide, previous: previous, current: current)
        }
    }

    /// The deck inputs the view holds: computed presence plus the three
    /// until-next-week dismissals, evaluated here so the shared deck logic
    /// stays pure (see `WeeklyReview.SlideContext`).
    private func slideContext(hasGroups: Bool) -> WeeklyReview.SlideContext {
        WeeklyReview.SlideContext(
            hasMetricGroups: hasGroups,
            hasAspirations: !aspirations.isEmpty,
            pulsedAspirations: pulsedAspirations,
            checkInDismissed: WeeklyCheckInDismissal.isDismissed(storedWeekStart: dismissedCheckInWeek),
            oversubscriptionDismissed: WeeklyCheckInDismissal.isDismissed(
                storedWeekStart: dismissedOversubscriptionWeek
            ),
            intentionAsksDismissed: WeeklyCheckInDismissal.isDismissed(
                storedWeekStart: dismissedIntentionAskWeek
            )
        )
    }
}

// MARK: - Slides

extension WeeklyReviewView {
    /// One slide's content. Every case but the effort cards and the done
    /// close reuses its section builder unchanged from the scroll era.
    @ViewBuilder
    private func slideBody(
        _ slide: WeekSlide,
        review: WeeklyReview,
        groups: [WeeklyReview.MetricGroup]
    ) -> some View {
        switch slide {
        case .effort: effortSlide(groups)
        case .moments: slideScroll { recentPhotosSection(review) }
        case .intentionsToClose: slideScroll { intentionsSection(review) }
        case .intentionsToSet: slideScroll { intentionAsksSection(review) }
        case .checkIn: slideScroll { checkInSection(review) }
        case .oversubscription: slideScroll { oversubscriptionSection(review) }
        case .goalSeasons: slideScroll { goalSeasonSection(review) }
        case .done: doneSlide(review)
        }
    }

    /// One slide's canvas: the section top-aligned in its own vertical
    /// scroll, padded clear of the page dots riding the deck's foot.
    private func slideScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.top, 8)
                .padding(.bottom, 44)
        }
    }

    /// The effort slide: the aspiration-grouped metric cards, still the
    /// stack the long-press drag reorders — the drop surface that closes
    /// out a released drag now rides this slide's scroll.
    private func effortSlide(_ groups: [WeeklyReview.MetricGroup]) -> some View {
        slideScroll {
            MetricGroupsSection(
                groups: groups, aspirations: aspirations,
                metric: metric(for:), draggingID: $draggingGroupID
            )
        }
        .aspirationReorderDropSurface(draggingID: $draggingGroupID)
    }

    /// The deck's close, stated as fact — no praise, no button; swiping
    /// back is the way back. The resting aspirations keep their closing
    /// seat here, names only, their numbers living on their own screens.
    private func doneSlide(_ review: WeeklyReview) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("That's the week.")
                .font(.title3.weight(.semibold))
            restingLine(review.quietAspirations)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 44)
    }

    /// Resting aspirations close the review as one centered breath.
    @ViewBuilder
    private func restingLine(_ quiet: [WeeklyReview.QuietAspiration]) -> some View {
        if !quiet.isEmpty {
            Text("Resting: \(quiet.map(\.title).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
}

// MARK: - Effort leaf

/// The aspiration group cards with their fold state, split into a leaf view
/// so expanding a card re-renders only this slide — not the parent body,
/// whose `WeeklyReview.build` pass over five query result sets is the tab's
/// expensive part. The groups still flow down from the parent's queries, so
/// any model change rebuilds them exactly as before.
struct MetricGroupsSection: View {
    let groups: [WeeklyReview.MetricGroup]
    /// The full aspiration set a drag rewrites ranks over.
    let aspirations: [Aspiration]
    /// Maps a ledger row back to its model for the drill-in link.
    let metric: (String) -> Metric?
    /// The lifted card, owned by the parent so its slide's scroll surface
    /// can close out drag sessions released outside the cards.
    @Binding var draggingID: String?
    /// The group cards the user has expanded from their default folded
    /// state — per-card, transient, never persisted, like the Today tab's
    /// cluster stubs. Empty (the default) means every card is folded to its
    /// header line for a calmer, more focused screen.
    @State private var expandedGroups: Set<String> = []
    /// Writes the drag-reorder rank rewrites.
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            ForEach(groups) { group in
                groupCard(group)
                    .aspirationReorderable(
                        id: group.id == AspirationGrouping.unalignedID ? nil : group.id,
                        draggingID: $draggingID,
                        move: move
                    )
            }
        }
        .padding(.horizontal)
    }

    /// One hover step of a drag: rewrite the ranks and save. The unaligned
    /// group never takes part — it always trails.
    private func move(_ draggedID: String, over targetID: String) {
        withAnimation(.snappy) {
            AspirationReorder.applyMove(
                all: aspirations,
                visibleIDs: groups.map(\.id).filter { $0 != AspirationGrouping.unalignedID },
                draggedID: draggedID,
                targetID: targetID
            )
            try? modelContext.save()
        }
    }

    private func groupCard(_ group: WeeklyReview.MetricGroup) -> some View {
        MetricLedgerCard(
            header: MetricLedgerCard.Header(
                title: group.title, icon: group.icon, colorName: group.colorName
            ),
            weeks: group.weeks,
            quiet: group.quiet,
            metric: metric,
            collapse: collapseBinding(group.id)
        )
    }

    /// The transient fold flag for one group card, backed by the set above so
    /// sibling cards fold independently. Cards start collapsed, so a card reads
    /// as folded unless the user has expanded it.
    private func collapseBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !expandedGroups.contains(id) },
            set: { collapsed in
                if collapsed {
                    expandedGroups.remove(id)
                } else {
                    expandedGroups.insert(id)
                }
            }
        )
    }
}
