---
status: superseded
contract_ids: [QUOTA-SEMANTICS-051, PRIVACY-APP-BUNDLE-040]
supersedes: []
superseded_by: 027-restore-dark-codex-flower
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Invert the original Codex prompt and remove its flower body

The user clarified that the existing asset should be inverted and its dark
flower removed. The screenshot illustrates the contrast; it is not the
source of a regenerated mark.

Derive the replacement once from the embedded 36px Codex artwork: preserve
the exterior transparency, invert alpha only in the enclosed prompt strokes,
normalize the brightest stroke pixel to white, and remove isolated low-alpha
source specks. Keep the original chevron/underscore contours and positions.
Embed the resulting PNG in `CodexMarkAsset` with the same 18pt template size.
No image processing or external asset lookup occurs at runtime.

The shared status renderer and echo already consume this template, so both
update together. Keep ChatGPT artwork, settings persistence, quota priority,
motion timing, the green checkmark, and window geometry unchanged.

Rejected: inverting the entire alpha canvas (creates a white background),
keeping the flower black against the black notch (loses its silhouette), or
generating a substitute glyph from the settings screenshot (changes the
source artwork against the user's correction).

`AppIconAssetTests` checks a sparse white alpha mask with exactly two connected
strokes and transparent surroundings; the former filled flower fails this
guard. Run `./scripts/verify.sh` and inspect the real notch. Physical readability
and motion still require user confirmation.
