# Feature proposals

Three meaningful features for **lead track / LeadStone**, each chosen to build on
what already exists rather than bolt on something foreign. They cover three
distinct axes — *seeing* your data, *enriching* your data, and *capturing* your
data with less friction — and every one of them reuses models and services that
are already in the repo.

Quick grounding in today's app: metrics are either `.duration` or `.count`
(`Shared/Models/MeasurementType.swift`); sessions roll up into `DailyTotal`s via
`SessionStatistics`; goals, rest days, and streaks already exist; the standout
feature is the pluggable **Weekly Review** insight engine
(`Shared/Services/InsightGenerator.swift`); a static `ScoreboardWidget` and a
timer Live Activity (`StopTimerIntent`) round it out. The gaps the three
proposals below fill are all visible in that code.

---

## 1. Progress trends & goal pacing (Swift Charts)

> **Status: implemented.** Shipped as `TrendsChartView` (range selector, daily
> bars, 7-day rolling-average line, weekly aggregation, goal reference line) and
> `GoalPace` / `GoalPaceView` (the pace banner), with unit tests in
> `GoalPaceTests` and `SessionStatisticsTests`.

**What.** A "Trends" section in `MetricDetailView` / `DetailedStatisticsView`
that plots a real time series of daily (or weekly) totals:

- Bars or a line for each day's total — the data is already computed as
  `DailyTotal.duration` in `SessionStatistics.dailyTotals`.
- A horizontal **goal reference line** (`dailyGoal`, or `weeklyGoal` in weekly
  mode) so you can see at a glance how often you clear the bar.
- A **7-day rolling average** line — `SessionStatistics.recentAverage` already
  exists; just plot it per day.
- A range/granularity switch (2 weeks · 8 weeks · 6 months; day vs. week).
- Rest days (`Metric.isGoalDay(on:)`) drawn de-emphasized so dips on intentional
  off-days don't read as failures.

**Plus a pace banner.** Given the week's progress vs. `weeklyGoal` and how much
of the week has elapsed (counting only goal days), show "on track / 2h ahead /
40m behind" with a projected end-of-week total. Streaks already answer
*consistency*; pace answers *am I going to make my number?*, which nothing in the
app does today.

**Why it matters.** The app computes a lot of numbers and has a calendar
heatmap, but there is **no trend visualization anywhere** — a user can't see
whether a metric is climbing or sliding, only today's totals and a colored grid.
Pace turns a passive stat into a forward-looking nudge.

**Why it fits.** Swift Charts is a first-party framework, so it honors the
"no external dependencies" rule in `CLAUDE.md`. Every input already exists
(`DailyTotal`, `currentWeekTotal`, `recentAverage`, `isGoalDay`), and it works
for both measurement types through `ValueFormatter`. To stay under the strict
SwiftLint limits (≤5 complexity, 30-line bodies), keep the pace math in a
testable `GoalPace` helper under `Shared/Services` — mirroring how
`SessionStatistics` is structured and unit-tested today.

---

## 2. Session notes & a quality rating → "what works" insights

**What.**

- Add two optional fields to `Session` (`Shared/Models/Session.swift`):
  `note: String?` and `quality: Int?` (a 1–5 "how did it go?").
- After a timer stops or a manual entry is saved
  (`DurationEntryView` / `CountEntryView`), offer an optional, skippable
  rating + note so logging stays frictionless.
- Surface the note/rating in `SessionRowView` and the detailed stats.
- Add **new `InsightGenerator` detectors** that correlate `quality` with
  context: "Your best-rated sessions are in the **morning**" (average rating per
  `TimeOfDayBucket`), "Longer sessions tend to feel better" (rating vs.
  duration), or a rising/falling quality trend week-over-week. These surface in
  the Weekly Review beside the existing insights under a new
  `InsightCategory.quality`.
- Add `note` / `quality` columns to `CSVExporter` and `CSVImporter` so the
  existing round-trip stays lossless.

**Why it matters.** Today the app tracks *quantity* (time and count) but never
*quality*. Pairing the two is the heart of quantified-self value: it stops
answering only "how much did I do?" and starts answering "**what conditions
produce my best sessions?**" That moves the insight engine — already the app's
most distinctive feature — from descriptive ("you did more this week") to
prescriptive ("you do your best work before noon").

**Why it fits.** The fields are optional, so this is an additive SwiftData
migration of exactly the kind the team already handles carefully (see
`ecc2fc6` and `SharedModelContainer.backfillMetricStableIDs`). The insight engine
is explicitly pluggable — `collectRaw` is a list of detectors, and adding a case
to `Insight` / `InsightCategory` is the established pattern. CSV already
round-trips, so it's just two more columns.

---

## 3. One-tap & "Hey Siri" logging (App Shortcuts + interactive widget)

**What.**

- Add `StartTimerIntent` and `LogEntryIntent` next to the existing
  `StopTimerIntent` (`Shared/Services/StopTimerIntent.swift`): start a duration
  metric's timer (and Live Activity), or add to a count metric ("+1" or an
  amount), parameterized by which metric via an AppIntents entity query.
- Register `AppShortcuts` so users automatically get Siri phrases
  ("Start Reading", "Log Pushups") plus Spotlight and Shortcuts actions.
- Make `ScoreboardWidget` **interactive**: a Start/Stop button per duration
  metric and a "+1" button per count metric via `Button(intent:)` — it already
  reads the shared store through `SharedModelContainer`, so the data path is
  done. Add a Lock Screen accessory widget for the single most-used metric.

**Why it matters.** For a habit tracker the biggest lever on adherence is
*capture friction*. Right now you must open the app to start a timer or log a
count. Voice and a Home/Lock Screen button let you capture the moment it
happens — the instant a run starts or a set finishes — which is exactly when
people forget. It also makes the streak and goal machinery the app already
invests in (reminders, streak-at-risk alerts) far easier to keep alive.

**Why it fits.** The pattern is already proven in the repo: `StopTimerIntent` is
a working `LiveActivityIntent` backed by `SharedModelContainer`, the Live
Activity and `TimerActivityAttributes` exist, and `ScoreboardWidget` already
fetches from the shared store. So this is "extend the App Intents surface and
make the existing widget interactive," not green-field work — and interactive
widgets, `AppShortcuts`, and accessory widgets are all first-party
(WidgetKit / AppIntents), keeping the zero-dependency rule intact.

---

### Also considered

Pause/resume + optional Pomodoro intervals on the running timer (accuracy for
interrupted focus sessions); a cross-metric **Today** dashboard; milestone
achievements beyond streaks (100 sessions, 50 hours); and iCloud/CloudKit sync
for the SwiftData store. Good candidates for a later round — the three above were
chosen for the best ratio of user value to fit with the current architecture.
