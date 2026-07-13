# Screen Time limit metrics (breach-counted)

> **Status: exploration / design.** Nothing below is built yet. This doc
> scopes how to add "stay-under-a-daily-ceiling" metrics backed by Apple's
> Screen Time (DeviceActivity) API, and — importantly — flags the one hard
> external blocker (a privileged Apple entitlement) before any code lands.

## The ask

> "A metric that has a max limit — e.g. only 30 min of entertainment per day.
> Count not the values but count them as **binary (breached vs not breached)**
> in stats."

Today every target in the app is an **at-least** target: `dailyGoal` /
`weeklyGoal` and the binary "show up today" expectation all mean *reach this
amount* (`GoalSummary.isDailyMet` → `today >= dailyGoal`). There is no
**ceiling / stay-under** notion anywhere. This is that inverted target, fed by
the OS rather than by hand.

## The headline finding: the API is binary *by design*

A third-party app **cannot read raw Screen Time usage numbers**. The
DeviceActivity report data (actual minutes per app) is only ever handed to a
sandboxed `DeviceActivityReport` SwiftUI extension that **cannot write to
storage or make network calls**, specifically so the host app can never
extract the value. The *only* usage signal your app process receives is a
threshold-crossing callback:

> Register a `DeviceActivityEvent` with a `threshold` (a `DateComponents`
> duration) over a set of apps/categories. When cumulative usage reaches that
> threshold within the monitored window, iOS calls
> `DeviceActivityMonitor.eventDidReachThreshold(_:activity:)` in an extension.

So "count them as binary, not the values" is not a design compromise we're
choosing — **binary breached/not-breached is the only thing the platform will
give us.** The requirement and the API line up exactly. That is what makes this
feature tractable at all.

## How the Apple pieces wire together

Four frameworks, in the order data flows:

1. **FamilyControls — authorization + app picking.**
   - `AuthorizationCenter.shared.requestAuthorization(for: .individual)` — a
     one-time system prompt. `.individual` (iOS 16+) authorizes the current
     user on their own device; it does *not* require a parental-controls /
     Family Sharing setup, and any number of apps per device may hold it. Our
     deployment target (iOS 26.2) is well clear of the floor.
   - `FamilyActivityPicker` (SwiftUI) lets the user choose apps / categories
     (e.g. the whole **Entertainment** category). It yields a
     `FamilyActivitySelection` of **opaque tokens** (`ApplicationToken`,
     `ActivityCategoryToken`) — never bundle IDs or names we can read. It is
     `Codable`, so we persist it as `Data` on the metric.

2. **DeviceActivity — the schedule + the threshold event.**
   ```swift
   let event = DeviceActivityEvent(
       applications: selection.applicationTokens,
       categories: selection.categoryTokens,
       webDomains: selection.webDomainTokens,
       threshold: DateComponents(minute: 30)        // the ceiling
   )
   let schedule = DeviceActivitySchedule(
       intervalStart: DateComponents(hour: 0, minute: 0),
       intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
       repeats: true                                // resets every day
   )
   try DeviceActivityCenter().startMonitoring(
       .init("limit-\(metric.stableID!.uuidString)"),
       during: schedule,
       events: [.init("breach"): event]
   )
   ```

3. **DeviceActivityMonitor extension — where the breach is observed.** A new
   app-extension target subclassing `DeviceActivityMonitor`:
   ```swift
   final class LimitMonitor: DeviceActivityMonitor {
       override func eventDidReachThreshold(
           _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
       ) {
           // activity name carries the metric's stableID → record today as breached
           BreachLog.shared.markBreached(activity: activity, on: .now)
       }
       override func intervalDidStart(for activity: DeviceActivityName) {
           BreachLog.shared.beginDay(activity: activity, on: .now)   // fresh day
       }
   }
   ```
   The extension and the app talk **only** through the App Group we already
   have (`group.plastickarma.lead-track`, `Shared/Services/AppGroup.swift`) —
   `BreachLog` is just a `UserDefaults(suiteName:)` writer keyed by metric ID
   and day. The extension runs briefly, cannot touch the network, and should
   not open the SwiftData store; a tiny defaults dictionary is the right
   channel.

