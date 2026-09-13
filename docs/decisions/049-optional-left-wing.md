---
status: active
contract_ids: [NOTCH-LEFT-001, SETTINGS-PREFERENCES-018]
supersedes: [025-selectable-status-icon]
owner: project-maintainer
created_at: 2026-09-13
---

# An Off choice releases the compact left wing

Following issue #3, the maintainer requested an Off choice beside Codex and
ChatGPT in the existing status-icon picker. The purpose is to recover menu-bar
space. Off therefore hides the entire compact left lane, including returned
five-hour quota, its background and mouse-hit area. Five-hour data remains in
the expanded card. The explanatory text states this explicitly in both
languages. Codex remains the default; both artwork choices retain their
existing quota priority, appearance and motion.

Store `off` in the existing preference. The runtime observes only whether the
left lane is enabled, so switching between the two artworks still does not
change runtime data preferences. Do not mount a hidden status/halo animation.

Keep the original content coordinates and expanded frames. Crop the actual
compact NSPanel up to the physical camera's left edge; on floating bars crop
the existing 30pt left lane while retaining the center and right positions.
Keep the SwiftUI hosting canvas centered on the original layout anchor inside
that narrower window. The shell's leading inset animates inside the existing
fixed canvas, and the final panel frame is reclaimed after completion. This
avoids both moving the right quota and retaining a transparent menu blocker.
The physical camera hover sensor remains available. Floating recovery uses
only the remaining compact region. Full-screen and display routing are intact.

Rejected alternatives: hiding only the glyph leaves the blocking wing; moving
both indicators right changes the requested choice; automatically detecting
menus introduces a separate interaction policy. The current work does not
implement automatic avoidance or change login items, quota values, task state,
expanded content, navigation, update behavior or release packaging.

Guards cover preference persistence/restoration, left selection with and
without five-hour data, physical/floating geometry, shell hit testing, actual
panel bounds, anchored content, reduced-motion settlement and stale collapse
callbacks. Retain the previous two artwork tests as explicit positive coverage.
Run the full verification and inspect the built settings and live floating bar.
Real-notch menu clicking, camera clearance, hover motion and all compact task
states still require hardware acceptance; automated geometry is not proof of
physical menu usability.

Local verification on macOS 26.6.2 passed 90 contracts and 228 tests (two
existing opt-in tests skipped), plus the release build, bundled-resource and
signature checks. In the built app, the three localized radio choices were
visible. Off removed the left compact surface while the right quota remained
visible; a process restart retained Off. Both artwork options were selectable
again, and the original Codex choice was restored after inspection. Physical
menu clicking, camera clearance and continuous hover motion remain unverified.
