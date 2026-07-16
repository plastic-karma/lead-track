import SwiftData
import SwiftUI

/// The Week tab, laid out like Today one timescale up: a header strip whose
/// weekly-goal dial and day-by-day flame graph sit beside the headline number,
/// then the metrics grouped into one compact card per aspiration — each folded
/// to its header by default for a calmer, more focused screen, tap to expand
/// its weeks with the quiet ones dimmed at the foot — then the goal seasons
/// due, and the resting aspirations closing the screen as one centered line.
/// Chevrons on the header strip browse earlier weeks; the metric rows drill
/// into their screens.
///
/// Formerly a notification-triggered sheet; it now anchors the middle
/// timescale of the app's three tabs (day / week / lifetime), and the review
/// notification simply switches to this tab. Hosted in `ContentView`'s
/// navigation stack, so the shared drill-in destinations apply.
struct WeeklyReviewView: View {
    /// The metrics themselves — grouped by aspiration into the compact cards
    /// that fill the tab (see `WeeklyReview.metricGroups`).
    @Query(sort: \Metric.createdAt) var metrics: [Metric]
    /// The aspirations the metric groups sort under, in the app's canonical
    /// creation order.
    @Query(sort: \Aspiration.createdAt) var aspirations: [Aspiration]
    /// Feeds the aspiration partition so a wholly quiet aspiration still reads
    /// as resting rather than active.
    @Query(sort: \Intention.createdAt) var intentions: [Intention]
    /// This week's alignment pulses — part of the same partition input.
    @Query(sort: \AspirationCheckIn.createdAt) var checkIns: [AspirationCheckIn]
    /// Every kept moment, windowed per aspiration into the reviewed week (see
    /// `WeeklyReview.build`). Empty until the feature is used — additive.
    ///
    /// These queries are deliberately unwindowed: the header chevrons browse
    /// arbitrarily far back, so any fetch-level window would need to track
    /// `weeksBack` (a dynamic-@Query restructure), and at a personal
    /// tracker's data scale the in-memory windowing in `WeeklyReview.build`
    /// stays proportional to the store, not the screen. Revisit by pushing
    /// a `weekStart`/`occurredAt` range into these predicates if lifetime
    /// histories ever grow past that.
    @Query(sort: \Moment.occurredAt) var moments: [Moment]
    @State private var weeksBack = 0
    /// The goal-settings route shared by measure-health insights, season
    /// adjustments, and accepted intention promotions — hoisted here so it
    /// works with or without goal seasons due.
    @State var goalSettingsRoute: GoalSettingsRoute?
    /// The metric whose goal season a Retire tap is confirming, if any.
    @State var retiringSeasonMetric: Metric?
    /// Aspirations whose alignment pulse was answered this visit, kept on
    /// stage so the note field doesn't vanish the moment a rating lands.
    @State var pulsedAspirations: Set<String> = []
    /// The group card lifted by a long-press drag, dimmed until the drop.
    /// Held here so the whole scroll surface can close out a drag session.
    @State var draggingGroupID: String?
    /// The calendar week the user dismissed the alignment pulse in, stored as
    /// the week start's reference-date offset; the section stays hidden until a
    /// later week reads past it. 0 — the unset default — dismisses nothing.
    /// See `WeeklyCheckInDismissal`.
    @AppStorage(WeeklyCheckInDismissal.alignmentWeekKey) var dismissedCheckInWeek = 0.0
    /// The same, for the oversubscription "Check-In" card — its own week so
    /// dismissing one check-in leaves the other.
    @AppStorage(WeeklyCheckInDismissal.oversubscriptionWeekKey) var dismissedOversubscriptionWeek = 0.0
    /// Writes intention closures, renewals, promotions, and check-ins.
    @Environment(\.modelContext) var modelContext

    var body: some View {
        // Built once per body pass. The pass re-runs whenever any query
        // result or `weeksBack` changes — which the intention-closure and
        // check-in sections rely on — while purely cosmetic state (the card
        // folds, the settings sheet) lives in leaf views below, so it can no
        // longer trigger this aggregation.
        let review = WeeklyReview.build(
            metrics: metrics, aspirations: aspirations, intentions: intentions,
            checkIns: checkIns, moments: moments, weeksBack: weeksBack
        )
        return content(review)
            .background(Theme.washedScreen)
            .navigationTitle("Week")
            .toolbar { toolbarItems(review) }
            .sheet(item: $goalSettingsRoute) { route in
                GoalSettingsView(metric: route.metric, prefillWeeklyGoal: route.prefillWeekly)
            }
    }

