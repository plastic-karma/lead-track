# Aspiration steering — escaping Goodhart's Law

Three features (plus one companion change) that steer **lead track / LeadStone**
toward *aspirations* — the why — while keeping lead-measure tracking vital.

The enemy is **Goodhart's Law**: *when a measure becomes a target, it ceases to
be a good measure.* An app built around daily goals, streaks, and pace is full
of Goodhart pressure points — the number can quietly replace the reason it was
set. These proposals give the app ways to notice that drift, question it, and
periodically release the pressure, without ever weakening the tracking itself.

## Grounding in today's app

The app already resists Goodhart in two deliberate places:

- **Aspirations are target-free by design** (`docs/ASPIRATIONS.md`): no target,
  no deadline, no "% done" — the why cannot be gamed because it is never
  scored.
- **Intentions expire by design** (`Shared/Models/Intention.swift`): a
  week-scoped commitment closes at the next Weekly Review, and the app computes
  no cross-week rate, streak, or pace over intentions — expiry is the feature.

What still calcifies is the **goal**: `Metric.dailyGoal` / `weeklyGoal` are
permanent once set, streaks reward unbroken chains, and the Weekly Review's
insight engine (`Shared/Services/InsightGenerator.swift`) describes behavior
but never questions the measure. These proposals extend the existing doctrine
to goals, insights, and the daily surface.

## Shared doctrine

Every feature below obeys the same rules, because an anti-Goodhart feature
that itself becomes a target is worse than nothing:

1. **Silence is the default.** Detectors and prompts need real evidence before
   they say anything; sparse data yields nothing, not a guess.
2. **Question the measure, never the user.** No copy accuses; measure-health
   copy always ends in a question.
3. **No new obligations.** Nothing here adds a streak, a completion rate, a
   badge, a notification, or queued "debt." Skipping is structurally
   invisible.
4. **Purely additive.** Default-valued fields and new models only; a user who
   ignores every feature sees the app behave exactly as it does today.

---

## Feature 1 — Aspiration alignment check-ins

### Concept

Every number in the app measures *output*. A check-in measures the one thing
output can't: **whether the effort still serves the why.** It is a weekly,
always-skippable, per-aspiration pulse — deliberately the app's only
*subjective* time series.

The Goodhart alarm is the **divergence**: effort trending up while alignment
trends down means the measures are being fed instead of the aspiration.

Crucially, the check-in itself must not become a metric: no streaks, no
completion rate, no "3 weeks checked in!", no nagging. Absence of a check-in is
silence, never debt — the same doctrine as intention closures, which never
queue across weeks.

### Data model

A new `@Model final class AspirationCheckIn` in
`Shared/Models/AspirationCheckIn.swift`, following the `Intention.swift`
`#if canImport(SwiftData)` shape exactly (compiles as a plain class in the
Linux overlay; no `Package.swift` exclude needed).

| Field | Type | Notes |
|---|---|---|
| `stableID` | `UUID?` | `#Unique` under the guard; minted in `init`, mirroring `Intention` |
| `weekStart` | `Date` | normalized start of the check-in's **calendar week**, the same convention as `Intention.weekStart(containing:)`. (The Weekly Review period is a trailing-7-day window, not a calendar week — the calendar-week key is what makes check-ins dedupable.) |
| `ratingRaw` | `Int` | 1–3, stored raw so a store written by a newer version with an unknown scale still opens (the `kindRaw` pattern) |
| `note` | `String` | default `""`; optional free text |
| `createdAt` | `Date` | default `.now` |
| `aspiration` | `Aspiration?` | plain var; the `@Relationship(deleteRule: .cascade, inverse:)` macro lives on a new `Aspiration.checkIns: [AspirationCheckIn] = []`, mirroring `Aspiration.intentions` — cascade for the same reason: a check-in is meaningless without its why |

**Rating semantics — alignment, not performance.** A 3-point scale with a
typed accessor:

```swift
enum AlignmentRating: Int, CaseIterable {
    case drifting = 1      // "Feels off the why"
    case unsure = 2        // "Somewhere between"
    case serving = 3       // "Serving the why"
}
```