4. **ManagedSettings — optional enforcement (not required by the ask).** If we
   ever want the limit to *block* rather than merely *count*, the same
   extension can call `ManagedSettingsStore().shield.applications = tokens` on
   breach to shield the apps for the rest of the day. The ask is
   count-only, so this is a clearly-separable later phase.

The app side reads the breach flags on foreground (and via a background
refresh), the same way `HealthDailyMirror` pulls HealthKit — see the data model
below.

## Data-model fit: a system-fed, inverted-binary metric

Two properties of a Screen Time limit metric map cleanly onto things the repo
already does:

- **It is "system-fed," like a HealthKit-mirrored metric.** The user never
  hand-logs a breach; the OS does. The repo already has exactly this shape:
  `Metric.isHealthLinked` disables manual logging, drops watch actions
  (`WatchActionHandler` line ~17), and marks the metric as filled-from-a-source.
  A Screen Time limit is another *linked source* — reuse that pattern rather
  than inventing a parallel one.
- **A day is binary — but success is inverted.** A breached day is a `Session`
  with `value = 1`, so the entire `SessionStatistics` → `DailyTotal` pipeline
  works **unchanged** (a day totals 0 or 1). What flips is the *reading*: for a
  normal `.binary` habit, `1` = good (did it); for a limit, `1` = **bad**
  (blew the ceiling). So streaks/"met" invert: a good day is one with **no**
  breach session, and the streak is *days since the last breach*.

### New `Metric` fields (all additive, migration-free)

Per `CLAUDE.md`'s SwiftData rule, every new stored field is `Optional` or
defaulted so existing stores migrate untouched, and stays cross-platform:

