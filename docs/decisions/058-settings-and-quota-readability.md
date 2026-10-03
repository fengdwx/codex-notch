---
status: active
contract_ids: [UI-READABILITY-058, SETTINGS-MOTION-021, SETTINGS-WINDOW-022]
supersedes: []
owner: project-maintainer
created_at: 2026-10-03
---

# Fit Settings to its content and keep quota decoration secondary

The user reviewed the installed 0.2.5 compact surface and all three Settings
pages, then approved reducing empty Settings space, quieter explanations,
less prominent ring decoration and a complete labelled floating example.
This is an L2 UI change. Data, preferences, notch geometry, animation timing,
window activation, login behavior and publication are out of scope.

Retain the native Settings scene and controls. Keep its width at 560pt;
General uses 360pt content height, or 460pt when login approval or an error
needs additional space. Appearance uses 320pt, while Floating Bar retains
580pt for its preview and editor. Scrollable forms keep conditional messages
and wrapped text reachable. Use 11pt secondary, leading-aligned explanations
with intrinsic vertical wrapping, retaining all existing bilingual copy.

Attenuate the inner glint in its native gradient layer to 0.55 opacity and
halve the halo pulse opacity to 0.03–0.12. Keep decision 057's native mask,
local coordinates and backing scale, together with every existing color,
stroke, gap, period and lifecycle gate. Set quota gradients back to full
layer opacity when reusing a glint view. The value and actual progress arc
must never inherit decorative attenuation.

Replace the floating preview's empty circle with the shared quota renderer
using a fixed, synthetic 75 percent remaining window and the selected quota
style. Keep the sample label, fixed 02:18 center example and existing center
motion gates. The quota example uses idle activity and disabled quota motion,
so it creates neither another clock nor another persistent quota animation.
It never requests or reads real quota/task data.

Rejected: resizing the notch panel, adding a SwiftUI glint mask, changing
quota colors or values, disabling decoration entirely, replacing native
Settings controls, introducing live data into the preview, or adding a new
rendering dependency.

Before the change, the hosted General page guard measured 580pt, exceeding
its 480pt upper bound; the native glint peak was 0.95, exceeding the 0.6
decorative limit. Retain those guards, the quota-gradient reuse check and
existing geometry, motion and preference checks. Run full verification and
inspect the rebuilt Settings for wrapping and page sizing. Physical-notch
confirmation of a full rotation and hover/collapse remains required; static
screenshots cannot establish animation smoothness or camera-cutout clearance.

Verification on 2026-10-03: both new guards failed against the baseline and
passed after the change. The focused suite passed 27 tests. Full verification
validated 100 contracts, ran 249 tests with zero failures and the two existing
opt-in capture tests skipped, then built and verified the signed app bundle.
On the local Swift 6.4 toolchain, the existing temporary Swift wrapper selected
the native build backend for `build` and `test`; the default backend was not
verified by this run. No checks or resource validation were removed.

The rebuilt app was launched from the isolated worktree. The real Chinese
Settings window resized between all three tabs, retained reachable controls
and wrapped secondary explanations, and its language popup opened and closed
normally. Running, idle and completed previews all displayed the labelled
75 percent example. Eight preference fingerprints matched before and after
the restart. The compact screenshot showed a legible quota value and arc with
subordinate decoration. The installed release bundle was left intact.

English wrapping, the wave-ball preview, conditional login notices and
physical-notch motion/clearance remain manual acceptance items. No publication
or real-hardware animation acceptance is implied by these checks.