Three points, not five, deliberately: five stars read as a grade of the user's
*week* (performance — the exact framing to avoid), and sparse subjective data
can't honestly support five levels of trend resolution anyway. The question
rendered above the control is always *"Is this effort still serving the
why?"* — never "how did you do?".

**One per aspiration per calendar week**, enforced in logic, not schema: the
UI edits the existing row for the current week if one exists.

**Migration:** purely additive — register the model in
`SharedModelContainer.create`'s `Schema` and the `ContentView` `#Preview`
model list; `Aspiration` gains one defaulted relationship array. Lightweight
migration, no backfill.

### Cadence & prompting

- **Weekly Review (primary surface).** `WeeklyReview.build(...)` gains a
  defaulted `checkIns: [AspirationCheckIn] = []` parameter (every existing call
  site and test stays byte-identical). `AspirationWeek` gains
  `offersCheckIn: Bool` — true only on the live week when the aspiration
  hasn't checked in yet. `AspirationWeekCard` renders a small **Pulse** block
  under the intentions block: the question, three capsule buttons (reusing the
  intention-closure button style), a note field revealed after a rating is
  tapped, and *no* dismiss button — scrolling past is the dismissal.
- **Skippability is structural, not polite:** a pending check-in never pulls a
  quiet aspiration onto the review stage (the staging rule is not extended),
  never badges, never notifies, and browsing earlier weeks shows no check-in
  machinery — exactly like intentions.
- **AspirationDetailView (always available).** A new **Pulse** section between
  the why text and the this-week section: this week's check-in (editable if
  present, offered if not) plus the history strip below.

### Divergence — the Goodhart alarm

A new pure service `Shared/Services/AspirationAlignment.swift` (enum,
Linux-testable):

```swift
enum AspirationAlignment {
    static let minimumCheckIns = 4          // before anything trend-like shows
    static let divergenceWindowWeeks = 6

    struct WeekPoint: Equatable { let weekStart: Date; let rating: Int }

    /// Ratings keyed to calendar weeks, oldest first, gaps preserved.
    static func series(from checkIns: [AspirationCheckIn], calendar: Calendar) -> [WeekPoint]

    /// Sessions per calendar week across the aspiration's de-duped
    /// contribution sources — the unit-blind effort proxy (units can't mix;
    /// session count can). Reuses AspirationRollup's source de-dup.
    static func effortSeries(for aspiration: Aspiration, weeks: Int, now: Date, calendar: Calendar) -> [Double]

    struct Divergence: Equatable {
        let windowWeeks: Int
        let effortChangeRatio: Double   // second-half mean vs first-half mean
        let firstRating: Int
        let lastRating: Int
    }

    /// Non-nil only when, over the trailing window: (a) >= minimumCheckIns
    /// ratings exist, (b) ratings fell by >= 1 full step from the window's
    /// first to its last, and (c) weekly effort is flat or rising
    /// (second-half mean >= first-half mean). Sparse data yields nil, always.
    static func divergence(alignment: [WeekPoint], effort: [Double], now: Date, calendar: Calendar) -> Divergence?
}
```

The trend math is intentionally crude — half-window means and endpoint
ratings, no regression. With ≤6 subjective points, anything fancier is false
precision. The guards make silence the default.

**Minimal honest visualization:** on the detail screen's Pulse section, a row
of small dots — one per week for the trailing 12 weeks, three fill levels,
hollow for skipped weeks — with *no* axis, numbers, or percentage. Shown only
once 4 lifetime check-ins exist; before that, the section shows only this
week's control and "Check in a few weeks running to see the shape." A detected
divergence renders as one quiet card in the same section:

> *"Effort here is up over the last six weeks, but your check-ins say it's
> serving the why less. Worth asking what changed?"*

with a **Reflect** affordance that focuses the note field. For v1 the
divergence card lives on `AspirationDetailView` only, not the review card —
the review card already carries totals, intentions, closures, and now a
check-in prompt; the alarm deserves the calmer lifetime screen it is computed
from.

### Why check-ins stay out of `InsightGenerator`

