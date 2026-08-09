import SwiftData
import SwiftUI

/// The Week tab, laid out like Today one timescale up — but as a slide deck
/// rather than one crowded scroll: a pinned header strip whose weekly-goal
/// dial and day-by-day flame graph sit beside the headline number, then one
/// swipeable slide per section — the aspiration-grouped metric cards, the
/// moments doorway, the intention decisions and check-ins, the goal seasons
/// due — each a focus of its own, closed by the done slide. Chevrons on the
/// header strip browse earlier weeks from any slide; the metric rows drill
/// into their screens. Which slides exist is decided in
/// `WeeklyReviewSlides` (pure, Linux-tested); `WeeklyReviewSlideDeck`
/// renders and pages them.
///
/// Formerly a notification-triggered sheet; it now anchors the middle
/// timescale of the app's three tabs (day / week / lifetime), and the review
/// notification simply switches to this tab. Hosted in `ContentView`'s
/// navigation stack, so the shared drill-in destinations apply.
struct WeeklyReviewView: View {
    /// The metrics themselves — grouped by aspiration into the compact cards
    /// of the effort slide (see `WeeklyReview.metricGroups`).
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
    /// How many weeks back the header chevrons have browsed. Internal so
    /// the deck extension in its own file can bind the header strip to it.
    @State var weeksBack = 0
    /// The deck's seat — which slide fills the screen. Internal so the deck
    /// extension in its own file can page and repair it.
    @State var slide: WeekSlide = .effort
    /// The goal-settings route shared by measure-health insights, season
    /// adjustments, and accepted intention promotions — hoisted here so it
    /// works with or without goal seasons due.
    @State var goalSettingsRoute: GoalSettingsRoute?
    /// The metric whose goal season a Retire tap is confirming, if any.
    @State var retiringSeasonMetric: Metric?
    /// The seeded intention-form route opened from an "Intentions to set"
    /// row (see `IntentionAskRoute`).
    @State var intentionAskRoute: IntentionAskRoute?
    /// The ask metric still choosing among several owning aspirations.
    @State var intentionAskMetric: Metric?
    /// Aspirations whose alignment pulse was answered this visit, kept on
    /// stage so the note field doesn't vanish the moment a rating lands.
    @State var pulsedAspirations: Set<String> = []
    /// The group card lifted by a long-press drag, dimmed until the drop.
    /// Held here so the effort slide's scroll surface can close out a drag
    /// session.
    @State var draggingGroupID: String?
    /// The calendar week the user dismissed the alignment pulse in, stored as
    /// the week start's reference-date offset; the slide stays away until a
    /// later week reads past it. 0 — the unset default — dismisses nothing.
    /// See `WeeklyCheckInDismissal`.
    @AppStorage(WeeklyCheckInDismissal.alignmentWeekKey) var dismissedCheckInWeek = 0.0
    /// The same, for the oversubscription "Check-In" slide — its own week so
    /// dismissing one check-in leaves the other.
    @AppStorage(WeeklyCheckInDismissal.oversubscriptionWeekKey) var dismissedOversubscriptionWeek = 0.0
    /// The same again, for the "Intentions to set" asks.
    @AppStorage(WeeklyCheckInDismissal.intentionAskWeekKey) var dismissedIntentionAskWeek = 0.0
    /// Writes intention closures, renewals, promotions, and check-ins.
    @Environment(\.modelContext) var modelContext

    var body: some View {
        // Built once per body pass. The pass re-runs whenever any query
        // result or `weeksBack` changes — which the intention-closure and
        // check-in slides rely on — while purely cosmetic state (the card
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
            .sheet(item: $intentionAskRoute) { route in
                IntentionFormView(aspiration: route.aspiration, seedMetric: route.metric)
            }
    }

    @ViewBuilder
    private func content(_ review: WeeklyReview) -> some View {
        if metrics.unarchived.isEmpty, aspirations.isEmpty {
            emptyState
        } else {
            reviewDeck(review)
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

// MARK: - Slide furniture

extension WeeklyReviewView {
    /// The quiet title opening most slides — the zone's name in the same
    /// voice the scroll's section breaks used, minus the hairline rule:
    /// each zone now opens its own slide, so there is nothing to divide.
    func sectionBreak(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `sectionBreak` plus a quiet close button on the title row, so a
    /// dismissible slide can be sent away for the week by a plain tap —
    /// the deck's sideways swipe pages, so a visible control is the one
    /// reliable dismissal. Shared by the Week tab's dismissible check-ins.
    func dismissibleSectionHeader(_ title: String, dismiss: @escaping () -> Void) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// The review-schedule bell and its sheet in one leaf view, so opening or
/// dismissing the sheet re-renders only this button — not the parent body
/// and its review aggregation.
private struct SettingsBellButton: View {
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "bell")
        }
        .accessibilityLabel("Review Notification Schedule")
        .sheet(isPresented: $showingSettings) {
            WeeklyReviewSettingsView()
        }
    }
}
