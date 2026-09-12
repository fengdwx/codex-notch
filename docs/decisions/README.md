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
| [010-layer-backed-quota-motion](010-layer-backed-quota-motion.md) | active | `QUOTA-SEMANTICS-046` | Keep 8 FPS quota motion while moving persistent ring and wave frames out of SwiftUI |
| [011-ignore-subagent-rollouts](011-ignore-subagent-rollouts.md) | active | `ACTIVITY-STATE-005`, `CONVERSATION-TITLE-041` | Ignore child-agent rollouts in notch activity and conversation history |
| [012-manual-release-update-check](012-manual-release-update-check.md) | active | `APP-UPDATE-001` | Check the latest public stable release manually from Settings |
| [013-no-notch-floating-bar](013-no-notch-floating-bar.md) | superseded | `NOTCH-VISIBILITY-044` | Show the same status surface as a top-center floating bar on displays without a physical notch |
| [014-top-attached-no-notch-activity-island](014-top-attached-no-notch-activity-island.md) | superseded | `NOTCH-VISIBILITY-045` | Attach a compact, state-driven activity island to the screen top on displays without a physical notch |
| [015-no-notch-task-status-island](015-no-notch-task-status-island.md) | superseded | `NOTCH-VISIBILITY-046` | Fit a task-title status island inside the measured menu-bar height on displays without a physical notch |
| [016-sword-wanderer-battle-island](016-sword-wanderer-battle-island.md) | active | `NOTCH-VISIBILITY-050` | Reuse the validated local Sword Wanderer pet for an overlapping endless slime battle loop |
| [017-mirrored-display-menu-bar-fallback](017-mirrored-display-menu-bar-fallback.md) | superseded | `NOTCH-VISIBILITY-047` | Keep no-notch islands out of mirrored ordinary app content while preserving live geometry recovery |
| [018-running-notch-marquee](018-running-notch-marquee.md) | superseded | `QUOTA-SEMANTICS-043` | Add a restrained layer-backed outline marquee to the running physical-notch compact surface |
| [019-low-cadence-notch-marquee](019-low-cadence-notch-marquee.md) | superseded | `QUOTA-SEMANTICS-044` | Bridge low-cadence outer-edge marquee steps with delayed fading copies |
| [020-running-notch-breathing-light](020-running-notch-breathing-light.md) | superseded | `QUOTA-SEMANTICS-045` | Use a centered breathing light for the running physical-notch state |
| [021-visible-quota-halo-running-cue](021-visible-quota-halo-running-cue.md) | active | `QUOTA-SEMANTICS-046` | Put the running cue behind the real visible compact quota indicators |
| [033-mirrored-display-floating-island](033-mirrored-display-floating-island.md) | active | `NOTCH-VISIBILITY-050` | Keep the enabled island visible in the mirror master's current coordinate space |

New decisions must include `status`, `contract_ids`, rejected alternatives, and consequences. When a decision changes, retain the old document and point to the new one with `superseded_by`.
