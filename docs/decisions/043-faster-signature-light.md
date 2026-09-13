---
status: superseded
contract_ids: [FLOATING-CENTER-056, SETTINGS-PREFERENCES-018]
supersedes: [042-seamless-signature-light]
superseded_by: 044-signature-without-status-dot
owner: project-maintainer
created_at: 2026-09-13
---

# Slightly faster continuous signature light

At the user's request, shorten the signature's repeating translation from six
seconds to five, making the same movement 20 percent faster. This L2 change
preserves FLOATING-CENTER-055's seamless gradient, brightness, glyph geometry,
all-state continuity and motion gates, plus SETTINGS-PREFERENCES-018. Other
styles, card transitions, task data, refactoring and releases are out of scope.

Rejected: changing the gradient, frame cadence or adding a speed setting for
this small adjustment. Only the duration changes, so the existing no-pause and
no-dark-gap guards remain applicable. Acceptance uses the existing live
signature fixture, full verification and an installed-app cycle recording;
physical-notch appearance remains subject to real hardware confirmation.