```swift
/// Encoded FamilyActivitySelection (apps/categories this limit watches).
/// Stored as Data — FamilyControls is Apple-only, so the Shared model keeps
/// it opaque and decodes behind `#if canImport(FamilyControls)`, exactly like
/// the `#if canImport(SwiftData)` guards already in this file.
var screenTimeSelection: Data?
/// The daily ceiling in minutes (e.g. 30). nil until configured.
var screenTimeLimitMinutes: Int?
/// When the OS monitor last confirmed it was watching this metric.
var lastScreenTimeSyncAt: Date?
```

### Discriminating the kind

Recommended: add a case to `MeasurementType` (`Shared/Models/MeasurementType.swift`):

```swift
enum MeasurementType: String, Codable, CaseIterable {
    case duration
    case count
    case binary
    case screenTimeLimit   // OS-fed daily ceiling; a day is breached(1)/clear(0)
}
```

`tracksQuantity` stays `false` for it (no magnitude the user enters). This is
cleaner than overloading `.binary` with a side flag, but it is a **contract**:
`screenTimeLimit` must be handled at every existing switch site the map turned
up —
- `ValueFormatter` (display: "2 days over" / "under limit today"),
- `GoalSummary.isDailyMet` (inverted: met = *no* breach today),
- `ComplicationProgress.fraction` (breached → full-red ring, else clear),
- `WatchMetricSnapshot` mirror methods + `WatchSnapshotBuilder`,
- `MetricFormKind` (a new "Screen Time limit" choice, disabled-on-edit like the
  others).

### Recording path (parallel to `HealthDailyMirror`)

A new `Shared/Services/ScreenTimeBreachMirror.swift` (the Apple-only wiring in
`lead track/Services/…`, excluded from the SwiftPM overlay in `Package.swift`):
on foreground it reads the App Group breach flags and, for any flagged day that
has no breach `Session` yet, inserts one (`value: 1`, dated to that day). Idempotent,
so re-running never double-counts. Streaks and "days over this week" then fall
straight out of the existing aggregates, read with inverted polarity.

### Stats the user sees

- **This week:** "Over limit 2 / 7 days" (count of breach days) — reuse
  `windowedSessionCount` / `DailyTotal`.
- **Streak:** *days under the limit* = inverted `currentStreak` (days since last
  breach). The best-run/"longest streak" becomes "longest clean run."
- **Trends chart:** already renders binary as discrete day marks; here each
  breach day is a red mark and clear days are empty — "how often did I blow it."
- The exact minutes used are **never** shown in our stats (we can't read them).
  If we want a live "22 / 30 min" ring for the user's eyes only, that requires a
  separate `DeviceActivityReport` extension whose number the app still cannot
  read — a nice-to-have, orthogonal to the binary stats.

## The blockers (read before committing to a timeline)

1. **Privileged entitlement — the real gate.** `com.apple.developer.family-controls`
   is a *restricted* entitlement. The **development** variant can be toggled on
   in Signing & Capabilities and works on device/simulator immediately, but the
   **Distribution** variant needs a manual approval request to Apple
   (`developer.apple.com/contact/request/family-controls-distribution`), **per
   bundle ID and per extension target**, with reported turnarounds from a couple
   of days to 6+ weeks. **Without it, no distribution/TestFlight/App Store build
   will sign.** That collides head-on with the mandatory PR → CI → TestFlight
   pipeline in `AGENTS.md`: the `release.yml` TestFlight step would fail until
   Apple grants the entitlement for both the app and the new monitor extension.
   → *The domain model + inverted-binary stats can be built and unit-tested now
   (they're pure `Shared/` logic, green on Linux CI). The actual Screen Time
   wiring cannot reach TestFlight until the entitlement is approved.*

2. **A new Xcode target.** The DeviceActivityMonitor extension is a fourth
   target (`.appex`) with its own entitlement, App Group membership, and
   Info.plist (`NSExtensionPointIdentifier = com.apple.deviceactivity.monitor-extension`).
   Editing the `.pbxproj` is a real change, outside the SwiftPM overlay, so it's
   only validated by the `macos` CI job, never on Linux.

3. **No raw numbers, ever.** Reinforces binary-only stats (see above). The
   "30 min" shown is the ceiling the user *set*, not measured usage.

4. **Device-only, phone-sourced, flaky on Simulator.** Threshold events are
   unreliable-to-absent on the Simulator and need real-device testing; multiple
   Apple Forum threads report events firing immediately or not at all on some
   iOS builds. Screen Time is per-device and privacy-siloed — fits the app's
   "phone is source of truth" model; the watch only *displays* the breach state.

## Suggested phasing

- **Phase 0 (buildable + testable today, no entitlement):** add the
  `MeasurementType.screenTimeLimit` case, the three `Metric` fields, the
  inverted "met"/streak logic in `GoalSummary`/`SessionStatistics`, and the
  breach-`Session` mirror service — all pure `Shared/` code with unit tests
  (`swift test` on Linux + macOS CI). No Screen Time API calls yet; a debug
  affordance can fake a breach flag to exercise the stats end-to-end.
- **Phase 1 (needs dev entitlement + real device):** FamilyControls
  authorization, the `FamilyActivityPicker` in `MetricFormView`, event
  registration via `DeviceActivityCenter`, and the DeviceActivityMonitor
  extension writing flags to the App Group.
- **Phase 2 (needs Distribution entitlement):** ship to TestFlight once Apple
  approves both targets. Optional: `ManagedSettings` shielding to *enforce* the
  limit, and a `DeviceActivityReport` ring for the user's own eyes.

## Open decisions for the user

- Dedicated `MeasurementType.screenTimeLimit` case (recommended, cleaner
  semantics, more switch sites) **vs.** reuse `.binary` + an inversion flag
  (less churn, muddier).
- Count-only (the literal ask) **vs.** also *shield/block* the apps on breach
  (`ManagedSettings`, Phase 2).
- Whether to pursue the Distribution entitlement at all — it's the difference
  between "shippable feature" and "local prototype only."
