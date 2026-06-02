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
  marketing version (e.g. `1.2.0`); leave blank to keep the project's value.
- Or from this machine:
  ```sh
  gh workflow run release.yml -f marketing_version=1.2.0
  gh run watch "$(gh run list --workflow=release.yml -L1 --json databaseId --jq '.[0].databaseId')" --exit-status
  ```

**By tagging a version** (also publishes a GitHub Release):

```sh
git tag v1.2.0 && git push origin v1.2.0
```

A `v*` tag sets the marketing version from the tag (`v1.2.0` → `1.2.0`). The build
number (`CFBundleVersion`) is always the workflow run number, so every build is
unique and accepted by App Store Connect.

## Downloading and uploading to Apple

1. Open the finished run → **Artifacts** → download **lead-track-ipa** (tag builds
   also attach the `.ipa` to the GitHub Release).
2. Upload to App Store Connect with any of:
   - **Transporter** app (Mac App Store) — drag in the `.ipa`.
   - **Xcode** → Organizer, or `xcrun altool`:
     ```sh
     xcrun altool --upload-app -t ios -f "lead track.ipa" \
       --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
     ```
     (`altool` reads the key from `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.)

The build then appears in App Store Connect → TestFlight after Apple finishes
processing.

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
