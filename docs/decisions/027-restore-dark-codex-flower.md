---
status: active
contract_ids: [QUOTA-SEMANTICS-055, PRIVACY-APP-BUNDLE-040]
supersedes: [026-invert-original-codex-prompt]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Restore the dark flower behind the white Codex prompt

The user requested the flower background after previewing the extracted
white prompt. Reuse the original flower alpha and the unchanged extracted
prompt, composing a #242424 flower with white prompt strokes at the original
36px size. The exterior remains transparent.

Embed a two-color display image and render it in original mode. Derive the
template used for monochrome echoes from its full alpha silhouette, so the
running and green completion echoes include the restored flower. Keep
the prompt-only template as a regression guard for its unchanged contours.
ChatGPT continues to use the existing tintable template; settings, animation
timing, completion checkmark, quota selection, and geometry stay unchanged.

Do not tint the two-color foreground as a single template: that would fill
the entire flower white and hide the prompt. Do not use its original dark
colors for echoes: their running/completion state colors must remain visible.

Asset tests verify the original prompt, dark flower coverage, white prompt
contrast, transparent exterior, and unchanged geometry. Existing switching
and motion lifecycle tests remain. Full verification and real-notch contrast
and motion inspection are required.

The live echo theme follows [decision 028](028-share-weekly-quota-theme.md) and
the white foreground outline follows [decision 030](030-white-codex-flower-outline.md);
this neutral two-color image remains the Settings brand sample.
