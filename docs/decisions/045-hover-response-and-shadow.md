---
status: active
contract_ids: [NOTCH-MOTION-008, SETTINGS-PREFERENCES-018, NOTCH-LAYOUT-038]
supersedes: [038-clean-expanded-typography]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Immediate compact hover response and a faint exterior shadow

The user approved a small hover response and shadow after reviewing Atoll's
[separate hover animation](https://github.com/Ebullioscopic/Atoll/blob/2a8f2ba8efa93ef76b641e41e4457ee63709a1bc/DynamicIsland/ContentView.swift#L2299-L2395).
This L2 change preserves NOTCH-READABILITY-007's main curves, text appearance,
camera clearance, state semantics and completion-driven recovery. Data,
settings, other center styles, dependencies and releases are out of scope.

During the existing 180ms opening delay, the compact shell alone grows by 2pt
on each side and 2pt downward. Use a 200ms curve with a small settling return, while
the compact content retains its original size and screen position. The shell
casts an 18 percent black shadow with 3pt radius and 2pt downward offset while
hovered or open. The main opening, closing and text transitions remain intact.

Reserve 12pt beside and below the active surface for the shadow, plus the
existing 8pt excursion clearance during expansion. Prepare once before the
SwiftUI transaction and retain only shadow space after opening. Restore the
exact compact frame after full collapse or a canceled short hover. Reuse the
existing completion identifiers and hover timers; skip pre-hover updates
during an in-flight card transition so rapid reentry cannot retime its tail.
Hidden and disabled-motion surfaces keep their previous geometry and no shadow.

Rejected: scaling the entire compact header, clipping effects inside the old
panel bounds, permanent idle padding, per-frame window resizing, or replacing
the accepted main spring with Atoll's more damped curve. Validation covers
top anchoring, stationary content, shadow clearance, cancellation, clock
refreshes, stale callbacks and motion gates, followed by full verification and
native recordings. Physical-notch clearance still requires hardware review.

The initial hover spring retained its completion callback for roughly 600ms
after a brief exit. A native recording reproduced the delayed canvas recovery.
Use the finite hover curve and retain the completion-based reclamation and
450ms canceled-hover guard. Clip the black background to the shell before
casting its shadow, so no rectangular fill leaks through rounded corners.

Validation on 2026-09-13: full verification passed with 208 tests passing and
two opt-in fixtures skipped, plus bundle, resource and signing checks. The
native hover recording fixture was run separately and passed after reproducing
and correcting the delayed short-hover recovery. Its 60 FPS recording covers
a brief canceled hover, opening, collapse, reentry and disabled motion. Frame
inspection confirmed rounded shell boundaries and the exterior shadow. The
installed binary matches the verified build and runs under launchd. The Mac
locked before the installed-app pointer check; that check and physical-notch
clearance remain pending manual unlock and hardware confirmation.
