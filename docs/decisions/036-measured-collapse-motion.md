---
status: active
contract_ids: [NOTCH-MOTION-005, SETTINGS-PREFERENCES-018, NOTCH-LAYOUT-038]
supersedes: [035-spring-card-transitions]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Match the recorded collapse while bounding camera and icon clearance

The user accepted the opening of revision 2385cf9 but rejected its collapse.
Preserve that opening, the settled geometry, and runtime behavior. This L2 change
affects collapse shape and content motion only; data, settings, typography,
distribution, and unrelated interactions are out of scope.

## Reference evidence

Measure the user-supplied 30 FPS Vibe Island demonstration around 3.97–4.50s.
Black-surface bounds, in recording pixels, were:

| Video time | Width | Height |
| --- | ---: | ---: |
| 3.967s | 680 | 319 |
| 4.033s | 612 | 216 |
| 4.167s | 537 | 105 |
| 4.333s | 516 | 74 |
| 4.500s | 520 | 79 |

The last movement is an undershoot followed by a return, about 2% of the travel
or 6% of compact height. Width/height stay centered on the same top anchor.
The old critically damped curve cannot produce this return. The reference also
blurs outgoing content and reveals the new compact label during the close.

The [reference website](https://vibeisland.app/) confirms its demonstration CSS
in the [observed stylesheet](https://vibeisland.app/_astro/affiliate.BLBIVOx3.css):
the surface uses a 0.5s cubic Bézier with control points (0.175, 0.885), (0.32, 1.1).
Content uses a 0.25s opacity transition, 0.30s blur to 6px, and a 0.35s scale to
0.96; incoming content has a 0.06s delay. This is verified website demonstration
behavior, not a claim about Vibe Island's native app source. Recording bounds
are approximate due to frame sampling and compression; the curve test permits
that uncertainty and checks the overshoot separately.

## Native implementation

Use SwiftUI's [UnitCurve timing animation](https://developer.apple.com/documentation/swiftui/animation/timingcurve(_:duration:))
for the collapsing surface. Preserve the accepted 0.42/0.8 opening spring and
0.8-scale insertion. Resizing reset details while already expanded keeps the
previous critically damped spring.

The native card has a much larger expanded-to-compact height ratio than the
reference. Directly applying its overshoot would remove too much of a 30pt bar.
An animatable frame smoothly limits floating-bar undershoot with a tanh bound:
less than 6% in height and 0.8% in width. The 22pt icons stay inside, including
the 28pt auto-hidden-menu-bar layout. Physical-notch dimensions have a strict
compact floor. Values above the compact size pass through unchanged, preserving
opening. Hidden sensors use their own geometry without a compact floor.

Use built-in opacity/scale transitions and a simple blur modifier for the
outgoing details. The returning compact header has its own asymmetric dissolve;
its removal on opening stays immediate. The native recording must show the
compact header before the canvas settles, not a blank strip that suddenly gains
icons afterwards. Keep all motion finite and honor app motion/Reduce Motion.

Retain the plain AppKit canvas, pre-layout centering, `.removed` completion,
transition IDs, stale-callback rejection, and clock stability from decision 035.
Do not reintroduce window resizing on each animation frame or fixed-delay runtime
reclamation. The fallback timer only serves callers without completion callbacks.

## Verification

`NotchCollapseMotionTests` checks recorded travel samples, a real undershoot and
return, icon clearance for both floating heights, physical camera-safe floors,
and unchanged geometry above the compact size. Existing hosting/center/completion/
reentry/disabled-motion tests remain active.

Run the opt-in `NotchMotionCaptureTests` fixture to record the actual production
SwiftUI surface and native panel with synthetic sessions. Inspect normal close,
the final return, compact label visibility, and reentry during close. Keep
recordings local and out of the app bundle and Git. Full checks and fixture
recordings do not establish physical-notch clearance or subjective acceptance;
those remain real-hardware confirmation items.
