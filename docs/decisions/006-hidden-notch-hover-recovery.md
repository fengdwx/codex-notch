---
status: superseded
contract_ids: [NOTCH-VISIBILITY-040]
supersedes: []
superseded_by: 009-keep-notch-visible-across-full-screen-apps
owner: project-maintainer
created_at: 2026-07-26
last_verified_commit: null
---

# Keep a Transparent Notch Hover Sensor While the Display Is Hidden

## Context

The notch is the user's primary discovery location. Removing the panel after a
Hide action made the setting technically reversible through secondary surfaces,
but left no way to rediscover the card by returning to the physical notch.

## Decision

- When the display preference is off on a valid notch screen, keep a transparent
  panel exactly over the physical notch hover sensor frame.
- Do not render quota, task, or compact-state content in that hidden state.
- If the pointer enters the sensor, use the existing hover reducer to expand the
  card and expose the same live display switch; turning it on restores the
  normal compact notch immediately.
- Keep menu-bar fallback panel-free and keep the panel out of native full-screen
  spaces.

## Rejected Alternatives

- **Order the panel out and rely only on the menu bar or hot key**: Users
  naturally return to the notch, so those recovery paths are easy to miss.
- **Keep a visible compact icon while hidden**: This violates the meaning of
  Hide and still makes the hidden state visually persistent.
- **Add a second recovery card or separate settings window**: Duplicates the
  existing expanded surface and creates another interaction path to maintain.

## Consequences and Verification

The hidden state still owns a small mouse-hit region at the physical notch, but
it is fully transparent and contains no user data until hover expansion. The
focused visibility-policy tests and `swift test` protect the mode selection;
physical-notch verification must confirm that moving to the camera cutout
reopens the card and that the in-card switch turns the compact notch back on.
