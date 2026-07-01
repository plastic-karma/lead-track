# Aspirations — requirements

A new top-level concept for **lead track / LeadStone**: an *aspiration* — an
ongoing, never-"done" theme you pour effort into over a lifetime. Unlike the
existing daily/weekly **goals** (`Metric.dailyGoal` / `weeklyGoal`,
`GoalSummary`, `GoalPace`), an aspiration has **no target and no deadline**. It
exists to answer *"why am I doing all this tracking?"* and to show *"how much
have I poured into what matters?"*

This document is the v1 requirements. Later follow-ups (notifications, watch
sync, insights, sharing) are listed under [Out of scope](#out-of-scope).

## Grounding in today's model

The app is a three-level hierarchy
(`Shared/Models/`):

- **`Metric`** — a tracked thing, either `.duration` (timer-based) or `.count`
  (with a `unit` like "pages" / "reps"). Owns `projects` and `sessions`. Carries
  goals, reminders, icon, color.
- **`Project`** — an optional sub-grouping *inside one metric* (e.g. Reading →
  "War and Peace"). Owns its own `sessions`; has a `status` and dates.
- **`Session`** — one recording: a timer run (`duration`) or a logged `value`
  (`trackingValue` unifies them).

An **`Aspiration`** sits *above* this hierarchy. It owns no sessions of its own —
it is a **lens** that aggregates the sessions of the metrics and projects
attached to it. `SessionStatistics` operates on a single metric's `[Session]`
and is **unit-blind** (it sums `trackingValue` into one number regardless of
unit). An aspiration mixes units, so it needs a dedicated aggregation layer on
top — see [Rollup semantics](#rollup-semantics).

## Principles

1. **Ongoing, never complete.** No target, no streak, no "% done." Aspirations
   grow and change over time.
2. **Purely additive and optional.** Aspirations are a layer *on top of* the
   existing app. Everything that works today keeps working unchanged — see
   [Backwards compatibility](#backwards-compatibility).
3. **A lens, not a container.** An aspiration never owns or moves sessions. It
   references metrics/projects; the underlying data is untouched.
4. **Membership is fluid.** Metrics and projects can be added to and removed from
   aspirations at any time — see [Mutable membership](#mutable-membership).
5. **Shared, not exclusive.** A metric or project can belong to many aspirations
   at once (many-to-many).

## Backwards compatibility

This is a hard requirement, not a nice-to-have:

- **Aspirations are entirely optional.** A metric or project with **zero**
  aspirations is a fully valid, first-class object — it behaves exactly as it
  does today. The Today dashboard, metric detail, projects, sessions, goals,
  widgets, and watch app are unaffected whether or not any aspirations exist.
- **No existing data is migrated or rewritten.** Adding `Aspiration` and the
  two relationship arrays is an **additive** schema change. SwiftData's
  automatic lightweight migration handles it with no migration code — the same
  way `excludedWeekdays`, `countdownDuration`, and `stableID` were added before.
  New relationship arrays default to empty.
- **An app with no aspirations is a normal state**, not an error. The
  Aspirations tab shows a friendly empty state (a `ContentUnavailableView`)
  prompting the user to create their first one; nothing forces their creation.
- **Deleting an aspiration never deletes a metric, project, or session.** It
  only severs the links (see delete rules below).

## Data model

A new `@Model final class Aspiration` in `Shared/Models/Aspiration.swift`,
following the `#if canImport(SwiftData)` pattern used by `Metric`/`Project`/
`Session` so it also compiles in the Linux SwiftPM overlay (`Package.swift`).

| Field | Type | Notes |
|---|---|---|
| `title` | `String` | the aspiration's name |
| `detail` | `String` | freeform "why this matters / what I'm reaching for" (default `""`) |
| `icon` | `String?` | SF Symbol, mirroring `Metric.icon` / `displayIcon` |
| `colorName` | `String?` | reuses the existing `MetricColor` palette |
| `imageData` | `Data?` | optional cover photo; `@Attribute(.externalStorage)` under the SwiftData guard so the blob lives outside the row |
| `createdAt` | `Date` | default `.now`; default sort key |
| `metrics` | `[Metric]` | **many-to-many** (default `[]`) |
| `projects` | `[Project]` | **many-to-many** (default `[]`) |

### Relationships

Both attachments are **many-to-many**, navigable from both sides (the back-link
UI needs the reverse direction).

**The `@Relationship(inverse:)` macro lives on `Aspiration`, and on `Aspiration`
only.** SwiftData requires the `inverse:` to be declared on *exactly one* side —
putting the macro on both sides raises a duplicate/circular-inverse error at
container init. `Aspiration` is the new type introducing the relationship, so it
owns the declaration; `Metric`/`Project` stay almost untouched (one plain array
each), reinforcing the "purely additive" promise. This mirrors how
`Metric.projects` carries the macro while `Project.metric` is plain.

```swift
// Aspiration.swift — owns both declarations (under the #if canImport guard)
@Relationship(inverse: \Metric.aspirations)  var metrics:  [Metric]  = []
@Relationship(inverse: \Project.aspirations) var projects: [Project] = []
```

- Add a **plain** `var aspirations: [Aspiration] = []` to **`Metric`** and to
  **`Project`** as the back-arrays — *no* `@Relationship` macro on these. They
  default to empty, so every existing metric and project reads as "no
  aspirations" with no migration.
- **Delete rules (nullify, never cascade):**
  - Deleting an **aspiration** removes it from each linked metric/project and
    deletes its `imageData`. Metrics, projects, and sessions are untouched.
  - Deleting a **metric** or **project** removes it from every aspiration that
    referenced it (handled by the inverse). The aspiration survives with that
    item gone from its rollup.

### Schema registration & platforms

- Register `Aspiration.self` in `SharedModelContainer.create(...)`'s `Schema`
  and in the `ContentView` `#Preview` container's model list.
- The model compiles on iOS, watchOS, **and** the Linux overlay. The `@Model`,
  `@Relationship`, `#Unique`, and `@Attribute(.externalStorage)` macros stay
  inside `#if canImport(SwiftData)`; on Linux the type degrades to a plain
  class with a `Data?` and two `[…]` arrays (no new `exclude:` entry needed if
  the whole file follows the existing guarded pattern).
- **Watch sync is out of scope for v1.** `Aspiration` is *not* added to
  `WatchSnapshot` / `PhoneWatchSyncService`; the watch app is unchanged.

## Mutable membership

Adding and removing metrics/projects must be possible **at any point in an
aspiration's life**, with no constraints tied to when sessions were recorded:

- The create/edit sheet and the aspiration detail screen both expose attach /
  detach affordances (multi-select picker to add; swipe-to-remove or an edit
  mode to remove).
- Optionally, a metric or project can also be attached to an aspiration from
  *its own* detail screen (the reverse direction). Nice-to-have; not required
  for v1.
- **Removing an attachment is non-destructive.** It severs the link only — the
  metric/project and all its sessions remain. The rollup simply recomputes
  without that contribution. Re-adding it later restores its full history to the
  total (rollups are always computed live from current membership, never stored
  as a running tally).
- There is no "archive" or locked state on links in v1; membership is freely
  editable.

## Rollup semantics

The rollup answers *"how much have I invested in this aspiration?"* It is
**computed live** from the current set of attached metrics/projects every time
it is shown.

A dedicated **`AspirationRollup`** service (in `Shared/Services/`, Linux-overlay
friendly) owns this computation. It does not get the breakdown for free from
`SessionStatistics` — that type is unit-blind and has no arbitrary-window total.
`AspirationRollup`:

1. **Collects** the de-duped session set for the aspiration (see
   [What counts](#what-counts)).
2. **Partitions** it into one duration bucket plus one bucket per distinct
   count unit (see [Mixed units](#mixed-units--a-breakdown-never-one-number)).
3. **Totals** each bucket two ways — lifetime and the 30-day window. Lifetime
   reuses `SessionStatistics.overallTotal`; the recent figure needs a new
   generic `windowedTotal(days:from:)` helper on `SessionStatistics` (today
   only the hardcoded `lastSevenDaysTotal` and the `recentAverage` exist).

`SessionStatistics` stays the per-bucket primitive; `AspirationRollup` is the
new layer that de-dups, partitions by unit, and aggregates across attached
items rather than a single metric.

### What counts

- **A whole metric attached** contributes **every** session of that metric —
  including sessions that live inside the metric's projects.
- **A single project attached** contributes only that project's sessions.
- **De-dup within one aspiration:** if a metric *and* one of that same metric's
  own projects are both attached to the *same* aspiration, the project is
  ignored for totals (the metric already contains it) — no double counting.
- **Across different aspirations**, the same metric/project may contribute to
  each independently. That overlap is intentional (the point of many-to-many)
  and is *not* deduped.

### Mixed units → a breakdown, never one number

An aspiration typically mixes a `.duration` metric (seconds) with `.count`
metrics in **different units** (pages, reps, glasses). These can't be summed
into a single figure. So the rollup is a **breakdown**:

- All `.duration` contributions collapse into **one time total**
  (`DurationFormatter`).
- Each distinct `.count` unit keeps **its own total** (`ValueFormatter`).
- Contributions with no `unit` fall back to a generic **entry count** —
  `"N entries"`, the **number of sessions**, not the summed value. (A no-unit
  count metric has no labelable magnitude, so the headline counts occurrences;
  the underlying values stay visible on the metric's own detail screen.) All
  no-unit count contributions share one `"entries"` bucket.

**Unit grouping is normalized.** `Metric.unit` is free-text, so the bucket key
is the unit trimmed of surrounding whitespace and case-folded
(`unit.trimmed().lowercased()`). This keeps `"pages"`, `"Pages"`, and
`"pages "` in **one** bucket instead of fragmenting the headline. The bucket is
**displayed** using the first non-empty original spelling encountered, so the
user sees `pages`, not `pages `. No singular/plural stemming — `"page"` and
`"pages"` stay distinct (the user controls the unit string).

### Lifetime + recent

Every figure is shown **two ways**:

- **Lifetime** — the cumulative total across all of a contribution's sessions.
  This is the headline "look how much you've poured in" number that only grows.
- **Recent** — the trailing **30-day** window (default; see
  [Chosen defaults](#chosen-defaults)), to show current momentum.

The recent window is **calendar-day-aligned**, matching the existing
`lastSevenDaysTotal` / `recentAverage` convention: the cutoff is
`startOfDay(now) - (days - 1)` days, so `days: 30` covers today plus the 29
prior calendar days (sessions filtered by `startedAt >= cutoff`). It is **not**
a rolling 30×24h boundary — "30 days" means 30 day-buckets, and today is never a
partial day.

Lifetime comes from `SessionStatistics.overallTotal`; recent comes from the new
`windowedTotal(days:from:)` helper. `AspirationRollup` computes both per bucket
and across the attached items rather than a single metric.

### Example

```
🏔  Grow wiser
   ─────────────────────────────────────────
   12h 40m  ·  340 pages  ·  18 articles        ← lifetime
   ↑ 2h 10m · 45 pages in the last 30 days      ← recent

   Reading            8h 20m · 340 pages
   Deep Work          4h 20m
   "Read Sapiens"     18 articles   (project)
```

A per-attachment breakdown list sits under the headline so each metric/project
keeps its own unit and total.

### Empty / zero states

- An aspiration with **no attachments** shows its title, cover, and *why* text
  with a "Nothing attached yet — add metrics or projects" prompt.
- Attachments that exist but have **no sessions yet** show a zeroed rollup
  ("Nothing logged yet"), not an error.

## UI surfaces

### Navigation — a new tab

Introduce a `TabView` at the `ContentView` root with two tabs, each owning its
own `NavigationStack`:

- **Today** — the existing `MetricListView` dashboard, unchanged.
- **Aspirations** — the new list described below.

This elevates aspirations to a first-class peer of daily tracking. It is the
only structural change to existing navigation.

**Destinations are registered on both stacks.** All three destinations
(`Metric`, `Project`, `Aspiration`) are applied to *each* tab's
`NavigationStack` via one shared modifier — not split per tab. This is required
because the Aspirations tab drills into `MetricDetailView` / `ProjectDetailView`
(tapping an attached item), and the back-link chip on those detail screens —
reachable from the **Today** tab — navigates to an `Aspiration`.

**Cross-tab back-link = push on the current stack.** Tapping "Part of: *Grow
wiser*" from a metric opened in the Today tab pushes the aspiration onto the
*current* (Today) stack — it does **not** switch tabs. This needs no cross-tab
state coordination and avoids a disorienting mid-drill tab jump. Accepted cost:
the same aspiration can appear in both tabs' histories; harmless for v1.

### Aspiration list

- A scrolling list of aspiration cards: cover image (or icon + color fallback),
  title, and a one-line rollup summary (e.g. "12h 40m · 340 pages").
- Sorted by `createdAt` (creation order), matching the metric list.
- Empty state: `ContentUnavailableView` inviting the first aspiration.
- A `+` toolbar button opens the create sheet.

### Aspiration detail

- Full-bleed **cover header** (cover image, or an icon+color band when none),
  title overlaid.
- The **why** text (`detail`), rendered prominently.
- The **rollup**: lifetime + recent headline, then the per-attachment breakdown.
- The list of **attached metrics & projects**, each tappable through to its
  existing detail screen, with remove affordances (see
  [Mutable membership](#mutable-membership)) and an "Add" entry point.
- Edit in the toolbar; delete behind the toolbar's ellipsis menu, guarded by
  a confirmation dialog.

### Create / edit sheet

- Fields: title, why-text (multi-line), icon picker, color picker, photo picker
  for the cover.
- **Attach picker** grouped by metric: select a metric **as a whole**, or
  expand it to pick **individual projects**. Reflects current membership and is
  fully editable here too.

### Back-links (default on)

`MetricDetailView` and `ProjectDetailView` show a small "Part of: *Grow wiser*"
chip (one per linked aspiration) that navigates to the aspiration. Makes the
connection bidirectional and motivating. Off would mean links are only visible
from the aspiration side.

## Out of scope

Deferred to later follow-ups:

- Notifications / reminders tied to aspirations.
- Watch sync (`WatchSnapshot`) and watch UI.
- Insight engine / Weekly Review integration (`InsightGenerator`,
  `WeeklyReview`).
- Sharing / share-image export.
- Any per-aspiration target, pace, or streak (aspirations stay target-free by
  design).

## Chosen defaults

Resolved here so v1 is unambiguous; each is easily changed later:

1. **Recent window = 30 days.**
2. **Rollup presentation** = one combined time total + per-unit count totals in
   the headline, with a per-attachment breakdown below.
3. **List order = creation order** (`createdAt`), like metrics.
4. **Back-links on metric/project detail = on.**
5. **Cover image stored** as `Data?` with `@Attribute(.externalStorage)` (no
   separate file management).

## Acceptance criteria

- [ ] Creating, editing, and deleting an aspiration works; deletion leaves all
      metrics, projects, and sessions intact.
- [ ] A metric/project can belong to multiple aspirations simultaneously.
- [ ] Metrics/projects can be added and removed from an aspiration at any time;
      the rollup recomputes live and re-adding restores full history.
- [ ] The rollup shows a correct lifetime and 30-day total, splitting duration
      from each count unit, with no double counting when a metric and its own
      project are both attached.
- [ ] An app with no aspirations behaves exactly as before; the Today tab,
      goals, widgets, and watch app are unchanged.
- [ ] The new model compiles on iOS, watchOS, and the Linux overlay
      (`swift build` / `swift test`), and lint passes (`swiftlint`,
      `swiftformat --lint .`).