The insight engine is per-*metric*, one-week-vs-previous, objective, and
capped per category; check-ins are per-*aspiration*, multi-week, subjective.
Forcing them through a metric-shaped API would either misattribute an
aspiration's mood to one metric or require a parallel pipeline the review
doesn't have. The divergence computation is aspiration-native and lives beside
`AspirationRollup`, the aspiration-scoped analog of `SessionStatistics`.
(Feature 2's narrowing detector links *to* the check-in composer — the two
features touch at the action layer, not the data layer.)

### Chosen defaults

1. **3-point scale** (drifting / unsure / serving) — performance-neutral
   wording, honest resolution.
2. **Calendar-week key, one check-in per week, latest edit wins.**
3. **`minimumCheckIns = 4`, divergence window = 6 weeks** — a month of pulses
   before any trend claim.
4. **Effort proxy = weekly session count** across de-duped sources
   (unit-blind by construction).
5. **No notifications, streaks, or completion accounting on check-ins —
   ever.** A design invariant, not a default.

### Out of scope

Check-in CSV export/import; watch check-ins; divergence on the review card;
per-metric (rather than per-aspiration) check-ins.

### Acceptance criteria

- [ ] A check-in can be recorded from the current week's review card and from
      `AspirationDetailView`; at most one row per aspiration per calendar week
      (re-rating edits it).
- [ ] Skipping is invisible: no staging change, no badge, no notification, no
      queued prompt next week; browsing earlier weeks shows no check-in UI.
- [ ] Deleting an aspiration cascades its check-ins; deleting a check-in never
      touches anything else.
- [ ] The pulse strip and any divergence card appear only after 4 lifetime
      check-ins; divergence requires falling ratings *and* flat-or-rising
      effort in the same 6-week window (unit tests cover both false-positive
      directions).
- [ ] Zero check-ins ⇒ review and aspiration detail render identically to
      today, minus the one optional Pulse affordance.
- [ ] Compiles on iOS/watchOS/Linux overlay; `swiftlint` and
      `swiftformat --lint .` pass.

---

## Feature 2 — Measure-health insights

### Concept

The existing detectors describe *behavior* ("mostly a morning thing").
Measure-health detectors describe **the measure's grip on behavior** — the
fingerprints left when a target, not the aspiration, is doing the steering.

The copy discipline is absolute: **question the measure, never the user.**
Every measure-health detail string ends in a question mark; the words "cheat,"
"gaming," and "streak-padding" never appear. Guards are strict enough that
silence is the norm — a false Goodhart accusation is worse than a missed one.

### Feasibility — which patterns are defensible

| Pattern | Data needed | Verdict |
|---|---|---|
| **Threshold-stopping** — daily totals clustering just above `dailyGoal` | `SessionStatistics.dailyTotals`, `dailyGoal`, `isGoalDay` | **In.** Fully computable; strongest signal. |
| **Streak-saver sessions** — late, tiny, sole-session days under an active streak | `startedAt`, `trackingValue`, session history, `currentStreak` | **In**, simplified: "would-be-streak-breaking day" = the day's only session, under an active streak ≥ 7. Excluded for `.binary` (value is always 1) and health-linked metrics (sessions are mirrored, not chosen). |
| **Volume monoculture** — an aspiration dominated by its "cheapest" metric | rollup contribution sources | **In, reframed as *narrowing*.** No cost model exists, so "cheapest" is not defensible — but one attachment dominating recent sessions while previously-active attachments go quiet is. |
| Weekly-goal cramming — the weekly total repeatedly landing in the week's last days | `weeklyGoal`, daily values | **Deferred.** Weekend-heavy lives and rest-day schedules (`excludedWeekdays`) produce structural false positives; needs a rest-day-aware baseline first. |
| Countdown / round-number stopping | `countdownDuration` | **Rejected.** Ending at the countdown is the tool working, not the measure distorting. |

### Placement — hybrid, one new service

- **Metric-scoped detectors extend the existing engine.** A new
  `InsightCategory.measureHealth` and two new `Insight` cases; the detection
  math lives in a new pure `Shared/Services/MeasureHealth.swift` enum that
  `InsightGenerator.collectRaw` calls. `InsightGenerator` stays the single
  orchestrator (thresholds, category caps, ordering) and gains only two
  `append` lines — friendly to the ≤5-complexity / 30-line lint budget. The
  existing one-insight-per-category cap then gives **at most one
  measure-health insight per metric per week** for free.