    @ViewBuilder
    private func content(_ review: WeeklyReview) -> some View {
        if metrics.unarchived.isEmpty {
            emptyState
        } else {
            reviewScroll(review)
        }
    }

    @ToolbarContentBuilder
    private func toolbarItems(_ review: WeeklyReview) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !review.metricWeeks.isEmpty {
                ShareLink(
                    item: WeekImageExport(review: review),
                    preview: SharePreview("Weekly Review")
                )
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            SettingsBellButton()
        }
    }
}

// MARK: - Layout

extension WeeklyReviewView {
    private func reviewScroll(_ review: WeeklyReview) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                WeekHeaderStrip(
                    review: review,
                    weeksBack: $weeksBack,
                    goalSegments: WeeklyReview.weeklyGoalSegments(metrics: metrics, weeksBack: weeksBack)
                )
                .padding(.horizontal)
                metricGroupsSection(review)
                intentionsSection(review)
                checkInSection(review)
                oversubscriptionSection(review)
                goalSeasonSection(review)
                restingLine(review.quietAspirations)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .aspirationReorderDropSurface(draggingID: $draggingGroupID)
    }

    /// The metrics grouped by the aspiration they serve, each aspiration one
    /// compact card of its metrics' weeks — the Week tab's answer to Today's
    /// clusters. Hidden when nothing logged effort this week (the resting line
    /// and header still speak).
    @ViewBuilder
    private func metricGroupsSection(_ review: WeeklyReview) -> some View {
        let groups = WeeklyReview.metricGroups(
            metrics: metrics, aspirations: aspirations,
            weeks: review.metricWeeks, quiet: review.quietMetrics
        )
        if !groups.isEmpty {
            MetricGroupsSection(
                groups: groups, aspirations: aspirations,
                metric: metric(for:), draggingID: $draggingGroupID
            )
        }
    }

    /// The labeled seam between the review's zones — a hairline rule with the
    /// zone's name, so the metric groups and the goal seasons read as distinct
    /// bands of one screen. Internal (not private) because the goal-seasons
    /// block in its own file opens with the same seam.
    func sectionBreak(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `sectionBreak` plus a quiet close button on the title row, so a section
    /// can be sent away for the week by a plain tap — the reliable partner to
    /// `SwipeToDismiss`. Shared by the Week tab's two dismissible check-ins.
    func dismissibleSectionHeader(_ title: String, dismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss until next week")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Resting aspirations close the review as one centered breath — names
    /// only; their numbers live on their own screens, the Aspirations tab
    /// the way in.
    @ViewBuilder
    private func restingLine(_ quiet: [WeeklyReview.QuietAspiration]) -> some View {
        if !quiet.isEmpty {
            Text("Resting: \(quiet.map(\.title).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
    }

    /// Shown only when no metrics exist at all; a week without sessions
    /// keeps the header strip so the chevrons can still browse.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Metrics", systemImage: "chart.bar")
        } description: {
            Text("Add a metric and start logging to see weekly insights.")
        }
    }

    /// Maps a ledger row back to its model for navigation. Internal (not
    /// private) for the same reason as the queries above.
    func metric(for id: String) -> Metric? {
        metrics.first { $0.stableID?.uuidString == id }
    }
}

// MARK: - Leaf state

/// The aspiration group cards with their fold state, split into a leaf view
/// so expanding a card re-renders only this section — not the parent body,
/// whose `WeeklyReview.build` pass over five query result sets is the tab's
/// expensive part. The groups still flow down from the parent's queries, so
/// any model change rebuilds them exactly as before.
private struct MetricGroupsSection: View {
    let groups: [WeeklyReview.MetricGroup]
    /// The full aspiration set a drag rewrites ranks over.
    let aspirations: [Aspiration]
    /// Maps a ledger row back to its model for the drill-in link.
    let metric: (String) -> Metric?
    /// The lifted card, owned by the parent so its scroll surface can close
    /// out drag sessions released outside this section.
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

/// The notification-settings bell and its sheet in one leaf view, so opening
/// or dismissing the sheet re-renders only this button — not the parent body
/// and its review aggregation.
private struct SettingsBellButton: View {
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "bell")
        }
        .accessibilityLabel("Weekly Review Notification")
        .sheet(isPresented: $showingSettings) {
            WeeklyReviewSettingsView()
        }
    }
}
