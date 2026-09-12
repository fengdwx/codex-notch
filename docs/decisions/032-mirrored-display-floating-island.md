---
status: active
contract_ids: [NOTCH-VISIBILITY-048]
supersedes: [017-mirrored-display-menu-bar-fallback]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-12
---

# Keep the Activity Island Visible While Mirroring

## Context

The user reported that mirroring the built-in display to a Mi Monitor hid
CodexNotch. Live inspection showed one 1920x1080 NSScreen with a 30pt menu
bar, no auxiliary camera areas, and an active hardware mirror set. The app
was running with its display preference enabled. Decision 017 deliberately
suppressed the floating island in that topology; the user requested visibility.

## Decision

- Remove the mirror-only suppression and menu-bar rendering branch. Use the
  existing geometry and presentation path for every current NSScreen.
- A mirror master without camera areas gets the existing 212pt floating bar,
  centered at the live screen top and contained within its measured menu bar.
- Continue to use valid auxiliary areas for physical-notch geometry. Screen
  parameter changes recompute geometry without retaining an old notch frame.
- Preserve display-off recovery, downward expansion, canvas reclamation,
  animation preferences, quota and activity semantics, and Space participation.
- Replace the old suppression assertions under the explicitly superseding
  contract with mirror-master geometry and visibility-policy regression guards.

## Rejected Alternatives

- **Keep menu-bar-only mirroring**: contradicts the requested visible island.
- **Keep a suppression function that always returns false**: leaves dead
  mirror detection and an unreachable renderer in the runtime.
- **Reuse the built-in notch rectangle**: the mirror master has a different
  drawable coordinate space, aspect ratio, and scale.
- **Change macOS mirroring settings**: not necessary to show the island.

## Consequences and Verification

The island is part of the mirrored desktop and intentionally occupies the top
center of its menu bar. Fixtures guard the observed master geometry, disabled
display recovery, and fresh geometry after leaving mirroring. Full verification
covers tests, build, bundle, and signature. The running installed app must be
checked on the current mirror set; returning to a physical notch and animation
or hover behavior not observed live must be reported as unverified.

## Verification on 2026-09-12

- `./scripts/verify.sh` passed: 68 contracts, 181 tests, release build, bundle,
  and signature checks.
- Backed up the installed app, installed the verified build, checked its
  executable hash against `dist`, and restarted `/Applications/CodexNotch.app`.
- The Mi Monitor remained a mirrored 1920x1080 desktop. WindowServer reported
  an on-screen, fully opaque 212x30 window at top-left coordinates (854, 0).
  The native app screenshot showed the status mark, battle scene, and quota.
- Physical-notch recovery after leaving mirroring, hover expansion/collapse,
  and animation smoothness remain unverified on hardware in this change.
