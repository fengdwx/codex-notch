---
status: active
contract_ids: [NOTCH-HEIGHT-001]
supersedes: []
owner: project-maintainer
created_at: 2026-09-25
---

# Match the compact surface to the measured physical camera height

Issue [4](https://github.com/fengdwx/codex-notch/issues/4) reports a height
mismatch that disappears when an external display is connected. The reporter
has not supplied a model, display mode or before/after screen metrics, so this
change fixes a demonstrated geometry limitation without claiming to reproduce
the reporter's complete display transition.

Commit 79bf505 moved the original below-camera panel into two compact wings
on July 16. It reduced the default height from 42pt to 32pt and clamped the
camera inset to 28...32pt. The reference screen and its regression fixture both
reported 32pt, leaving the limits untested at other display scales.

For valid auxiliary camera areas, a positive `NSScreen.safeAreaInsets.top`
now determines compact and hover-sensor height directly. Both physical-notch
indicator lanes receive the same height; artwork sizes remain unchanged.
The runtime already reads fresh metrics after screen-parameter notifications
and passes compact height to the view, so no new observer or cached state is
needed. The existing nonpositive-inset fallback remains intact.

This L2 fix preserves screen-top anchoring, width, left-wing cropping, expanded
content clearance, fixed-canvas motion, app animation preferences, quota/task
data and floating/mirrored-display behavior. It does not change display modes,
introduce per-model constants, or ship a release.

Rejected alternatives:

- Raising the fixed cap merely moves the failure to a different scale.
- Using menu-bar height couples physical-camera alignment to menu visibility.
- Adding delayed refreshes does not correct a measured height being clamped.

`NotchHeightTests` uses synthetic 24, 28, 29, 32, 37 and 38pt insets, explicitly
not a table of MacBook models. Guards check matching top/bottom edges, sensor
height, nonzero screen origins, left-wing cropping, preserved expanded detail
space, menu-bar independence, unchanged floating geometry and fresh metrics
after a route change. Existing geometry, routing and motion guards remain.

Run `swift test` and `./scripts/verify.sh`, rebuild/restart the app, and inspect
real camera clearance, indicator centering, expansion/collapse, hidden hover
recovery and external-display transitions. Synthetic metrics cannot establish
physical appearance or confirm that issue 4 is resolved on the reporter's Mac.

## Local verification status

On September 25, the pre-fix `swift test --filter NotchHeightTests` was blocked
before compilation by the unaccepted Xcode license. After the fix,
`./scripts/verify.sh` validated 97 contracts, then stopped at the same license
error. The separately installed Command Line Tools also
fail with duplicate `SwiftBridging` module definitions. No toolchain files or
license settings were changed. `git diff --check` passed.

After the user handled the license prompt, Xcode 27.0 (27A266a), Swift 6.4,
compiled the change. All four new height tests passed. In an isolated copy,
restoring only the original geometry implementation made three of those tests
fail with 26 assertions, including 38pt becoming 32pt and 24pt becoming 28pt.
The nonpositive-inset fallback guard still passed on the original code.

The default Xcode 27 `swiftbuild` engine failed five existing resource-loading
assertions across three tests. Its `.copy("Resources")` output places assets
under `Contents/Resources/Resources`; the app's current resource lookup does
not find them there. The same five failures were reproduced in the isolated
copy with the original geometry. This separate build-engine compatibility
issue is not changed by the height fix.

Using the supported `--build-system native` option and a fresh scratch build
directory, all 15 resource/battle tests passed. An exported shell wrapper then
supplied that option and scratch path to `swift build` and `swift test` in the
unchanged `./scripts/verify.sh` entry point. The full check passed: 97 contracts,
239 tests with two existing opt-in skips and zero failures, a release build,
bundled-resource checks, icon validation and signature verification. No tests
or assertions were removed or skipped to obtain this result. The native engine
is deprecated by Xcode 27; the default-engine failure remains outstanding.

Quit the installed app and launched the newly built
`/Users/david/projects/codex-notch/dist/CodexNotch.app`. The process executable
path matched that bundle. On the current 1512x982 screen, `safeAreaInsets.top`
was 32pt and WindowServer reported an opaque 257x32pt panel at (627, 0) in
top-left coordinates. The native screenshot showed both indicators and quota;
the context menu opened and dismissed successfully. Executable SHA-256:
`cbdfc0ed4fd2e9841aaeae9e6c93a7afa23095a375c39c6b911298497ef10786`.

Physical camera clearance at other display scales, actual hover
expansion/collapse and hidden recovery, animation smoothness, and the
reporter's external-display transition still require hardware acceptance.
The screenshot does not establish those outcomes. No public release was made.
