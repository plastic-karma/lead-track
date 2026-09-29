# AGENTS.md

Instructions for coding agents working in this repo. Read [CLAUDE.md](CLAUDE.md)
before planning or editing for architecture, build, lint, and toolchain constraints.

## Local-only tooling

Build, sign, and upload the complete iOS/watchOS application locally with the
source-built xtool native release stack. Use `scripts/build-release.sh` and
`xtool-release.yml`; keep reusable compiler, SDK, resource, and signing tooling in
the xtool checkout/installation, not in this application repository.

Run SwiftLint, SwiftFormat, and the SwiftPM overlay tests locally. GitHub is for
source hosting and review only: do not add or dispatch GitHub Actions workflows,
wait for CI checks, use remote Xcode runners, or restore the old Codex Cloud
bootstrap. Missing local prerequisites are a setup problem, not a reason to
switch to cloud builds. See [docs/RELEASE.md](docs/RELEASE.md).

## Change delivery pipeline

1. **Preserve the worktree and task branch.** Inspect existing changes first;
   never discard unrelated work. Start a clean new task on its own branch from
   the current base. Continue an existing task on its branch instead of creating
   duplicate branches or PRs. Do not rewrite published history without approval.

2. **Verify locally.** Before every push, run:

   ```sh
   swiftlint
   swiftformat --lint .
   swift test
   ```

   Use the versions in `CLAUDE.md`. Fix failures without weakening the gates.
   Linux tests cover the portable overlay, not Apple's SwiftData/SwiftUI runtime.
   For changes to app code, assets, entitlements, or build configuration, also run
   a complete local build:

   ```sh
   ./scripts/build-release.sh --unsigned
   ```

   This compiles and verifies all five bundles, including both Watch device
   architectures. It produces an ad-hoc IPA, not a TestFlight-installable release.
   Docs/tooling-only changes need the relevant local command smoke checks, not a
   new TestFlight build. Keep generated files and artifacts under ignored `.xtool/`.

3. **Publish the reviewed change.** Commit and push the task branch and open or
   update its PR unless the user requests local-only edits. Do not wait for hosted
   checks or dispatch workflows. Merging the PR remains the user's decision.

4. **Deliver app-affecting changes through local TestFlight.** Unless the user
   explicitly asks to keep the existing build or not upload, finish changes to
   shipped app code, assets, entitlements, runtime settings, or app build
   configuration with:

   ```sh
   ./scripts/build-release.sh --upload
   ```

   Release a clean, committed, reviewed revision. Do not overlap local release
   runs. Keep signing identities, all five distribution profiles, and App Store
   Connect authentication outside the repository. Use the existing protected
   identity; never automatically revoke certificates, expire existing builds,
   change tester groups, or submit a public App Store release. See the release
   guide for setup and Apple processing/access checks.

   Skip upload for docs, tests, or repository-tooling-only changes. Preserve the
   working TestFlight build when upload is out of scope. If local signing or Apple
   account prerequisites are missing, report the exact blocker after completing
   reachable local checks; do not fall back to GitHub Actions.

5. **Report evidence and limits.** Include the commit/PR when published, actual
   local check results, artifact path and bundle/architecture verification for a
   build, and the version/build plus Apple processing and tester-access results
   for an upload. Otherwise state why TestFlight was skipped. Compilation and
   Apple acceptance do not establish device behavior: exercise persistence,
   Watch sync, widgets, sharing, AppIntents, and protected capabilities on devices
   when available, and explicitly report any runtime verification gap.
