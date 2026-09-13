---
status: superseded
contract_ids: [FLOATING-CENTER-054, SETTINGS-PREFERENCES-018]
supersedes: [040-running-signature-shimmer]
superseded_by: 042-seamless-signature-light
owner: project-maintainer
created_at: 2026-09-13
---

# Keep the personal signature shimmering slowly between tasks

The user confirmed the installed shimmer looks correct and requested that it
continue even when no task is running, at a slower pace. This L2 adjustment
supersedes decision 040's running-only gate and four-second period. Use a
six-second cycle for personal signatures in running, completed and idle states.
Task state changes only the adjacent dot; the neutral highlight continues
without restarting. Preserve geometry, fonts, contrast, text normalization,
the mask and the existing visible-only Core Animation renderer.

Expansion, hidden/detached surfaces, disabled animations and Reduce Motion
still stop decorative work and restore readable static text. Orbit and flow
retain their running-only gates; elapsed digits, quota, icons, card motion,
privacy, settings choices and releases are out of scope. Rejected: animating
every center style when idle, adding a separate toggle, restarting on task
completion, or changing the accepted appearance instead of just the cadence.

Acceptance includes failing state/renderer guards before the change, a live
full-cycle sample spanning completion and idle, full verification and an
installed-app restart through LaunchServices. The live fixture uses the
production NotchPanel's Space behavior so its test window can be visible on
the same desktop as the real island. A command-line XCTest process also needs
AppKit launch setup, event delivery and a committed first display before
WindowServer reports visibility; the fixture performs those steps without
changing the production visibility gate or weakening its assertions.

Validation on 2026-09-13: the new state, hosted-view and cadence guards failed
before the change. Full verification passed with 206 tests and two opt-in
fixtures skipped, followed by release build, resource and signing checks.
The dedicated live-layer fixture then passed separately: a full highlight
traversal survived clock updates, completion and idle, with fixed glyph
geometry and no animation after motion was disabled. Continuous frame samples
also showed the blue-to-green-to-neutral status dot while the text kept its
highlight. The installed executable matched the verified build and relaunched
under launchd with an opaque 212x30 window at the screen's top center.
