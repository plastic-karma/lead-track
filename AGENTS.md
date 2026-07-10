# AGENTS.md

Instructions for coding agents working in this repo. Build, lint, architecture, and
toolchain docs live in [CLAUDE.md](CLAUDE.md); this file defines the delivery
pipeline that follows every implementation task.

## Feature delivery pipeline (run it — don't ask)

When you implement a feature or fix, writing the code is not the end of the task:
the task is done only when the change has gone through this pipeline. Never ask
"should I create a PR?", "should I run CI?", or "should I trigger the release?" —
the answer is always yes. Run the steps and report the results.

1. **Branch & verify locally.** Work on a branch off `main`. Before every push run
   `swiftlint`, `swiftformat --lint .`, and `swift test`.

2. **Open a PR.** This triggers CI (`.github/workflows/ios.yml`) automatically:

   ```bash
   git push -u origin HEAD && gh pr create --fill
   ```

3. **Watch CI and iterate until green.** Do not hand a red build back to the user:

   ```bash
   gh pr checks --watch --fail-fast
   ```

   On failure, read the logs (`gh run view <run-id> --log-failed`), fix, push, and
   watch again. Repeat until all checks pass. Only involve the user for failures
   that cannot be fixed from the repo (expired Apple agreements, secrets,
   App Store Connect account state — see `docs/RELEASE.md`).

4. **Release to TestFlight.** Once CI is green, dispatch the release workflow from
   the PR branch with TestFlight publishing enabled, and watch it to completion:

   ```bash
   branch="$(git branch --show-current)"
   gh workflow run release.yml --ref "$branch" -f publish_testflight=true
   sleep 15  # let the dispatched run register
   gh run watch --exit-status \
     "$(gh run list --workflow=release.yml --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId')"
   ```

   Iterate on failures the same way as CI. When the upload succeeds, the build
   appears in TestFlight after App Store Connect finishes processing.

5. **Report.** Summarize the PR link, CI result, and TestFlight upload status.
   Merging the PR stays with the user.

Scope: step 4 applies to changes that affect the app itself. For docs-only or
CI-only changes, still open the PR and get CI green, but skip the TestFlight
release.
