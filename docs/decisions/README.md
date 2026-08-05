# CodexNotch Architecture Decisions

Record decisions here only when they affect active behavior contracts, could be accidentally changed by a future agent, or capture a historical failure boundary.

| Decision | Status | Related contract | Description |
|---|---|---|---|
| [001-fixed-canvas-notch-motion](001-fixed-canvas-notch-motion.md) | superseded | `NOTCH-MOTION-002` | Fixed NSPanel canvas with an expanding inner SwiftUI island |
| [004-zip-and-dmg-local-release](004-zip-and-dmg-local-release.md) | active | `PACKAGE-VERIFY-006`, `PACKAGE-DMG-018` | Keep a verified ZIP fallback while adding a verified DMG installation path |
| [005-static-card-transitions-and-completion-cue](005-static-card-transitions-and-completion-cue.md) | active | `NOTCH-MOTION-003`, `NOTCH-LAYOUT-038` | Keep the fixed canvas while removing card transitions and completion fireworks |
| [006-hidden-notch-hover-recovery](006-hidden-notch-hover-recovery.md) | superseded | `NOTCH-VISIBILITY-040` | Keep a transparent notch hover sensor so the hidden display can be recovered from the physical notch |
| [007-suppress-notch-over-full-screen-content](007-suppress-notch-over-full-screen-content.md) | superseded | `NOTCH-VISIBILITY-040` | Suppress the complete notch panel over native and borderless full-screen content |
| [008-local-thread-summary-titles](008-local-thread-summary-titles.md) | active | `CONVERSATION-TITLE-041`, `PRIVACY-BOUNDARY-005` | Resolve row labels from Codex's read-only thread summaries rather than rollout messages |
| [009-keep-notch-visible-across-full-screen-apps](009-keep-notch-visible-across-full-screen-apps.md) | active | `NOTCH-VISIBILITY-042` | Keep the requested notch surface available in native and borderless full-screen applications |
| [010-layer-backed-quota-motion](010-layer-backed-quota-motion.md) | active | `QUOTA-SEMANTICS-043` | Keep 8 FPS visual motion while moving persistent ring and wave frames out of SwiftUI |
| [011-ignore-subagent-rollouts](011-ignore-subagent-rollouts.md) | active | `ACTIVITY-STATE-005`, `CONVERSATION-TITLE-041` | Ignore child-agent rollouts in notch activity and conversation history |

New decisions must include `status`, `contract_ids`, rejected alternatives, and consequences. When a decision changes, retain the old document and point to the new one with `superseded_by`.
