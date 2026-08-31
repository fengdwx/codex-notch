---
status: superseded
contract_ids: [NOTCH-VISIBILITY-045]
supersedes: [013-no-notch-floating-bar]
superseded_by: 015-no-notch-task-status-island
owner: project-maintainer
created_at: 2026-08-10
---

# Attach a Compact Activity Island to the Top of No-Notch Displays

## Context

The first no-notch implementation did make CodexNotch visible, but it reused
the physical-notch 257pt compact width and positioned the panel below the menu
bar plus an eight-point gap. That left a large empty camera lane on hardware
where no camera cutout exists and made the surface look detached from the
screen. The user rejected that real-machine result and referenced Vibe Island's
top-attached, content-filled status presentation.

## Decision

- Keep the existing `floatingBar` mode as the no-notch implementation boundary,
  but give it a dedicated compact width rather than the physical camera-gap
  minimum.
- Anchor compact and expanded frames to `screen.frame.maxY`; the panel occupies
  the center of the menu-bar region rather than sitting below it.
- Use a top-attached shape with a flat top edge and rounded lower corners.
- Fill the compact center lane with original pixel art: idle is a still
  face-off, running is an 8 FPS four-frame sword loop, and completed is a still
  victory frame. App animation settings and Reduce Motion gate the loop.
- Preserve the left Codex state mark and right quota indicator. The physical
  notch path does not render the battle scene.
- Reserve the compact attachment height before no-notch expanded content and
  reclaim the larger transparent panel canvas after collapse.

## Rejected Alternatives

- **Tune the existing 257pt bar only**: Removing the vertical gap would not fix
  the empty camera lane or the incorrect no-notch information density.
- **Play the battle continuously in every state**: It would obscure task state,
  waste power while idle, and conflict with Reduce Motion.
- **Copy Vibe Island sprites or assets**: The reference informs attachment and
  density, while CodexNotch keeps original visuals and behavior.
- **Change the physical-notch compact layout too**: That path has hardware-safe
  camera clearances and user-confirmed geometry that are outside this change.

## Consequences and Verification

No-notch users gain a smaller, top-attached status surface whose middle conveys
activity rather than simulating a camera gap. Geometry and motion-policy tests
guard the mode boundary. A screenshot can confirm size and attachment, but
animation timing, hover expansion, click routing, and canvas reclamation still
require real-hardware confirmation.