- **The narrowing detector cannot fit `InsightGenerator`** (its API is
  metric-shaped: `generate(for metric:)`), so it is a second entry point on
  the same `MeasureHealth` enum, consumed by the aspiration side of review
  assembly and by `AspirationDetailView`. One service, two scopes, one tone.

```swift
// Shared/Services/MeasureHealth.swift
enum MeasureHealth {
    static let lookbackDays = 28
    static let clusterBand = 0.15            // within +15% of the goal line
    static let clusterShare = 0.7            // of hit-days in the band
    static let minHitDays = 8
    static let saverValueShare = 0.25        // vs the metric's median session
    static let saverMinStreak = 7
    static let saverMinOccurrences = 2
    static let saverLateHour = 21
    static let monocultureShare = 0.75
    static let monocultureMinQuietSources = 2
    static let monocultureMinSessions = 12

    /// Daily totals hugging the goal line: of the last 28 days' goal-day
    /// hits, >= 70% landed in [goal, goal * 1.15], with >= 8 hit-days.
    /// Quantity metrics with a dailyGoal only.
    static func detectGoalClustering(metric: Metric, now: Date, calendar: Calendar) -> Insight?

    /// Sole-session days in the last 28 days whose value was <= 25% of the
    /// metric's median completed session AND started at/after 21:00, while a
    /// streak >= 7 was alive. Fires at >= 2 occurrences.
    static func detectStreakSaver(metric: Metric, now: Date, calendar: Calendar) -> Insight?

    /// Aspiration narrowing: over the trailing 30 days one de-duped source
    /// carries >= 75% of sessions (>= 12 sessions total) while >= 2 sources
    /// active in the prior 30-day window logged nothing.
    struct Narrowing: Equatable {
        let dominantName: String
        let dominantShare: Double
        let quietNames: [String]
    }
    static func detectNarrowing(for aspiration: Aspiration, now: Date, calendar: Calendar) -> Narrowing?
}
```

New `Insight` cases (pure `Equatable` payloads, copy in the `Insight.swift`
extensions like every other case):

```swift
case goalClustering(bandedHits: Int, totalHits: Int)
case streakSaver(occurrences: Int, streak: Int)
```

Copy, in the questioning register:

- **goalClustering** — headline *"Days often stop right at the goal"*, detail
  *"8 of 10 goal days landed within 15% of the line. Is the goal the right
  size — or has the line become the point?"*
- **streakSaver** — headline *"Small late saves kept the chain"*, detail
  *"2 evenings this month, a session a quarter of your usual size landed after
  9 pm. Would a rest day serve the why better than the chain?"* (Rest days
  exist — `excludedWeekdays` — so the question points at real machinery.)

**Ordering:** measure-health detectors are appended *first* in `collectRaw` —
ordering is priority, and when a measure-health insight fires (rarely, by
design) it must not be crowded out of the card's three insight slots by a
routine volume delta.

### Minimum-data guards

Beyond the threshold table: first session ≥ 28 days old (both metric
detectors); goal present and `tracksQuantity` (clustering); non-binary and
non-health-linked (streak-saver); ≥ 3 ever-active attached sources
(narrowing). No persistence-based cooldown: insights are recomputed live and
never stored, matching the engine's design. A clustering insight that fires
two weeks running is answered by the pressure-release valve — Feature 3's
season review, where adjusting or retiring the goal ends the signal at the
source. An accepted, deliberate trade against adding insight persistence.

### Insight → action

- **Metric cards:** the insight row on `MetricWeekCard` gains an optional
  trailing action chip, rendered only for `.measureHealth` insights:
  **"Review goal"**, opening `GoalSettingsView` via the same sheet route the
  intention-promotion flow already uses (`PromotionGoalRoute` — renamed
  `GoalSettingsRoute`, since it now serves two callers). With Feature 3
  shipped, that sheet is also where the season gets reconsidered, so the
  deep-link lands on the full remedy.
- **Narrowing (aspiration):** one quiet row on `AspirationDetailView` (beside
  the Pulse section) and a single line on the aspiration's review card, with
  the action **"Check in"** opening the Feature 1 composer — the correct
  remedy for "is the mix still right?" is a subjective pulse, not a settings
  screen.

