---
status: active
contract_ids: [NOTCH-MOTION-004, SETTINGS-PREFERENCES-018, NOTCH-LAYOUT-038]
supersedes: [005-static-card-transitions-and-completion-cue]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Restore restrained top-anchored spring transitions

The user requested elastic opening/closing after inspecting the Vibe Island
website demonstration. That page animates width/height with a 0.5s overshooting
timing curve; this is observed website behavior, not a verified native app API.

Restore a SwiftUI spring for actual surface changes when motion is allowed.
Expansion uses response 0.48/damping 0.80; collapse uses response 0.38/damping 1
to avoid undershooting the camera-safe compact width. The controller allocates
one temporary canvas with 8pt side/bottom clearance, preserving its top-center
anchor, and settles after 0.65s expanding or 0.60s collapsing. The displayed
surface retains the existing target geometry. Repeated updates to the same
target do not reset settlement; reversing direction cancels the previous work.
Global animation off and macOS Reduce Motion use immediate frame settlement.

On macOS 26.6.2 the first runtime build crashed in
`NSHostingView.updateAnimatedWindowSize` with repeated window constraint passes.
`sizingOptions = []` alone did not isolate animation from window sizing. Embed
the hosting view inside a plain autoresizing AppKit canvas instead of using it
as the panel's direct content view. The controller exclusively owns panel size.
The offscreen SwiftUI integration test did not reproduce this on-screen crash;
validate the installed application after building as well as running tests.

The user then supplied separate 30 FPS recordings of the reference and this
app. The first implementation visibly stretched the details with the shell
and kept them legible while collapse clipped the rows. Keep the compact header
separate from the detail transition and lay out details at the expanded target
size. Reveal them with a 0.18s fade after a 0.10s delay; remove them with a 0.10s
fade while the shell collapses. Interpolate the outer corner radius too. The
source recordings remain local review artifacts, not bundled application data.

Preserve fixed-canvas hosting, downward-only alignment, no frame-by-frame panel
resize, and the prohibition on quota completion fireworks. Do not reproduce
the reference's feature set or restyle the whole expanded card in this change.

Verification must cover geometry/policy and actual deferred frame recovery,
including rapid reentry. Full verification alone cannot establish perceived
spring quality or camera clearance; real hardware review remains necessary.
