# Moments — requirements

A new concept for **lead track / LeadStone**: a *moment* — a kept piece of
testimony that an aspiration is being lived. Every existing number in the app
records what was **poured in**; a moment records something that **grew out**:
*"ran the bridge loop without stopping — two years ago I couldn't climb the
stairs."* It is the answer to the rollup's reciprocal question — not *"how
much have I invested?"* but *"what has it given back?"*

A moment is the lag side of the app's lead measures, kept safe from Goodhart
by being **witnessed rather than measured**: written only by the user, never
aggregated, never scored, never prompted.

## Grounding in today's app

Every concept on the board is input-side effort or meta-commentary on the
measuring itself:

- **Sessions / rollups** — how much was poured in (`AspirationRollup`).
- **Goals + seasons** — is the input target right-sized, still worth having.
- **Intentions** — what input is committed to this week.
- **Check-ins** — a 1–3 *feeling* about whether the effort serves the why
  (`AspirationCheckIn`), the app's only subjective series.
- **Measure-health / divergence** — has the number replaced the reason.

Nothing records evidence of the becoming itself. When the Pulse asks *"is
this effort still serving the why?"*, the user answers from memory alone —
the app holds no record they could consult. Moments are that record, and the
Pulse question gains its ground truth: the aspiration screen shows the
evidence just above the question.

Two in-repo precedents already define the discipline this concept runs on:
`Intention.swift`'s *"history exists only as narrative"* (no cross-week
aggregate is ever computed over outcomes) and the check-in doctrine (absence
is silence, never debt). A moment generalizes both.

## Principles

1. **Testimony, not telemetry.** Only the user writes a moment. Nothing is
   ever auto-generated from tallies — no "100 sessions!" auto-moments. (The
   "milestone achievements" idea in `docs/FEATURE_IDEAS.md` is this concept's
   dishonest twin: computed from volume, it celebrates input with a bigger
   number, which is exactly the calcification `docs/ASPIRATION_STEERING.md`
   fights.)
2. **Never a number.** No moment counts on any surface of the app — not on
   cards, headers, rollups, insights, widgets, or the watch. Surfaces show
   the moments themselves, or nothing. The one deliberate exception is the
   user-triggered markdown export, whose range inventory prints a moment
   count for the LLM reader (see Principle 4).
3. **Never prompted.** No notification, badge, streak, or "you haven't kept a
   moment lately." Capture affordances sit quietly where the user already is;
   skipping is structurally invisible.
4. **Private by construction.** Photos live in on-device external storage;
   location is captured only on an explicit per-moment tap; nothing enters
   `WatchSnapshot`, widgets, or Health. The explicit, user-triggered
   markdown export — the "hand the whole practice to an LLM" artifact — is
   the one outbound path: it includes each moment's text, place label, and
   provenance, plus a range count, and never photos or coordinates. No
   other surface exports moments.
5. **Additive data, quiet capture.** New models and relationships remain
   additive, and every capture path is user-initiated. A store with zero
   moments needs no backfill and never invents testimony.

## Data model

A new `@Model final class Moment` in `Shared/Models/Moment.swift`, plus a
cascade-owned `MomentPhoto`, both following the `#if canImport(SwiftData)`
shape of `Intention`/`AspirationCheckIn` (plain classes in the Linux overlay;
no `Package.swift` exclude needed).

| Field | Type | Notes |
|---|---|---|
| `stableID` | `UUID?` | `#Unique` under the guard; minted in `init` (the `Intention` pattern) |
| `text` | `String` | the testimony, in the user's words |
| `occurredAt` | `Date` | when it happened — user-editable, backdatable, never in the future; what every surface windows and sorts on |
| `createdAt` | `Date` | when it was kept; immutable |
| `latitude` / `longitude` | `Double?` | plain doubles so the model compiles on Linux — CoreLocation types never enter `Shared/` |
| `placeName` | `String` = `""` | short human label, reverse-geocoded **once at capture**; display never geocodes or touches the network |
| `aspiration` | `Aspiration?` | the owning why — exactly one, fixed at creation |
| `metric` | `Metric?` | optional provenance; nullify |
| `project` | `Project?` | optional provenance; nullify |
| `photos` | `[MomentPhoto]` | cascade-owned, ordered by `sortIndex` |

`MomentPhoto`: `data: Data` (`@Attribute(.externalStorage)` under the guard),
`sortIndex: Int`, plain `moment: Moment?` back-pointer. A child model rather
than a `[Data]` attribute so each photo is its own lazily-loaded external
blob — moments accrue for a lifetime, and a text-only render must never drag
photo bytes in. (`Aspiration.imageData` stays a single attribute; a cover is
one decoration, moment photos are many pieces of content.)

