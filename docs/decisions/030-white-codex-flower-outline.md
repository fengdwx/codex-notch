---
status: active
contract_ids: [QUOTA-SEMANTICS-055]
supersedes: [029-black-center-themed-flower-outline]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Keep the Codex foreground outline white

The user requested a white outer flower outline. Preserve the existing black
center and original white prompt with the same 88-percent inner mask and 18pt
frame. Change only the foreground outline color. The quota palette on the right,
running echo colors (including neutral white at critical quota), completion cues,
ChatGPT artwork, and Settings samples keep their existing behavior.

Render all quota bands and verify neutral pixels throughout the foreground,
black center samples, a visible white outline, and a white prompt. Integrate
fractional pixel coverage to avoid OS-dependent antialias counts. Keep the
400-pixel area ceiling and the deliberately solid-white negative control so
an opaque flower cannot pass the outline check. Real-notch contrast and motion
perception still require visual confirmation.