### Chosen defaults

The threshold table above, plus: measure-health prepended in priority order;
one per metric per week via the existing category cap; band = +15% and
share = 70% chosen so a user who *naturally* stops near a well-sized goal for
a single week doesn't trigger (it takes 8+ hit-days over 4 weeks).

### Out of scope

Notifying on insights (insights are never notified); CSV changes; watch
surfaces; the deferred weekly-cramming detector.

### Acceptance criteria

- [ ] Each detector returns nil below its data floor (unit-tested per guard)
      and never fires for binary or health-linked metrics where excluded.
- [ ] A fired measure-health insight appears at most once per metric card,
      first in the list, with a working "Review goal" deep-link into
      `GoalSettingsView`.
- [ ] Narrowing appears on aspiration surfaces only when the dominance,
      quiet-sources, and volume floors all hold, and links to the check-in
      composer.
- [ ] No copy string contains an accusation; every measure-health detail ends
      with a question.
- [ ] Metrics with no goal, sparse history, or steady behavior produce reviews
      identical to today.
- [ ] Linux `swift test` covers all detector math; lint passes.

---

## Feature 3 — Goal seasons

### Concept

A permanent target is how a measure quietly becomes the point: it outlives the
reason it was set. Seasons make every goal an **experiment with an end date**:
created for N weeks, then deliberately renewed, adjusted, or retired at the
Weekly Review — each option framed against the aspirations the metric serves.
Retiring becomes a first-class, positive act (tracking without a target is a
first-class state — `CONTEXT.md` already defines goal and aspiration as
opposites), not a failure.

### Data model — fields on `Metric`, no `GoalSeason` @Model

A separate `GoalSeason` @Model preserving past seasons was weighed and
rejected: (a) `dailyGoal`/`weeklyGoal` are read by `GoalSummary`, `GoalPace`,
`InsightGenerator`, the watch snapshot builder, widgets, and every card — a
season table either duplicates the live values (drift risk) or becomes the
source of truth (touching every reader; the opposite of additive); (b) a
ledger of retired goals is a performance record by another name — precisely
the score-keeping this feature exists to dissolve; (c) intentions set the
precedent that lifecycle history is narrative, not aggregate.

