# lead track

**LeadStone** — a personal effort-tracking app for iOS, built with SwiftUI + SwiftData. Metrics, projects, and sessions record the effort you pour in; aspirations, intentions, moments, and principles hold the why. The iPhone UI is a page-style three-tab shell (Today / Week / Aspirations); a watchOS companion starts timers and logs counts from the wrist, and widget extensions surface metrics on the home screen and watch face.

The app ships under the display name **LeadStone**; "lead track" is the internal project, scheme, and bundle name (`plastickarma.lead-track`) used throughout this repo.

Read saved Moments, intention narrative, check-in notes, and unit-separated effort
through [period retrospectives and opt-in Moment rediscovery](docs/MOMENTS.md#period-retrospectives).
[Set aside an aspiration](docs/ASPIRATIONS.md#set-aside-and-bring-back) without
deleting its history or hiding shared work; bring it back when it matters again.

## Requirements

- Local source-built [xtool native release tools](https://github.com/plastic-karma/xtool/blob/main/Documentation/xtool.docc/NativeReleases.md)
- Darwin SDKs imported from your Xcode archive; builds do not run Xcode
- Swift 6.4.0 compiler, Swift 5 application language mode
- iOS 26.2 / watchOS 26.2 deployment targets

No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, Foundation).

## Build & Run

Build the complete iOS/watchOS application locally:

```sh
./scripts/build-release.sh --prepare-only  # Import the canonical Xcode project.
./scripts/build-release.sh --unsigned      # Full ad-hoc smoke IPA; no upload.
./scripts/build-release.sh --upload        # Distribution build and TestFlight upload.
```

Set `XTOOL` to the source-built CLI or a local environment launcher if it is not
on `PATH`. The build preserves the iPhone app, iPhone widget, share extension,
Watch app, and Watch widget, including both Watch device architectures.

See [the local release guide](docs/RELEASE.md) for setup, external signing,
artifacts, and Apple processing/tester-access checks. Keep credentials outside
the repository. An unsigned smoke IPA is not TestFlight-installable, and a
successful build does not prove device behavior.

## Optional Obsidian / GitHub sync

LeadStone still works entirely offline with its local SwiftData store. GitHub
sync is off until you enable it in **Settings → Obsidian & GitHub**.

1. Use an existing GitHub repository and branch containing your Obsidian vault;
   the repository root should be the vault root. Initialize an empty repository
   with a commit first.
2. Enter the owner, repository, branch, and a nonempty vault subdirectory such
   as `LeadStone` or `Notes/LeadStone`. Tap **Continue with GitHub**, review the
   sensitive-data notice, and confirm **Agree & Continue to GitHub**.
3. The form scrolls to a large **GitHub verification code** as soon as it arrives;
   no copy or browser tap is required to reveal it. Keep LeadStone open and enter
   that code at [github.com/login/device](https://github.com/login/device) on a
   computer or tablet, then approve **LeadStone**. Alternatively, use **Copy Code**
   and **Open GitHub** on the iPhone, then return to the app. Copy, browser opening,
   and cancellation are separate controls; copying does not cancel sign-in.
   Successful authorization enables sync without creating or pasting an API token.
   The first sync combines existing local and remote records rather than replacing
   either collection. The selected folder can be created by this sync.
4. Pull the repository into Obsidian using your Git client. Push Obsidian edits
   back to that branch; LeadStone reads them on foreground/save-triggered sync
   or **Sync Now**. This connects through GitHub, not directly to an Obsidian
   installation, and is not Obsidian Sync.

**Use a Manual Token Instead** remains available for a fine-grained personal
access token limited to that repository, with **Contents: Read and write**.
Existing token connections continue to work after updating.

### GitHub sign-in and build configuration

**Continue with GitHub** uses GitHub's
[OAuth Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow).
It requests the `repo` scope, which can authorize more repositories than the
one selected in LeadStone. LeadStone only synchronizes the configured
destination; use the optional fine-grained token for repository-limited
authorization. Organization OAuth restrictions or SAML SSO can require separate
approval from the organization.

Access and refresh tokens stay together in the device-only Keychain, never in
the vault or preferences. Expiring access tokens refresh before sync, and
rotating credentials are saved together before sync resumes. Losing connectivity
does not affect local recording. Canceling sign-in or leaving Settings discards
the attempt, while opening the GitHub browser page keeps it alive. GitHub may
ask for a passkey or two-factor confirmation there. An expired refresh token or
revoked authorization requires signing in again.

Temporary polling timeouts or connection loss keep the same device code and
retry with increasing delays until its original expiry. GitHub's “all set”
confirms browser approval; return to LeadStone and wait for **Two-way sync
enabled** to confirm the app completed sign-in. Cancellation, denial, expiry,
and TLS/certificate failures still stop the attempt. Remaining connection
failures show a numeric network error code, never credentials or server details.

The project and `xtool-release.yml` configure LeadStone's public
`GITHUB_CLIENT_ID`, emitted as `GitHubClientID` in the app's Info.plist. For a
separate app identity:

1. Register an OAuth App in **GitHub Settings → Developer settings → OAuth
   Apps**, using the app's name and HTTPS repository/homepage URL. The required
   redirect URI can be that same URL; Device Flow does not use a callback.
2. Enable **Device Flow** and retain **Expire user access tokens**. LeadStone
   handles the resulting access/refresh-token rotation.
3. Set that app's public client ID in the project's Debug/Release
   `GITHUB_CLIENT_ID` build setting and the native release manifest's
   `settings.GITHUB_CLIENT_ID`. Do not generate or embed a client secret.

### Vault layout and editing

The selected directory contains `Aspirations/`, `Metrics/`, `Projects/`, `Data/`,
`Principles/`, `Intentions/`, `CheckIns/`, `Moments/`, `Photos/`, and
`Attachments/`. Each record is a small Markdown file, initially named with its
stable UUID; each measurement/session gets its own file in `Data/`, not a row
inside a monolithic export.

Every managed note has `leadstone_id`, `leadstone_type`, and
`leadstone_version: 1` in YAML frontmatter. Keep these identifiers intact.
Aspirations link to their metrics/projects; datapoints link to their metric
and optional project; the remaining records link to their related notes using
Obsidian wikilinks. For example, a count datapoint has this shape:

```yaml
---
leadstone_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
leadstone_type: "session"
leadstone_version: 1
aliases: ["Reading · 2026-10-02T09:00:00Z"]
metric: "[[aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa]]"
project: null
started_at: "2026-10-02T09:00:00.000Z"
ended_at: "2026-10-02T09:00:00.000Z"
countdown_duration: null
value: 5
---
```

Edit an aspiration's Markdown body to change its description in LeadStone; a
metric's body is its description. Principle, intention, check-in, and Moment
prose also lives in the body. Scalar properties such as `title`, `name`, `unit`,
`value`, and ISO-8601 timestamps live in frontmatter. Keep required fields and
relationship targets valid. Renaming a note is supported when its stable ID
stays intact; let Obsidian update its links.

Nine [Obsidian Bases](https://help.obsidian.md/bases) files sit beside these
folders, including `Aspirations.base`, `Metrics.base`, and `Data.base`.
Their scoped tables use readable, clickable record titles and expose the
relevant relationships and measurement properties. Existing `.base` files are
never overwritten, so their layouts and formulas can be customized.

### Reconciliation and privacy

- Local changes remain usable offline. Sync uses a destination-specific durable
  journal, a three-way merge, and atomic Git commits tied to the fetched branch
  head; it never force-pushes over someone else's commit.
- Independent property edits merge. Competing edits and delete-versus-edit
  changes pause for explicit choices in Settings. Newer edits invalidate old
  choices instead of silently applying them to different content.
- Remote deletions propagate once relationships remain valid. Malformed notes,
  broken required links, unsupported schema versions, unsafe paths, and partial
  remote snapshots stop reconciliation rather than importing a partial graph.
- A local session can inherit its metric from its project. Export writes both
  links explicitly without changing its ID, timestamps, or value. Conflicting
  owners, unresolvable metrics, invalid values, and multiple running timers for
  one metric still stop sync; no session is skipped to bypass validation.
- Unrelated notes, custom YAML properties, unchanged Markdown prose, and
  user-customized Bases are retained. Files outside the selected directory are
  not modified. Shared image references are retained when another note still
  uses the attachment.
- Access and refresh tokens stay in this device's Keychain. Health connections/export settings,
  notification schedules, app privacy preferences, and credentials are not
  transferred. Recorded values—including Health-derived values—notes, photos,
  and saved locations **are** uploaded when you opt in. Prefer a private
  repository: Git history can retain content after a later deletion.
- **Disconnect** disables syncing and removes this device's stored credentials
  without deleting local records or repository files. Reconnecting to the same
  destination keeps its reconciliation history. To revoke GitHub authorization
  itself, use **GitHub Settings → Applications → Authorized OAuth Apps**;
  revocation can affect other devices using that authorization.

GitHub authentication/rate limits, protected branch rules, and network failures
are shown in Settings without blocking ordinary recording. The transport has
explicit bounds: 25 MiB per blob and per commit's added content, 128 MiB per
downloaded folder snapshot, and 10,000 tree entries. Larger vault slices need
to be reduced before they can synchronize.

## Project Layout

- `lead track/` — iOS app sources
- `lead-track Watch App/` — watchOS app sources
- `lead-track Widget/` — iOS widget extension
- `lead-track Watch Widget/` — watchOS widget/complications extension
- `lead-track Share Extension/` — iOS share extension
- `Shared/` — models, services, and watch-sync logic used by the phone, Watch app, and widget targets
- `lead trackTests/` — unit tests
- `lead trackUITests/` — UI tests
- `Package.swift` — SwiftPM overlay that builds and tests the platform-neutral subset of `Shared/` (plus most unit tests) on Linux: `swift build` / `swift test`; see CLAUDE.md "Building & testing on Linux"
- `docs/` — feature specs and the release guide
- `scripts/` — local xtool release launcher and app-icon generation
- `xtool-release.yml` — native release configuration; imports `lead track.xcodeproj`

## SwiftUI maintenance conventions

- Give meaningful screen sections and lazy-list rows concrete `View` types with
  narrow inputs. Keep small repeated fragments inline when they have no separate
  update boundary; avoid caches that can go stale when SwiftData relationships
  change.
- Own view-local state privately. UI-facing observable controllers use
  `@MainActor` and `@Observable`; non-UI bookkeeping does not participate in
  observation. Create provider/location readers in lifecycle or explicit action
  handlers, not during parent view construction.
- Identify movable rows by the model or calendar date. Photo presentations
  snapshot distinct occurrences once, so duplicate image bytes still have
  different identities. Fixed weekday/bar slots may retain positional identity.
- Prepare thumbnail availability in lifecycle work and omit malformed photos
  before building the tappable strip. Full-resolution covers cache by exact
  bytes with four-entry and 64 MiB cost budgets, including stored bytes and
  estimated decoded pixels; never retain an unbudgeted history of cover edits.
- Use key-path bindings for direct state projections. Keep guarded/actionful
  closure bindings where deletion, uniqueness, or a transformation requires
  them. Reminder edits resolve a row by its durable ID, not its former index.
- Keep disk writes outside `body`. Export links prepare an immutable `ExportFile`
  with `.task(id:)` and hide the previous link as soon as its contents change;
  failed preparation must never offer a stale artifact.
- Prefer current APIs available at the deployment target and direct
  `.enumerated()` collections with Swift 6.4 rather than eager `Array` copies.
  Preserve privacy/authentication boundaries, countdown/recording semantics,
  and the English-only policy; format user-facing numbers and dates with format
  styles.

These boundaries are not a measured performance result. Native compilation and
portable tests do not exercise SwiftUI state retention, photo paging, extension
completion, or Watch delivery on devices; verify those workflows separately.

## Interface conventions

- Keep the copper-warm `Theme` surfaces, 20pt card corners, and 16pt card padding.
  Center dashboard and narrative columns at a maximum 680pt reading width rather
  than stretching cards across a wide window.
- Use semantic system fonts: serif for commitments and reflection, rounded
  monospaced digits for data. Let titles, provenance, and cover headings grow;
  provide stacked layouts and an external ring readout at accessibility sizes.
- Give custom controls at least 44pt touch targets without overlapping adjacent
  actions. Keep recording controls separate from detail-navigation links, and
  photo removal separate from photo viewing.
- Keep caption-sized labels in primary/secondary ink. Identity colors promise
  only 3:1 contrast in light mode and belong on icons, large numerals, washes,
  and selection outlines—not small readable labels.
- Use `Theme.photoOutline` for a neutral 1pt inset photo edge: black at 10% in
  light appearance, white at 10% in dark appearance. Do not duplicate strokes
  on both a shared thumbnail and its wrapper.
- Gate custom animations with `accessibilityReduceMotion`. Prefer static
  selected/recording cues over repeated pulses; haptics supplement the visible
  state rather than replace it.
- Name icon-only controls and numeric fields. Heatmap cells expose their date
  and correctly formatted measurement/unit, hide future days from accessibility,
  and retain all 16 weeks in a horizontally scrollable grid.

Native compilation and palette/data checks do not establish visual fit or
VoiceOver behavior. Verify small screens, iPad widths, light/dark appearance,
Increase Contrast, accessibility text sizes, Reduce Motion, photo actions, and
Watch complication fitting on devices.

## Linting

Use SwiftLint 0.63.3 and SwiftFormat 0.61.1 locally. Native xtool builds skip the validation-only Xcode linter phases, so run these explicitly:

```bash
swiftlint              # style and complexity checks
swiftformat --lint .   # formatting check
swiftformat .          # auto-fix formatting
```

## Local tests and delivery

```sh
swift test
```

The SwiftPM overlay tests portable domain logic on Linux. It does not execute
Apple's SwiftData/SwiftUI runtime or the UI-test target. Pair it with a complete
local xtool build for app changes and device testing where available.

Follow [AGENTS.md](AGENTS.md) and [CLAUDE.md](CLAUDE.md) for local gates and delivery.
GitHub is used only for source hosting and review: there are no Actions workflows,
hosted CI requirements, remote Xcode release jobs, or Codex Cloud bootstrap.
Commits, pushes, and tags do not build or upload the app.

## License

[MIT](LICENSE)
