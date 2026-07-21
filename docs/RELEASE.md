# Releasing — building an App Store `.ipa` from GitHub

The [`Release IPA`](../.github/workflows/release.yml) workflow archives, signs, and
exports a distributable `.ipa` on GitHub's macOS runners, so you can ship from any
machine (including Linux/Windows, where Xcode isn't available). You download the
`.ipa` and upload it to App Store Connect / TestFlight.

## One-time setup

You need an **App Store Connect API key** (the modern, no-`.p12`-juggling way to sign
in CI). Xcode uses it to create the distribution certificate and provisioning
profiles automatically for all five signed targets: the app, its widget extension,
its share extension, the watch app, and the watch widget extension.

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access**
   → **Integrations** → **App Store Connect API** (Team Keys).
2. Create a key with the **Admin** role. This is required: exporting an App Store
   build makes Xcode create the **Apple Distribution** certificate via cloud
   signing, and only an Admin-role key may do that. An App Manager/Developer key
   can do *development* signing (so the archive step succeeds) but the export then
   fails with `Cloud signing permission error`. Note the **Key ID** and the
   **Issuer ID** shown on the page.
3. Download the `AuthKey_<KEYID>.p8` file. **You can only download it once.**
4. Make sure an app record for `plastickarma.lead-track` exists in App Store
   Connect → **My Apps**. Five bundle IDs are signed: `plastickarma.lead-track`,
   `.widget`, `.share`, `.watchkitapp`, and `.watchkitapp.widget`. The app, widget,
   and watch app don't need manual registration: with an Admin key, cloud signing
   registers missing bundle IDs automatically during Archive (observed when the
   watch app shipped for the first time). The share extension and watch widget
   App IDs are exceptions: their entitlements request an App Group, which API-key
   cloud signing cannot create, so the release workflow pre-registers both via
   [`register-app-group-bundle-ids.rb`](../.github/scripts/register-app-group-bundle-ids.rb).
   Assigning the actual App Group to those App IDs is not supported by the public
   API and remains a **one-time manual step**. In the
   [developer portal](https://developer.apple.com/account/resources/identifiers/list),
   edit both the `plastickarma.lead-track.share` and
   `plastickarma.lead-track.watchkitapp.widget` identifiers and assign
   `group.plastickarma.lead-track` under the App Groups capability for each.
5. Add three repository secrets (**Settings → Secrets and variables → Actions →
   New repository secret**):

   | Secret | Value |
   | --- | --- |
   | `APP_STORE_CONNECT_API_KEY_ID` | the Key ID, e.g. `2X9R4HXF34` |
   | `APP_STORE_CONNECT_API_ISSUER_ID` | the Issuer ID (a UUID) |
   | `APP_STORE_CONNECT_API_KEY` | the **entire text** of `AuthKey_<KEYID>.p8`, including the `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----` lines |

## Building an `.ipa`

**On demand** (just want a build to download):

- GitHub → **Actions** → **Release IPA** → **Run workflow**. Optionally type a
  marketing version (e.g. `1.2.0`); leave blank to keep the project's value. Tick
  **publish_testflight** to also upload the build to TestFlight.
- Or from this machine:
  ```sh
  # build only (download the artifact):
  gh workflow run release.yml -f marketing_version=1.2.0
  # build AND upload to TestFlight:
  gh workflow run release.yml -f marketing_version=1.2.0 -f publish_testflight=true
  gh run watch "$(gh run list --workflow=release.yml -L1 --json databaseId --jq '.[0].databaseId')" --exit-status
  ```

**By tagging a version** (publishes a GitHub Release **and** uploads to TestFlight):

```sh
git tag v1.2.0 && git push origin v1.2.0
```

A `v*` tag sets the marketing version from the tag (`v1.2.0` → `1.2.0`) and always
uploads to TestFlight. The build number (`CFBundleVersion`) is derived from a UTC
timestamp at build time, so every build is unique and accepted by App Store Connect.

## Testing on your iPhone (TestFlight)

App Store distribution builds **cannot be sideloaded** directly onto a device — they
install through TestFlight. When the workflow publishes (the `publish_testflight`
tick or a `v*` tag), it uploads the `.ipa` to App Store Connect for you via
`xcrun altool`, so you don't need a Mac.

1. Run the workflow with publishing enabled (see above) and wait for it to go green.
2. In [App Store Connect](https://appstoreconnect.apple.com) → your app → **TestFlight**,
   wait a few minutes for the build to finish **Processing**.
3. Add yourself under **Internal Testing** (internal testers need no Beta App
   Review, so it's immediate).
4. On the iPhone: install the **TestFlight** app from the App Store, sign in with
   that Apple ID, and tap **Install** next to the build.

Prerequisite: an **app record** for `plastickarma.lead-track` must exist in App Store
Connect → **My Apps** (separate from registering the bundle identifier). If it's
missing, the upload step fails telling you to create it.

### Manual upload (fallback)

If you'd rather upload by hand, download the **lead-track-ipa** artifact from the run
(tag builds also attach it to the GitHub Release) and drag it into the **Transporter**
app (Mac App Store), or use Xcode → Organizer / `xcrun altool --upload-app`.

## Notes

- The export uses `method=app-store-connect` (App Store / TestFlight). The workflow
  falls back to the legacy `app-store` value automatically on older Xcode.
- This is independent of [`ios.yml`](../.github/workflows/ios.yml), which lints,
  builds, and tests every push/PR. `release.yml` only runs on demand or on `v*` tags.

## Troubleshooting

- **`Cloud signing permission error` / `No profiles for '…' were found` during
  Export** (the Archive step succeeded first): the API key is not an **Admin** key.
  Creating the Apple Distribution certificate via cloud signing requires the Admin
  role. Generate a new Admin key, update the `APP_STORE_CONNECT_API_*` secrets, and
  re-run. (You can't elevate an existing key's role — make a new one.)
- **Upload step fails with "no suitable application records" / app not found**: the
  app record doesn't exist yet. Create it in App Store Connect → **My Apps** for
  bundle ID `plastickarma.lead-track`, then re-run.
- **Build shows "Missing Compliance" in TestFlight** and testers can't install it:
  answer the export-compliance question on the build in App Store Connect (most apps
  using only standard/HTTPS encryption are exempt). To skip this prompt permanently,
  add an `ITSAppUsesNonExemptEncryption` key to the app's Info.plist.
- **Upload rejected: "must be built with the iOS 26 SDK"**: the runner built with an
  older Xcode. The workflow's *Select newest Xcode* step picks the newest Xcode
  installed on the runner; if that's still too old, the `macos-latest` image doesn't
  have Xcode 26 yet — pin a newer image with `runs-on:` (e.g. a `macos-26` label).
- **Upload rejected: "train version 'X' is closed" / "CFBundleShortVersionString must
  contain a higher version"**: that marketing version is already on App Store Connect.
  Re-run with a higher version — `-f marketing_version=1.0.1` or a higher `v*` tag.
  (The build number auto-increments per run; only the marketing version can collide.)
- **"You can only submit one build from version X to Beta App Review"**: external
  TestFlight reviews only one build per version at a time, so a previously-submitted
  build still *Waiting for Review* / *In Review* blocks the new one. On publish the
  workflow auto-expires stuck builds **of the version being uploaded** first — the
  *Expire builds stuck in Beta App Review* step, run by
  [`expire-builds-in-review.rb`](../.github/scripts/expire-builds-in-review.rb) —
  so the new build can be submitted; approved builds testers are using, and builds
  of other versions, are left untouched. Fastest path of all: distribute to
  **Internal Testing**, which skips Beta App Review entirely.
