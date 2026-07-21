---
status: active
owner: project-maintainer
created_at: 2026-07-21
contract_ids:
  - PACKAGE-VERIFY-006
  - PACKAGE-DMG-018
supersedes: []
superseded_by: null
---

# Keep ZIP and DMG local release artifacts

## Decision

`./scripts/release.sh` produces both a ZIP and a compressed read-only DMG for the same verified `CodexNotch.app`. The DMG is verified, mounted into a temporary directory, and its mounted app bundle is checked before the script succeeds. ZIP remains available as the compact fallback archive.

## Context

The initial preview release used only a ZIP archive. That works, but a DMG gives macOS users the familiar open-and-drag installation flow. A disk image is a delivery format, not a trust mechanism: the current app still uses ad-hoc signing and has not been notarized.

## Rejected alternatives

- **Keep ZIP only:** retains a working archive but leaves the standard macOS installation path absent.
- **Publish DMG only:** removes the existing simple fallback and weakens `PACKAGE-VERIFY-006`'s ZIP guarantee.
- **Treat DMG as a signing fix:** a DMG does not provide Developer ID signing or Apple notarization; those need private Apple Developer credentials and are out of scope for the local packaging change.

## Consequences

- Local release builds take slightly longer because the script verifies and mounts the generated DMG.
- Release notes must say that the DMG does not eliminate the Gatekeeper warning until Developer ID signing and notarization are added.
- Public upload remains a separate, explicit release action.
