---
status: active
contract_ids: [QUOTA-SEMANTICS-049]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-07-27
last_verified_commit: null
---

# Move Persistent Quota Motion into Visible-Only Core Animation Layers

## Context

The 22pt quota ring and wave ball originally used SwiftUI `TimelineView` to
rebuild an angular gradient or a 28-sample wave path on every requested frame.
Reducing those timelines from 8 FPS to 4 FPS lowered CPU use but made the motion
visibly rough on physical-notch hardware. The user confirmed that 8 FPS remains
visually acceptable.

Comparable open-source notch apps use AppKit views with `CAShapeLayer` and
`CABasicAnimation` for persistent visualizers, and explicitly stop their timers
or animations when the view is detached or inactive.

## Decision

- Keep the user-confirmed visual cadence at a preferred 8 FPS.
- Render the running ring with a conic `CAGradientLayer`; keep the existing
  SwiftUI arc as a static mask and rotate only the gradient layer.
- Build the wave path only when its geometry or liquid level changes. Extend it
  by one wavelength and animate only the layer's horizontal translation.
- Use `CAFrameRateRange` to request the 8 FPS cadence for both persistent layer
  animations.
- Remove the layer animations when motion is no longer requested, the view is
  dismantled, or its window is no longer visible. Recreate them only when both
  the running state and visible surface require motion.
- Keep quota values, warning colors, progress transitions, accessibility
  behavior, the fixed transparent canvas, and all window geometry in SwiftUI
  and the existing AppKit controller.

## Rejected Alternatives

- **Keep the 4 FPS SwiftUI timelines**: Lower CPU, but the motion was visibly
  rough on the real notch.
- **Restore 8 FPS SwiftUI timelines**: Visually acceptable, but still rebuilds
  gradient stops and the sampled wave path eight times per second.
- **Use a 60 FPS Canvas**: Improves visual density but retains continuous
  SwiftUI scheduling and exceeds the requested power budget.
- **Restore frame-by-frame NSPanel resizing**: Reintroduces historical layout
  crashes and window jumping and is unrelated to quota motion.

## Consequences and Verification

- App-process CPU should fall because persistent frames no longer evaluate the
  SwiftUI indicator body, although WindowServer and GPU work still requires
  measurement.
- The layer implementation has a lifecycle boundary that must remain covered by
  tests and runtime sampling.
- Run the focused quota tests and `./scripts/verify.sh`, then inspect ring
  direction, wave level, stopped states, animation preference, and Reduce Motion
  on physical-notch hardware. Automated tests cannot prove perceived smoothness.
