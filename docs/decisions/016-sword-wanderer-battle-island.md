---
status: active
contract_ids: [NOTCH-VISIBILITY-047]
supersedes: [015-no-notch-task-status-island]
superseded_by: null
owner: project-maintainer
created_at: 2026-08-10
---

# Use the Existing Sword Wanderer Pet for the No-Notch Battle Island

## Context

The menu-bar-height task-title island fixed top-edge overflow, but real-machine
review still found its center visually unbalanced. The earlier pixel battle was
also rejected because its newly drawn warrior looked crude and its rounded
helmet read as a bald head. The user already has a validated v2 `sword-wanderer`
pet whose face, hair, costume, palette, and animation identity are stronger than
another purpose-drawn substitute.

## Decision

- Bundle the validated Sword Wanderer v2 atlas as a project resource and render
  its original cells in the no-notch center lane. Do not alter the installed
  pet package under `~/.codex/pets`.
- Keep the proven 212pt width, measured 30pt maximum height, top attachment,
  outer safety insets, and symmetric 30pt indicator lanes.
- Replace only the visible task-title lane with a 136pt battle lane. Preserve
  the resolved task title in the compact button's accessibility label.
- Drive one overlapping loop sampled at no more than 12 FPS: a slime makes two
  small hops from the right, the wanderer anticipates and swings, the slime
  compresses and bursts, `+1` rises, and the next slime enters before that
  feedback ends.
- Keep the Sword Wanderer's head and gaze facing the incoming slimes. Use four
  complete right-facing key poses with small vertical weight shifts and a
  restrained step-through; do not splice the head and body, rotate the whole
  sprite in 3D, or add a duplicate sword trail. The continuously visible sword
  rises vertically, pauses briefly, crosses in one fast strike, and leaves a
  short follow-through. Do not turn the head or make the sword disappear
  between attacks.
- Keep the wanderer image unchanged. Use bundled pixel-art assets for the
  short sword, slime, and amber hit spark, with a restrained `+1` score label;
  use squash-and-stretch only for the slime's jump and landing, and do not add
  a large cyan slash arc or smooth glossy vector shapes around it.
- App animation settings and Reduce Motion gate the timeline. The disabled
  state uses one static encounter frame.
- Keep the physical-notch compact surface and all existing expanded-card,
  quota, navigation, visibility, and privacy behavior unchanged.

## Rejected Alternatives

- **Generate another complete warrior**: previous attempts changed identity and
  produced the bald-looking silhouette the user rejected.
- **Modify the installed pet atlas in place**: it would couple this app to
  mutable private user state and risk breaking the pet in Codex Desktop.
- **Return to the task title**: it was functionally informative but did not fix
  the user's visual-balance objection.
- **Wait for one kill cycle to finish before spawning again**: the scene reads
  like a repeated demo rather than a continuous stream of enemies.

## Consequences and Verification

The app gains one bundled image resource and a small 12 FPS SwiftUI timeline on
no-notch surfaces. Deterministic tests verify atlas geometry, overlap between
the outgoing score and incoming slime, impact feedback, loop continuity, and
motion-policy gating. Full verification must confirm that the resource bundle
is copied into the app. Real no-notch hardware must still confirm character
clarity at menu-bar scale, sword contact, `+1` legibility, lower-corner
containment, animation cadence, hover expansion, and Reduce Motion behavior.
