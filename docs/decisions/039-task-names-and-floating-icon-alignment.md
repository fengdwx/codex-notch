---
status: active
contract_ids: [CONVERSATION-TITLE-042, PRIVACY-BOUNDARY-006, FLOATING-ICON-052, FLOATING-CENTER-051]
supersedes: [008-local-thread-summary-titles.md]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
last_verified_commit: null
---

# Resolve Current Task Names and Balance Floating Status Marks

## Change boundary

This L2 repair changes displayed task names and floating status-mark alignment.
Preserve immutable thread navigation, lifecycle and quota semantics, read-only
metadata access, the accepted card motion, and physical-notch camera clearance.
Changing Codex's own data, processing message bodies, altering icon artwork,
new dependencies, releases and unrelated UI redesign are out of scope.
Acceptance requires failing title regressions before the repair, the full
verification script, native completed/running visual fixtures, and installed
app readback. Mirrored-display aesthetics and physical-notch placement still
require user confirmation where they cannot be exercised automatically.

## Evidence and decision

The reported task IDs have concise names in `session_index.jsonl`; their SQLite
`threads.title` values instead retain an attachment wrapper and an escaped
initial prompt. This is a source-selection bug, not damaged font rendering.
Codex's [session index implementation](https://github.com/openai/codex/blob/main/codex-rs/rollout/src/session_index.rs)
appends name updates, with the last matching record taking precedence. Resolve
that metadata first, using the existing read-only SQLite lookup as fallback.
Ignore malformed index records. Cache only normalized requested names in memory.
Index or actual `state_5.sqlite-wal` changes invalidate the reader cache.

Normalize plain text entities without invoking an HTML renderer. Reject known
transport wrappers and overlong prompt-like values instead of exposing their
first 96 characters. If no short name is available, retain the project fallback.
Never derive a title from a request body or write a rename back into Codex.

The floating mark previously centered its 18pt flower but placed an 11pt badge
outside the bottom-right bounds. Use a 20pt flower, a 9pt badge, and center the
combined bounds including the badge border. Keep the existing 22pt indicator
slot, 30pt lane, and 212pt surface. Match both indicator containers to the
measured floating height. The physical-notch configuration remains unchanged.

## Rejected alternatives

- Extract text following `My request`: still displays message-derived content.
- Rename tasks or repair Codex's database: exceeds a local display fix.
- Render HTML to decode entities: unnecessary parsing and UI-thread work.
- Shift the entire island or widen lanes: changes accepted geometry without
  addressing the badge's local visual weight.

## Verification

- Synthetic title-reader tests reproduce stale source precedence, entity text,
  attachment wrappers, rename refresh, missing databases and malformed records.
- Readback checks ensure title lookup does not mutate its index or database.
- The native motion fixture adds a completed scenario for before/after inspection.
- Run `./scripts/verify.sh`, rebuild and restart the installed app, then verify
  displayed names and compact geometry. Static captures do not certify hover
  motion or physical-notch hardware placement.

Validation on 2026-09-13: the seven focused title tests passed after reproducing
the failures. Full verification passed with 205 tests and one opt-in capture
skipped. Separate completed and running native capture runs passed, including
final compact-frame recovery. The installed app was restarted and its active
button exposed the current indexed name without a wrapper or entity sequence;
its binary matched the verified build and its runtime log remained empty.
The real expanded list and physical-notch positioning still need user visual
confirmation; the native captures use synthetic task data.
