# CodexNotch Architecture Decisions

Record decisions here only when they affect active behavior contracts, could be accidentally changed by a future agent, or capture a historical failure boundary.

| Decision | Status | Related contract | Description |
|---|---|---|---|
| [001-fixed-canvas-notch-motion](001-fixed-canvas-notch-motion.md) | active | `NOTCH-MOTION-002` | Fixed NSPanel canvas with an expanding inner SwiftUI island |
| [004-zip-and-dmg-local-release](004-zip-and-dmg-local-release.md) | active | `PACKAGE-VERIFY-006`, `PACKAGE-DMG-018` | Keep a verified ZIP fallback while adding a verified DMG installation path |

New decisions must include `status`, `contract_ids`, rejected alternatives, and consequences. When a decision changes, retain the old document and point to the new one with `superseded_by`.