### Cardinality — exactly one aspiration

**Weighed and rejected: many-to-many.** A lived moment can genuinely witness
two aspirations at once ("ran the bridge loop with my daughter"), but
many-to-many breaks cascade (orphaned moments when the last aspiration goes,
or a nullify rule that leaves why-less testimony), forces de-dup rules into
the review, and dilutes the moment's home. **Chosen: the `Intention` shape** —
exactly one owning aspiration, picked at creation and fixed for life (misfiled
testimony is deleted and re-kept, not re-homed). The occasional cost of
choosing a primary why is small and even clarifying.

### Relationships & delete rules

```swift
// Aspiration.swift — cascade, the Intention/AspirationCheckIn precedent:
// testimony is meaningless without its why.
@Relationship(deleteRule: .cascade, inverse: \Moment.aspiration)
var moments: [Moment] = []

// Moment.swift — provenance, the Intention.metric precedent: nullify both
// ways. Deleting the metric or project drops the link; the moment's text
// stands alone (no isSourceRemoved analog — a moment needs no machinery).
@Relationship(deleteRule: .nullify, inverse: \Metric.moments)  var metric: Metric?
@Relationship(deleteRule: .nullify, inverse: \Project.moments) var project: Project?

// Moment.swift — photos die with their moment.
@Relationship(deleteRule: .cascade, inverse: \MomentPhoto.moment)
var photos: [MomentPhoto] = []
```

`Metric` and `Project` gain one plain `var moments: [Moment] = []` back-array
each — no macro, defaulting empty, the same purely-additive shape as
`aspirations` and `intentions`.

**Provenance is not membership.** The linked metric/project records *where it
happened* ("Reading · War and Peace") and is **not** required to be attached
to the owning aspiration — the composer's picker merely leads with the
aspiration's own attachments. Deleting an aspiration cascades its moments and
their photos; metrics, projects, and sessions are never touched by any moment
operation.

### Schema registration & platforms

- Register `Moment.self` and `MomentPhoto.self` in
  `SharedModelContainer.create`'s `Schema` and in the `ContentView` `#Preview`
  container's model list.
- Additive lightweight migration (the `AspirationCheckIn` precedent): new
  models plus defaulted relationship arrays; no backfill, no data rewritten.
- Compiles on iOS, watchOS, and the Linux overlay. Watch sync untouched —
  `WatchSnapshot`, the watch app, and widgets never learn moments exist.

## Timestamps & editing

- **`occurredAt` is the moment's own time** — a date+time picker in the
  composer, defaulting to now, capped at now (testimony describes what
  happened, never what will). Moments are often remembered days late;
  backdating is normal, not an edge case.
- **Prose, photos, provenance, and `occurredAt` stay editable.** The
  *"closures are final"* rule (`Intention.close`) guards verdicts; a moment is
  the user's own words and follows the user. `createdAt` and the owning
  aspiration never change.
- **Deletion** is always available and cascades photos only.

## Location — asked once per moment

Location is **pull, never push**: the composer carries an *Add location*
chip; nothing is captured without that tap, on every single moment.

