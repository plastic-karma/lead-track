# Releasing locally with xtool

All application builds, signing, and TestFlight uploads use the local,
source-built [xtool native release stack](https://github.com/plastic-karma/xtool/blob/main/Documentation/xtool.docc/NativeReleases.md).
GitHub hosts source and reviews only. There are no GitHub Actions build/release
workflows, tag-triggered uploads, remote Xcode runners, or Codex Cloud setup steps.

## Toolchain setup

1. Build and install the native tools from the xtool checkout, following its
   linked release guide. Use the source-built CLI, toolset, OpenAppleMacros server,
   asset/AppIntents tools, and signer together, not an older upstream xtool binary.
2. Import the Darwin SDKs from your own Xcode archive. Xcode supplies SDK inputs;
   builds run locally on Linux without running Xcode or using a Mac runner.
3. Install Swift 6.4.0, as selected by `xtool-release.yml`. Native SwiftData
   `@Query` views need its synthesized-initializer rules; the application remains
   in Swift 5 language mode. The manifest imports the canonical
   `lead track.xcodeproj`, including its deployment targets and embedded products.
4. Put the installed tools on `PATH`, or set `XTOOL` to the source-built CLI (or a
   local launcher that supplies its Swift runtime environment). Do not store
   workstation-specific toolchain paths in this repository.

The default native installation is `${XDG_DATA_HOME:-$HOME/.local/share}/xtool/native`.
`XTOOL_NATIVE_HOME` selects another installation. When rebuilding the macro server,
install it and run `xtool sdk update` as described in xtool's release guide: the
SDK contains its own copy, so replacing the installed executable alone is not
enough.

The project has no third-party app dependencies. The SwiftPM overlay at the root
is for local domain tests, not a replacement for the complete application build.

## Local validation and smoke builds

Run the pinned linters and portable tests before publishing changes:

```sh
swiftlint
swiftformat --lint .
swift test
```

See [CLAUDE.md](../CLAUDE.md#linting) for tool versions and Linux setup. xtool skips
the Xcode project's validation-only linter phases; the commands above are still
required.

From this repository:

```sh
./scripts/build-release.sh --prepare-only
./scripts/build-release.sh --unsigned
```

`--prepare-only` imports the project into `.xtool/workspace/`; it does not compile,
sign, or upload. `--unsigned` builds every product and produces a locally verified,
ad-hoc-signed IPA. It is not distribution signing or proof of TestFlight readiness.
The complete build includes:

| Product | Bundle identifier | Device architectures |
| --- | --- | --- |
| LeadStone | `plastickarma.lead-track` | iOS `arm64` |
| iPhone widget | `plastickarma.lead-track.widget` | iOS `arm64` |
| Share extension | `plastickarma.lead-track.share` | iOS `arm64` |
| Watch app | `plastickarma.lead-track.watchkitapp` | watchOS `arm64_32`, `arm64` |
| Watch widget | `plastickarma.lead-track.watchkitapp.widget` | watchOS `arm64_32`, `arm64` |

Do not drop extensions, capabilities, or architectures to get a build through.
Linux overlay tests and native compilation do not execute Apple's persistence or
UI runtime. Exercise the app on devices and report that verification separately.

## External distribution signing and Apple authentication

Reuse a valid distribution certificate and its matching private key. Provision an
App Store distribution profile for **each of the five bundle identifiers** above,
with the capabilities requested by that target. The signing team is `9492A97LWY`.
The share and Watch widget identifiers need the App Group
`group.plastickarma.lead-track` assigned in the
[developer portal](https://developer.apple.com/account/resources/identifiers/list).
Enable other requested capabilities before generating their profiles. Do not
copy every profile entitlement into the app or silently remove requested ones.

xtool validates the supplied identity/profiles; it does not create or revoke
certificates or provision profiles during a release. No account-wide certificate
cleanup is part of this workflow.

Default signing configuration:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/xtool/signing/plastickarma.lead-track.yml
```

The file contains paths to external files, not credential values:

```yaml
certificate: /private/location/distribution.cer
privateKey: /private/location/distribution.key
profiles:
  plastickarma.lead-track: /private/location/App.mobileprovision
  plastickarma.lead-track.widget: /private/location/Widget.mobileprovision
  plastickarma.lead-track.share: /private/location/Share.mobileprovision
  plastickarma.lead-track.watchkitapp: /private/location/Watch.mobileprovision
  plastickarma.lead-track.watchkitapp.widget: /private/location/WatchWidget.mobileprovision
```

Protect the signing directory with mode `0700`, and the config and private inputs
with `0600`. Keep them outside both the application and xtool repositories.
`--signing /private/location/signing.yml` or `XTOOL_SIGNING_CONFIG` can override
the default. Never commit credentials or put them in `xtool-release.yml`.

Authenticate the local [asc CLI](https://github.com/rudrankriyam/App-Store-Connect-CLI)
using its protected credential store and an App Store Connect API key authorized
for uploads to this app. The existing App Store Connect app ID is `6761788241`.
No GitHub secrets, GitHub Actions token, attached device, or USB connection is
required for an App Store/TestFlight upload.

## Distribution build and TestFlight upload

Release from a clean, committed, reviewed revision after the local checks pass.
Do not overlap release runs. Keep the existing working TestFlight build unless an
app-affecting change or an explicit user request calls for another upload.

```sh
# Distribution-signed IPA only; no upload.
./scripts/build-release.sh

# Build, sign, verify, upload, and check Apple processing/tester access.
./scripts/build-release.sh --upload
```

Upload is explicit: installation, preparation, ordinary builds, commits, pushes,
and tags never upload anything. `--build-number` accepts a unique decimal build
number; by default xtool uses the current Unix timestamp. A failed Apple upload
can consume its number, so use a new one for a retry. The marketing version comes
from the canonical Xcode project.

Each release is under `.xtool/releases/<build-number>/`, including `Payload/`, the
IPA, `release.json`, and `verification.json`; uploaded releases also retain Apple
receipts. `--output <directory>` selects another release parent. Existing release
directories are not overwritten. `.xtool/` is excluded from Git and both linters;
canonical application sources remain covered.

The release command verifies all five bundles/seven architecture slices, Mach-O
platform and deployment metadata, requested entitlements, and code/resource/CMS
signatures before upload. It then checks the exact version/build for Apple's
`VALID` processing state, unexpired status, beta-testing availability, and related
TestFlight groups. Report those receipts, not just a successful upload command.

In [App Store Connect](https://appstoreconnect.apple.com), open LeadStone's
TestFlight page and check access for the intended internal tester group. Install
with TestFlight on the iPhone, then verify Watch installation/sync, persistence,
widgets, sharing, AppIntents, and protected capabilities. App Store distribution
IPAs cannot be sideloaded. Internal testing does not require external Beta App
Review; a `Ready to Submit` label can coexist with internal testing availability.
Do not automatically expire older builds, enroll testers, or submit a public App
Store release.

## Troubleshooting

- **xtool is missing or lacks `release`:** select the source-built native CLI with
  `PATH`/`XTOOL`; do not install the retired upstream/cloud bootstrap binary.
- **Macro or SDK mismatch:** verify Swift 6.4.0 and the selected native toolset,
  reinstall the rebuilt macro server, and refresh the SDK with `xtool sdk update`.
- **Missing/expired profile or entitlement mismatch:** repair the external profile
  for the reported bundle. Preserve the existing identity and requested app
  capabilities; do not revoke unrelated certificates or drop a product.
- **Apple authentication, account agreement, or app-access failure:** resolve the
  exact issue using local asc authentication or App Store Connect. Do not move
  credentials to GitHub or fall back to a cloud release workflow.
- **Build rejected or still processing:** use the saved Apple receipt for that
  exact build. Fix rejection errors before retrying with a fresh build number;
  processing alone does not mean testers have access.
- **No internal tester access:** inspect the intended group's membership/build
  access in App Store Connect. Do not expire another build or change tester
  enrollment automatically.
