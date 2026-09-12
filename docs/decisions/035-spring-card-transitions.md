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
Expansion uses response 0.42/damping 0.80; collapse uses response 0.45/damping 1
to avoid undershooting the camera-safe compact width. The controller allocates
one temporary canvas with 8pt side/bottom clearance, preserving its top-center
anchor. Runtime settlement waits for SwiftUI's `.removed` animation completion;
the 0.65s/0.60s delays remain only for callers without a completion signal. The displayed
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
size. The first revision used a 0.18s fade after a 0.10s delay and a 0.10s removal;
the subsequent recording showed this left a blank black slab during both
transitions. That timing is replaced by the coordinated transition below.
Interpolate the outer corner radius too. The
source recordings remain local review artifacts, not bundled application data.

Follow-up feedback identified a left-origin expansion and an abrupt final
collapse frame. A native hosting test reproduced the first issue with the old
canvas setter: widening 212pt to 436pt moved the content's screen center 112pt
left before SwiftUI re-laid it out. Resolve and display the existing surface
inside an unanimated canvas transaction before updating its animated state.
Reclaim the canvas only after the runtime's `.removed` completion, rather than
guessing when a spring's tail has finished. A transition identifier rejects
stale completions even after returning to the same target size. Clock updates
retain the current wait. Motion-disabled and hidden states still settle directly.

Guards cover the pre-animation content center, callback-driven recovery after
the former timeout, stale callbacks, and actual SwiftUI completion with a running
conversation's repeating status indicator. The old setter fails the center guard;
the prepared-layout setter passes.

## Upstream comparison and coordinated content motion

The user's next 30 FPS recording still failed visual acceptance. Inspection of
the primary upstream sources found:

- [Boring Notch ContentView, commit 99900bf](https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/boringNotch/ContentView.swift#L117-L128)
  uses separate opening (0.42 / 0.8) and closing (0.45 / 1.0) springs.
  [Its detail transition](https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/boringNotch/ContentView.swift#L354-L361)
  combines a top-anchored 0.8 scale with opacity over 0.35s.
- [Boring Notch window setup](https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/boringNotch/boringNotchApp.swift#L234-L279)
  creates the window canvas separately and positions it at the screen's top center.
- [Atoll ContentView, commit 8f84be6](https://github.com/Ebullioscopic/Atoll/blob/8f84be6bafadbe89f6215fe3c9a8408bf2c6f329/DynamicIsland/ContentView.swift#L689-L708)
  also separates outer-surface motion; its modern close path uses a 0.45 / 1.0
  spring. [Its outer frame](https://github.com/Ebullioscopic/Atoll/blob/8f84be6bafadbe89f6215fe3c9a8408bf2c6f329/DynamicIsland/ContentView.swift#L856-L866)
  suppresses notch-state animation independently from the visible surface.

Adopt the standard SwiftUI top-anchored scale/opacity technique for our existing
detail layer: scale 0.8 to 1, smooth 0.35s in either direction, no insertion delay.
The compact header remains stationary and the detailed text retains its layout.
Use the opening/closing response values above with the existing camera-safe
critical damping on collapse. No upstream application components or dependencies
are imported. Keep completion-driven canvas recovery rather than broadening the
window or changing pointer behavior.

`NotchMotionCaptureTests` is an opt-in native recording fixture using synthetic
sessions and the production `NotchViewModel`, `NotchView`, and window controller.
It records opening, closing, and mid-collapse reentry against a neutral backdrop:

```sh
NOTCH_MOTION_CAPTURE="$PWD/.build/motion-review/native.mov" swift test --filter NotchMotionCaptureTests
```

It is skipped during normal checks because it intentionally displays panels and
requires screen recording. Before/after recordings reproduced the old empty-slab
phase and showed coordinated content movement in the new version. They establish
native rendering evidence, not physical camera clearance or user acceptance of
the final feel. Existing callback/center/reentry/motion-disabled guards remain.

Preserve fixed-canvas hosting, downward-only alignment, no frame-by-frame panel
resize, and the prohibition on quota completion fireworks. Do not reproduce
the reference's feature set or restyle the whole expanded card in this change.

Verification must cover geometry/policy and actual deferred frame recovery,
including rapid reentry. Full verification alone cannot establish perceived
spring quality or camera clearance; real hardware review remains necessary.