- Tapping the chip runs a one-shot `requestLocation()` (When-In-Use
  authorization, `kCLLocationAccuracyHundredMeters` — a place label needs no
  more) and **one** `CLGeocoder` reverse-geocode; the result is stored as
  `latitude`/`longitude` plus a short `placeName` ("Golden Gate Bridge,
  San Francisco" — best-effort name + locality). Display renders the stored
  string and never geocodes again; a failed or offline geocode keeps the
  coordinates with an empty name and the chip reads a generic "Location".
- iOS's own **"Allow Once"** grant composes exactly with the intent: a user
  who picks it is re-asked by the system each session, and the app never
  escalates (no Always, no background, no significant-change monitoring).
- Consent is the tap, so it is also the honesty check: composing a backdated
  moment at home about Tuesday's summit, the user simply doesn't tap. Stored
  location is **removable but never re-fetchable** — a later fetch would lie
  about where it happened. No map picker, no location search (out of scope).
- If permission is denied, the chip renders disabled with a one-line footnote
  and an Open Settings link — shown only inside the composer the user already
  opened; never an alert, never proactive.
- **All CoreLocation code lives in the iOS target** (a small `@Observable`
  `MomentLocationReader` beside the other app-only services) — `Shared/`
  stays CoreLocation-free, so the Linux overlay and the watch build are
  untouched. The iOS target gains one build setting, following the FaceID /
  Health precedent:
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Your location is used
  only to label the moments you choose to keep. It is never tracked in the
  background and never leaves your iPhone."`

## Photos

- The composer reuses the `PhotosPicker` + `loadTransferable(type: Data.self)`
  pattern from `AspirationFormView`, with multiple selection and a **soft cap
  of 4** photos per moment (enforced in the composer, not the schema).
- Unlike the one-off aspiration cover, moment photos accrue for a lifetime, so
  the composer downscales on import: longest edge ≤ 2048 px, re-encoded JPEG
  (~0.8 quality) before the bytes reach `MomentPhoto.data`.
- Photos render as thumbnails on the aspiration surfaces and in the in-app
  composer; tapping one opens an uncropped, full-screen viewer, with swiping
  between the moment's photos. The weekly review card shows at most a small
  photo glyph on the row (see below), never the images — the card stays light.
- A Photos share opens a dedicated new-Moment composer inside LeadStone's
  Share Extension. The extension accepts at most four images, lets the user
  remove any of them, requires an aspiration and text, and saves directly to
  the app-group SwiftData store. It does not use unsupported attempts to
  foreground the containing app from another app's share sheet.
- The live Week screen offers an exact trailing-seven-day PhotoKit grid. It
  asks for library access only after a tap, supports limited-library access,
  and turns the selected images into an editable Moment draft. Selection alone
  never writes a Moment.

## UI surfaces

### Composer — `MomentFormView`

A sheet with: the text field (multi-line, the only required field), the
`occurredAt` picker, the *Add location* chip, the photo picker, and an
optional provenance picker (None / a metric / a project). Capture from an
aspiration surface is born bound to that aspiration and lists its attachments
first. A draft started from Week has no owner yet, so the same composer shows
an aspiration picker and requires exactly one before Keep becomes available.
The owner is fixed after creation. The verb everywhere is **Keep** ("Keep a
moment", primary button "Keep") — the counterpart of an intention's *let
go*. Editing an existing moment opens the same sheet without changing its
owner.

The Share Extension mirrors the essential new-Moment fields — aspiration,
text, date, and removable photos — in its own process. Because supported Share
Extension APIs cannot force-open their containing app, completing this small
composer is the automatic Photos-to-Moment path.

### Aspiration detail — the evidence above the question

A new **Moments** section in `AspirationDetailView`, between `whySection` and
`pulseSection` — deliberately: the reader scrolls past what grew before the
Pulse asks whether the effort still serves the why.

- The three most recent moments (newest first): text, relative day, place
  chip when present, thumbnail strip when photos exist. Tapping a row opens
  the composer in edit mode; swipe deletes (confirmation for moments with
  photos).
- A **Keep a moment** affordance in the section header — the always-available
  capture point.
- When more than three exist, a plain **All moments** link pushes
  `MomentListView`: the full timeline, newest first, day-labelled, photos and
  places inline, swipe-to-delete. No count in the link label, ever.
- Empty state: the header, one quiet line ("Nothing kept yet."), and the Keep
  affordance. The section never begs.

### Weekly review — moments on the aspiration card

Assembly follows the check-in integration pattern exactly, and stays pure and
Linux-testable:

- `WeeklyReview.build(...)` gains a defaulted `moments: [Moment] = []`
  parameter after `checkIns` — every existing call site and test stays
  byte-identical.
- `AspirationWeekContext` gains the passed moments; `AspirationWeek` gains
  `moments: [MomentLine]`, with `MomentLine` (id, text, `occurredAt`,
  `placeName`, `hasPhotos`) defined in `WeeklyReviewModels.swift` beside
  `IntentionLine`.
- **Windowing:** a moment belongs to the reviewed period when `occurredAt`
  falls inside `PeriodBounds` under the same half-open rules as sessions
  (`occurredAt >= start && occurredAt < end`) and its aspiration owns the
  card. Ordered ascending — the card reads as the week's chronicle.
- **A moment stages a quiet aspiration.** The staging guard in
  `aspirationWeek(_:context:)` extends to
  `sessionCount > 0 || !intentions.isEmpty || awaitsClosure ||
  !moments.isEmpty`. This is the intention precedent, not a doctrine breach:
  *content the user created* stages; *pending prompts* (an unanswered
  check-in) never do. A week whose only event is "finished my first 10k" is
  the week's most important card.
- **Past weeks show moments.** Intention lines and the check-in block are
  live-week-only because they are *machinery*; moment rows are pure narrative
  display — precisely what browsing an old week is for.
- On `AspirationWeekCard`, moment rows render between the intentions block
  and the Pulse block (content before prompts): relative day, text, place,
  and at most a small photo glyph. Rows are display-only on the card; photos
  are viewed on the aspiration's own screen. The **live** week's card ends
  the block with one quiet **Keep a moment** affordance (opening the composer
  pre-bound to that aspiration); it never appears on browsed weeks, never
  stages a card by itself, and skipping it is invisible.

### Weekly review — recent-photo capture

The live review also carries a quiet **Photos from the last 7 days** section.
It is capture, not an insight: tapping it requests Photos access and shows only
image assets whose creation date falls in the review's half-open
`start ..< end` window. Up to four selected images seed one new Moment draft,
ordered chronologically and dated from the earliest successful selection. The
user still chooses the aspiration, writes the testimony, can remove photos,
and explicitly taps Keep. Browsed historical weeks never offer this capture
surface.

## Chosen defaults

Resolved here so v1 is unambiguous; each is easily changed later:

1. **Exactly one aspiration per moment**, fixed at creation.
2. **Verb = Keep**; section title = "Moments".
3. **All windows and orderings key on `occurredAt`** (review: ascending;
   detail and timeline: newest first); `occurredAt` ≤ now, editable.
4. **A moment stages a quiet aspiration** on the review.
5. **Photos: child `MomentPhoto` model, soft cap 4, downscaled on import.**
6. **Location: per-moment explicit fetch, one geocode at capture,
   remove-only afterwards; hundred-meter accuracy.**
7. **No counts of moments are displayed anywhere in the app's UI** — a
   design invariant, not a default (with #8 the doctrine mirror of
   check-ins); the markdown export's range inventory line is the sole,
   deliberate exception (see Principles 2 and 4).
8. **No notifications, badges, streaks, or completion accounting on
   moments — ever.**

## Out of scope

Deferred to later follow-ups:

- **Resurfacing** ("From last spring: …" — a remembered moment on the review
  card or Today). The strongest v2: it closes the motivational loop, and it
  deserves its own care so it never becomes a slot machine.
- Session → moment promotion after a timer stops; check-in-note → moment
  promotion. (Both capture flows stay frictionless and untouched.)
- Moments in the aspiration week drill-in (`AspirationWeekDetailView`).
- CSV export/import of moments; iCloud/backup tooling.
- Watch capture or display; widget surfaces.
- A map view; manual location search or post-hoc location editing.
- Many-to-many aspiration links; moving a moment between aspirations.

## Acceptance criteria

- [ ] `Moment` + `MomentPhoto` compile on iOS, watchOS, and the Linux overlay
      (`swift build` / `swift test`); registered in `SharedModelContainer`
      and the `#Preview` container; a pre-feature store opens clean with an
      additive migration.
- [ ] A store with zero moments opens without migration or backfill; all
      existing `WeeklyReview` histories remain valid.
- [ ] Keeping works from `AspirationDetailView` and from the live review
      card; capture requires text plus an aspiration when not already bound,
      caps `occurredAt` at now, backdates freely, keeps bound owners fixed, and
      shows the aspiration picker only for an unbound Week draft.
- [ ] Photos shared from another app immediately open the Share Extension's
      new-Moment composer; up to four photos can be added or removed, and save
      requires text plus exactly one aspiration.
- [ ] The live Week screen can select accessible image assets from its exact
      trailing-seven-day window and seed an editable Moment; denied, limited,
      empty, partial-failure, and iCloud-backed states are visible to the user.
- [ ] Deleting an aspiration cascades its moments and photos; deleting a
      linked metric or project nullifies provenance and the moment survives;
      deleting a moment touches nothing else.
- [ ] Location is captured only on the explicit per-moment tap: one fetch,
      one reverse-geocode, stored as doubles + text; removable, never
      re-fetched; no CoreLocation import anywhere under `Shared/`.
- [ ] Review windowing is half-open on `occurredAt`, owner-filtered, shown on
      live *and* browsed weeks; a moment alone stages its aspiration; the
      Keep affordance appears on the live week only (unit-tested on Linux,
      including the staging and boundary cases).
- [ ] No surface renders a count of moments; no notification, badge, or
      prompt machinery references them (doctrine tests where practical).
- [ ] New unit-test files are wired into `project.pbxproj` (test files are
      not auto-included); `swiftlint` and `swiftformat --lint .` pass.