**Chosen: four defaulted fields on `Metric`,** one season per metric covering
its goal settings as a whole (daily + weekly are already edited as one
screenful in `GoalSettingsView`, and one review question — "is this target
still serving *Grow wiser*?" — is the right altitude).

| Field (on `Metric`) | Type | Notes |
|---|---|---|
| `goalSeasonStartedAt` | `Date?` | stamped when a goal is enabled, its amount changed, or the season renewed. `nil` = unseasoned (all pre-feature goals) |
| `goalSeasonWeeks` | `Int?` | chosen at creation; default suggestion 6. `nil` with a goal present = unseasoned |
| `goalSeasonNote` | `String` = `""` | "what this season is for," in the user's words — the review row's framing line |
| `binaryGoalRetiredAt` | `Date?` | when a binary habit's implicit show-up expectation was released. `nil` (all pre-feature habits) = the expectation is live |

Additive lightweight migration (the `excludedWeekdays`/`countdownDuration`
precedent). Plain properties outside any `#if` guard — Linux-fine.
`WatchSnapshot` untouched.

**Unseasoned legacy goals are never due** — no retroactive obligation appears
on update day. They acquire a season the first time `GoalSettingsView` saves
them (the season section is part of the form, pre-filled with the default).
The alternative — declaring all existing goals due — would greet users with a
wall of prompts.

### Pure service

`Shared/Services/GoalSeason.swift` (enum; `GoalSeasonTests.swift`, Linux):

```swift
enum GoalSeason {
    static let defaultLengthWeeks = 6
    static let lengthChoices = [4, 6, 8, 12]
    static let graceWeeks = 2

    enum Phase: Equatable {
        case none                       // no goal, or unseasoned goal
        case active(weeksRemaining: Int)
        case due                        // season ended, within grace
        case pastSeason(weeksOver: Int) // grace elapsed; goal still working
    }

    static func phase(of metric: Metric, now: Date, calendar: Calendar) -> Phase

    /// Review rows for the live review only: metrics whose phase is .due or
    /// .pastSeason, with the aspiration names the metric serves.
    struct Review: Identifiable, Equatable {
        let id: String            // metric stableID
        let name: String
        let icon: String
        let colorName: String?
        let goalText: String      // "30 min / day · 5h / week"
        let seasonNote: String
        let aspirationTitles: [String]
        let phase: Phase
    }
    static func reviews(for metrics: [Metric], now: Date, calendar: Calendar) -> [Review]
}
```

Binary habits are seasoned through their implicit target: the show-up-today
expectation. Their season runs while the expectation is live (goal settings
surface it as an explicit, releasable "Expect It Daily" toggle), the review
row reads "Show up daily," and retiring stamps `binaryGoalRetiredAt` — the
habit keeps its card, logging, and streak history but drops out of the day's
rings and done/left arithmetic, exactly mirroring a retired amount goal. A
daily habit's chain is the most Goodhart-prone target in the app, so it gets
the season treatment rather than an exemption.

### Lapse semantics — flag, never auto-retire

If the review prompt is ignored, the goal **keeps working unchanged** — rings,
pace, goal-days-hit, reminders, everything. For 2 weeks it sits as `.due`;
after that, `.pastSeason`: still fully functional, but surfaces wear a quiet
"past season" tag (the goal area of `MetricDetailView`, a small badge on the
review row), and the review keeps offering the *same single row* — never
stacking, never counting weeks of "debt" beyond the factual tag.

Auto-retire was rejected because it silently destroys user configuration and
changes ring/pace behavior without consent — a trust break. Escalating
reminders were rejected because they would make the season itself a Goodhart
target ("clear your reviews"). The flag is a fact, not a judgment.

### Review UI & write path

- **Assembly:** `WeeklyReview` gains `goalSeasonReviews: [GoalSeason.Review]`,
  built in `build(...)` for the live review only (empty when browsing earlier
  weeks, so all existing tests pass with `[]`).
- **WeeklyReviewView:** a "Goal seasons" block (new file
  `WeeklyReviewGoalSeasons.swift`, mirroring how the aspiration and intention
  sections live in their own extension files), placed after the aspiration
  section and before the Metrics section break — decisions about targets
  belong with the why-zone, above the stats pager. One row per due metric:
  icon + name, the goal, the season note, an aspiration line ("serves *Grow
  wiser*" from `metric.aspirations`, or "serves no aspiration yet" — itself a
  gentle nudge), and three capsules:
  - **Renew** — re-stamps `goalSeasonStartedAt = .now`, keeps
    `goalSeasonWeeks`. One tap, no sheet.
  - **Adjust** — opens `GoalSettingsView` via the shared `GoalSettingsRoute`
    sheet (also used by promotions and Feature 2); saving re-stamps the
    season.
  - **Retire** — confirmation dialog, then clears `dailyGoal`, `weeklyGoal`,
    and the three season fields; a binary habit instead stamps
    `binaryGoalRetiredAt`, releasing its show-up expectation while the card
    and history stay. **Preserves `excludedWeekdays`,
    `reminderTime`, and `streakAlertTime`** — rest days keep protecting the
    streak, and reminders are about showing up, not the target.
- **GoalSettingsView** — the single production write site for
  `dailyGoal`/`weeklyGoal` — gains a "Season" section (length picker
  `4/6/8/12` weeks, default 6, plus the note field). `save()` stamps
  `goalSeasonStartedAt` when a goal is enabled from off or an amount changes,
  keeps the stamp when only reminders change, and clears the season fields
  when both goals are toggled off. Because the intention-promotion flow
  already routes through this exact view, **promoted goals are automatically
  born with a season** — `IntentionRenewal`, `chainLength`, and
  `promotionDismissed` are untouched. The promotion copy gains two words:
  "…can graduate into a weekly goal on its metric *for a season*."

### Streak interaction — what the code actually does

Streaks are *logged-day* streaks: `SessionStatistics.currentStreak` counts
days with any session, protected by rest days — the goal amount never enters
the computation. So **retiring a goal does not break the streak**, and the
retire dialog says so, positively:

> *"The metric keeps tracking, and your streak of showing up continues. Only
> the target retires."*

The only thing that disappears is goal-attainment chrome (rings, pace banner,
goal-days-hit footer) — which is the point. Tests must pin that retire leaves
`excludedWeekdays` (and therefore `currentStreak` output) unchanged.

### Chosen defaults

1. **Default season = 6 weeks; choices 4/6/8/12** — long enough to see a
   habit's shape, short enough that "renew" is a real question ~8 times a
   year.
2. **Grace = 2 weeks, then a passive "past season" tag; never auto-retire.**
3. **One season per metric**, not per daily/weekly goal.
4. **Legacy goals unseasoned until first edit; unseasoned = never due.**
5. **Retire preserves rest days, reminders, and streak alerts.**

### Out of scope

Season history/ledger; watch or widget awareness of season phase
(`WatchSnapshotBuilder` keeps sending `dailyGoal` regardless); notifications
(rides the existing weekly-review notification).

### Acceptance criteria

- [ ] Creating or adjusting a goal via `GoalSettingsView` (including via
      intention promotion) stamps a season; the promotion chain logic is
      bit-for-bit unaffected (existing renewal tests untouched and green).
- [ ] A due season appears exactly once on the live review with
      Renew/Adjust/Retire; browsing earlier weeks shows nothing; ignoring it
      changes no goal behavior, and after 2 weeks only adds the "past season"
      tag.
- [ ] Retire clears both goals + season fields, preserves
      `excludedWeekdays`/reminders, and `SessionStatistics.currentStreak`
      output is provably unchanged before/after.
- [ ] Pre-feature goals produce no prompts until first edited.
- [ ] Additive migration verified (a store from the previous build opens
      clean); Linux overlay and lint green.

---

## Companion — Aspiration-first Today

A lighter reframe of the daily surface: an optional grouping mode where
Today's metric cards cluster under the aspiration they serve, each group
headed by the aspiration's title **and its why line** — so the first thing
read on the day screen is a reason, not a number. Strictly a toggle; the
default dashboard is untouched.

- **Toggle:** `@AppStorage("todayGroupsByAspiration") = false`, surfaced in
  `AppSettingsView` as a new "Today" section ("Group by aspiration"),
  following the existing plain-string key style.
- **Grouping:** new pure `Shared/Services/TodayGrouping.swift`
  (+ Linux tests). A metric belongs to an aspiration when the metric itself
  *or any of its projects* is attached (matching rollup semantics). With
  multiple candidate aspirations, the **earliest-created wins** as primary —
  no duplicate cards (a duplicated card would duplicate live timer affordances
  and break the "N left today" arithmetic; creation order is already the app's
  canonical aspiration order). Groups ordered by aspiration `createdAt`,
  metrics keeping their order within a group.
- **"Unaligned effort"** closes the list: header plus one quiet subtitle
  ("Not serving any aspiration yet"). The section's existence is the nudge —
  no badge, no CTA.
- **View change:** `MetricListView` only — with the flag on, the "left today"
  cards render per group with headers (title, why line in secondary caption,
  navigation to the aspiration); the Done Today section and toolbars are
  unchanged, and the aspirations footer is suppressed in grouped mode (its
  "Poured Into" chips would be redundant).

**Acceptance criteria:** toggle off ⇒ Today identical to before; every metric
appears exactly once in grouped mode; project-attached metrics group under
that aspiration; group counts sum to the ungrouped count; grouping logic
unit-tested on Linux.

---

## Suggested build order

1. **Goal seasons** — smallest model delta, and it creates the deep-link
   target the others point at: `Metric` fields → `GoalSeason` + tests →
   `GoalSettingsView` season section → review block.
2. **Alignment check-ins** — `AspirationCheckIn` model + container
   registration → `AspirationAlignment` + tests → review card block → detail
   Pulse section.
3. **Measure-health insights** — `MeasureHealth` + tests →
   `Insight`/`InsightGenerator` extension → card action chip (reusing 2's
   composer and 1's goal route).
4. **Companion** — `TodayGrouping` + tests → `MetricListView` branch +
   settings toggle.

Every step is independently shippable and additive; a store touched by any
step opens unchanged for a user who ignores all four features.
