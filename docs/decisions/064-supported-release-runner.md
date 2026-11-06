---
status: active
contract_ids: [CI-VERIFICATION-002]
supersedes: [053-explicit-ci-toolchain]
superseded_by: null
owner: project-maintainer
created_at: 2026-11-06
---

# Move verification and packaging to a supported hosted runner

GitHub retired macOS 14 hosted images; fresh runs are cancelled before tests
with `macos-14-arm64-us-default is not supported`.
https://github.com/actions/runner-images/issues/13518

Use macOS 15 in CI and packaging, retaining Xcode 16.2, the complete verify
script, source-SHA logging, and successful exact-source CI before publication.
Do not change the minimum runtime requirement or skip failed checks. The
macOS 15 diagnostic run 42154414967 passed the full suite after correcting
button-layout assertions to use AppKit alignment rectangles. See
../reviews/2026-11-06-reset-dialog-ci.md. This does not replace a macOS 14
hardware acceptance test; that remains unverified.

Rejected: continuing to dispatch a retired runner, using an implicit latest
SDK, or treating local tests as a substitute for remote verification.
