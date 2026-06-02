# Releasing — building an App Store `.ipa` from GitHub

The [`Release IPA`](../.github/workflows/release.yml) workflow archives, signs, and
exports a distributable `.ipa` on GitHub's macOS runners, so you can ship from any
machine (including Linux/Windows, where Xcode isn't available). You download the
`.ipa` and upload it to App Store Connect / TestFlight.

## One-time setup

You need an **App Store Connect API key** (the modern, no-`.p12`-juggling way to sign
in CI). Xcode uses it to create the distribution certificate and provisioning
profiles automatically for both the app and its widget extension.

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access**
   → **Integrations** → **App Store Connect API** (Team Keys).
2. Create a key with the **Admin** role. This is required: exporting an App Store
   build makes Xcode create the **Apple Distribution** certificate via cloud
   signing, and only an Admin-role key may do that. An App Manager/Developer key
   can do *development* signing (so the archive step succeeds) but the export then
   fails with `Cloud signing permission error`. Note the **Key ID** and the
   **Issuer ID** shown on the page.
3. Download the `AuthKey_<KEYID>.p8` file. **You can only download it once.**
4. Make sure the app and widget bundle IDs already exist under **Certificates,
   Identifiers & Profiles → Identifiers**:
   - `plastickarma.lead-track`
   - `plastickarma.lead-track.widget`
   …and that an app record for `plastickarma.lead-track` exists in App Store Connect.
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
uploads to TestFlight. The build number (`CFBundleVersion`) is always the workflow
run number, so every build is unique and accepted by App Store Connect.

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
