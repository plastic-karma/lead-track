# AGENTS.md

Instructions for coding agents working in this repo. Read [CLAUDE.md](CLAUDE.md)
before planning or editing; it is authoritative for the build, lint, architecture,
and toolchain constraints. This file defines the delivery pipeline for every task
that changes repository files.

## Change delivery pipeline (run it — don't ask)

Writing the change is not the end of the task: the task is done only when it has
gone through this pipeline. Never ask
"should I create a PR?", "should I run CI?", or "should I trigger the release?" —
run every applicable step without confirmation and report the results.

1. **Start clean, branch, and verify locally.** Inspect the worktree first and
   preserve unrelated changes. For a clean new task, start on a dedicated branch
   from the current remote base, never on another task's branch:

   ```bash
   set -euo pipefail
   test -z "$(git status --porcelain)"
   git fetch origin main
   git switch -c agent/short-description origin/main  # replace short-description
   ```

   When continuing an existing task or PR, stay on its branch after verifying its
   upstream, base, and diff; do not create a duplicate branch or PR.

   Before every push run `swiftlint`, `swiftformat --lint .`, and `swift test`.
   On Linux, `swift test` covers the SwiftPM overlay described in `CLAUDE.md`; the
   macOS CI job is the authority for the full Xcode project build and any simulator
   tests available on its runner.

2. **Open a PR.** This triggers CI (`.github/workflows/ios.yml`) automatically:

   ```bash
   git push -u origin HEAD
   gh pr create --base main --fill
   ```

3. **Watch CI and iterate until green.** Do not hand a red build back to the user:

   ```bash
   gh pr checks --watch --fail-fast
   ```

   "No checks reported" is not green; wait briefly and rerun until checks register.
   Both `Lint, build & test (iOS)` and
   `Build & test (Linux SwiftPM)` must pass for the current PR head. On failure,
   read the logs (`gh run view <run-id> --log-failed`), fix, run the local gates,
   push, and watch again. Repeat until all checks pass. Only involve the user for
   failures that cannot be fixed from the repo (for example Apple account
   agreements, secrets, or App Store Connect state); see `docs/RELEASE.md` for
   known signing and upload failures.

4. **Release to TestFlight.** Once CI is green, dispatch the release workflow from
   the PR branch with TestFlight publishing enabled, and watch the exact run it
   creates. First prove that the release commit is current, clean, and identical
   to the pushed PR head, and that no other release is active:

   ```bash
   set -euo pipefail
   git fetch origin main
   git merge-base --is-ancestor origin/main HEAD
   test -z "$(git status --porcelain)"
   branch="$(git branch --show-current)"
   sha="$(git rev-parse HEAD)"
   pr_sha="$(gh pr view --json headRefOid --jq .headRefOid)"
   test "$sha" = "$pr_sha"
   active_releases="$(gh run list --workflow=release.yml --limit 100 \
     --json status --jq 'map(select(.status != "completed")) | length')"
   test "$active_releases" = 0
   ```

   If that check fails, incorporate the current `origin/main`, then repeat the
   local gates, push, and CI watch. Merge the base into an already-published branch;
   rebase only before the first push or when rewriting its remote history is
   explicitly safe. Release only a same-repository branch whose complete diff you
   authored or reviewed for this task. Never dispatch untrusted or fork-derived
   code: the selected ref controls workflow and repository code that runs with App
   Store Connect credentials. Do not knowingly overlap release runs; the workflow
   serializes only within one ref, not across the repository.

   The current GitHub CLI returns the exact run URL when available. Keep a
   commit/event/time-scoped fallback for hosts that do not return it:

   ```bash
   set -euo pipefail
   branch="$(git branch --show-current)"
   sha="$(git rev-parse HEAD)"
   dispatched_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   run_url="$(gh workflow run release.yml --ref "$branch" -f publish_testflight=true)"
   case "$run_url" in
     */actions/runs/[0-9]*) run_id="${run_url##*/}" ;;
     *) run_id="" ;;
   esac
   for _ in {1..30}; do
     [ -n "$run_id" ] && break
     run_id="$(gh run list --workflow=release.yml --branch "$branch" \
       --commit "$sha" --event workflow_dispatch --created ">=$dispatched_at" \
       --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
     [ -n "$run_id" ] || sleep 2
   done
   [ -n "$run_id" ] || { echo "Release run did not register" >&2; exit 1; }
   run_sha="$(gh run view "$run_id" --json headSha --jq .headSha)"
   test "$run_sha" = "$sha"
   gh run watch "$run_id" --exit-status
   gh run view "$run_id" --json url,headSha,conclusion
   ```

   Iterate on fixable failures through the local and CI gates before dispatching a
   new release. A successful upload means App Store Connect accepted it; TestFlight
   availability still waits on Apple's processing.

5. **Report.** Summarize the PR link, both CI job conclusions, and either why
   TestFlight was skipped or the release run URL/ID, head SHA, and upload status.
   Merging the PR stays with the user.

Scope: step 4 applies when any part of the diff changes shipped app source, assets,
entitlements, runtime configuration, `ExportOptions.plist`, or an app target's
Xcode project/build configuration. Skip TestFlight only when the entire diff is
docs, tests, CI workflows/scripts, or repository tooling; mixed diffs release.
Skipped changes still require a PR and green CI.
