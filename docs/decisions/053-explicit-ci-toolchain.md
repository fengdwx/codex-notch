---
status: active
contract_ids: [CI-VERIFICATION-001, SETTINGS-WINDOW-022, APP-UPDATE-002]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-14
last_verified_commit: null
---

# Select a supported SDK and verify the release source in CI

## Evidence

[CI run 34770566411](https://github.com/fengdwx/codex-notch/actions/runs/34770566411)
failed compiling `@Environment(\.openSettings)` before tests could run. The
runner was macOS 14.8.9, image `macos-14-arm64/20260831.0302`. Its
[software inventory](https://github.com/actions/runner-images/blob/macos-14-arm64/20260831.0302/images/macos/macos-14-arm64-Readme.md)
lists Xcode 15.4 as default and Xcode 16.2 as installed. The workflow did not
select Xcode. Local verification used Xcode 26.6 / Swift 6.3.3.

SwiftUI exposes `openSettings` with the Xcode 16 SDK and supports it on macOS 14.
The local SDK declares that runtime availability; the API is also described by
[Apple](https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings)
and the [SettingsAccess maintainer](https://github.com/orchetect/SettingsAccess#xcode-16-update).
The same compile error occurred before v0.2.2. That history did not justify
publishing without resolving and verifying the failure.

The SDK mismatch is the primary hypothesis. An application source regression
or another failure hidden behind compilation remains possible until the entire
remote verification passes. Testing the unchanged release source with the
supported SDK distinguishes these cases.

## Decision and acceptance

- Keep the macOS 14 runner and set `DEVELOPER_DIR` to its installed Xcode 16.2.
  Record the source SHA, OS, Xcode, Swift and SDK versions before verification.
- Run `scripts/verify.sh` in CI: behavior contracts, the complete existing test
  suite, release build, resources, bundle and code-signature verification.
- Allow a manual `ref` to verify the exact v0.2.2 source with the repaired
  workflow. Keep the original tag and signed assets unchanged. This is a source
  build check, separate from the previous installed-app update smoke test.
- Require successful CI for the intended release source before publication;
  local success or a pre-existing CI failure cannot substitute for it.
- Document Xcode 16 as the source-build requirement. Runtime support remains
  macOS 14 or later. No dependency, user preference or UI behavior changes.

Risk is L2 for CI and publication verification. Acceptance requires local full
verification, a successful remote run for this change, and a successful manual
run whose checkout SHA matches v0.2.2. Report any later failures rather than
reducing coverage. These checks do not establish physical-notch appearance or
login-session behavior. Rollback is reverting the workflow/documentation change;
release publication remains blocked until a supported setup passes.
