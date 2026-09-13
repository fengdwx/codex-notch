---
status: active
contract_ids: [APP-UPDATE-002, SETTINGS-WINDOW-019, PRIVACY-BOUNDARY-005]
supersedes: [012-manual-release-update-check]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
last_verified_commit: null
---

# Install signed updates from Settings with Sparkle

The user requested download and installation inside the app and authorized a
dedicated publisher signing key in the local macOS Keychain. This supersedes
the link-only update behavior in ADR 012.

## Decision

- Pin Sparkle 2.9.6. Retain its standard updater across Settings presentations;
  start it on the first manual check. Sparkle owns progress, cancellation,
  archive verification, installation, and relaunch.
- Serve the stable appcast from the personal repository's `main/appcast.xml`;
  archives remain GitHub Release assets. No credentials or application data
  are added to requests. Disable profiling and automatic checks/downloads.
- Store the Ed25519 signing key under Keychain account
  `com.david.codexnotch.sparkle`; embed only `SUPublicEDKey`. Verify archives
  before extracting them. No key export or CI secret is required.
- Preserve Sparkle's vendor-signed helpers, symlinks and executable bits when
  embedding the framework. Sign our outer app ad hoc as before. This does not
  constitute Apple Developer ID signing or notarization.
- `release.sh` signs the ZIP and generates `dist/appcast.xml` automatically.
  Publish the archive first, then the generated feed. The initial tracked feed
  has no items until the first updater-enabled release is published.
- The old GitHub metadata parser and its regression tests remain as historical
  guards; Settings no longer calls that network path.

## Rejected alternatives

- A custom shell installer would duplicate Sparkle's verification and replacement
  safeguards, including failure recovery and handling a running application.
- Requiring an Apple developer subscription is unnecessary for the Ed25519 key.
  Apple signing/notarization remains separate; Gatekeeper behavior needs real
  installation testing and cannot be inferred from a successful build.
- Exporting the private key into GitHub Actions is unnecessary for local releases.

## Acceptance and rollback

Risk is L3 because the change provisions a signing key and installs executable
updates. Run full verification and test a lower build downloading/installing and
relaunching a signed higher build. Also test a modified archive and verify the
old executable remains intact. Record observed results, not just compile status.

Keep a copy of the currently installed app before replacing it. Restore that
copy if local installation fails. A bad public update can be withdrawn by
removing its appcast entry; already installed releases require a higher-numbered
corrective release. Do not rewrite existing release tags or archive contents.
Users of 0.2.0 must install the first Sparkle-enabled release manually once.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[programmatic lifecycle](https://sparkle-project.org/documentation/programmatic-setup/).

## Observed acceptance on 2026-09-13

- Full verification: 215 tests, 213 passed and two pre-existing opt-in tests skipped;
  release build, embedded helpers, code signature, resources and license checks passed.
- A separate bundle identity on this Mac used the real Settings and Sparkle UI
  with a loopback feed. A one-byte change to the signed ZIP was rejected as
  improperly signed. Build 18 remained runnable with its code signature intact.
- Restoring the valid ZIP installed build 19 (0.2.1), relaunched via LaunchServices,
  and retained the custom signature preference. The installed executable matched
  the signed update payload.
- Publisher release packaging generated the ZIP/DMG and independently verified
  the archive signature using only the embedded public key.
- This covers this Mac's ad-hoc installation. Fresh-download Gatekeeper behavior
  on another Mac and existing-window activation across Spaces still require
  physical confirmation; this change does not assert new animation verification.
