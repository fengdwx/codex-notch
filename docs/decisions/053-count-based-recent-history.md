---
status: active
contract_ids: [ACTIVITY-STATE-007]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-14
---

# Retain recent conversations by count, not age

The July 16 implementation (`1e9fe5c`) extended completed-history retention
from the active store's six-hour lifetime to 24 hours. The original rollout
monitor (`7a6ac7a`) already scanned only the last day. The design recorded the
chosen duration without a requirement explaining why older conversations
must disappear. In v0.2.2, both layers still discarded older records, making
the count setting appear broken after two idle days.

## Change and preserved behavior

This is an L2 correction explicitly requested by the user. Supersede only the
age cutoff in ACTIVITY-STATE-006 with ACTIVITY-STATE-007. Keep the six-hour
unfinished-task stale fallback, running priority, completion matching,
child exclusion and ordered event delivery. Preserve SETTINGS-WINDOW-022,
SETTINGS-MOTION-021, DISPLAY-TRANSITION-010, CONVERSATION-TITLE-042,
PRIVACY-BOUNDARY-006 and PACKAGE-VERIFY-006. Visual redesign, quota changes,
new permissions and public releases are out of scope.

## Decision

Remove age-based removal from the completion store and discovery path.
Enumerate metadata newest first. Process every file in the active window,
then continue backward until five distinct completed threads have been found
and remaining files predate the oldest needed completion. The user explicitly
accepted retaining five candidates and applying the configured 0–5 limit at
presentation, so increasing the setting does not need another disk read. File
modification time bounds the lifecycle events appended to a local rollout; a recently
touched file with only old completions must not stop discovery too soon.
Reuse fingerprints and incremental cursors. Evict unneeded older scan state,
and backfill after deletion on the existing recovery scan. No new Codex
database columns, message contents or persistent caches are needed.

## Rejected alternatives

- Increase the cutoff to seven or thirty days: the same failure returns after
  a longer break, and the count setting still has a hidden time limit.
- Remove the active stale fallback too: abandoned turns would appear running.
- Parse every historical JSONL on every launch: this machine already has about
  953 MiB of rollout logs; only enough valid recent history is needed.
- Stop after five files: children, duplicate threads and unfinished tasks
  would consume slots and hide valid older conversations.

## Validation

Guards cover restart with weeks-old history, all count settings, stale and
child exclusion, duplicate threads, bounded historical reads, unchanged
recovery, deletion and backfill. Run the full verification script, install
the verified local build with a backup, and check actual history counts.
Physical-notch geometry and perceived motion still require real hardware
confirmation; this change does not alter their implementation.


### Local verification, 2026-09-14

- Before the fix, the store regression discarded the synthetic completion at
  2, 30 and 365 days. After the fix, all three ages retain history and reject
  stale unfinished work.
- The full check completed with 233 passing tests, zero failures and two
  opt-in native animation captures skipped; 94 contracts, release build,
  bundled resources and code signatures passed.
- A read-only probe compiled from the production monitoring and presentation
  sources loaded five completed threads, including three older than 24 hours.
  It read five JSONL files (10.57 MiB) in about 0.17 seconds for that snapshot;
  unchanged recovery added zero reads, and display settings 0–5 produced
  exactly 0–5 rows. These are local sample measurements, not a latency bound.
- The verified app replaced the installed v0.2.2 bundle after backing it up.
  Relaunch and Settings inheritance were checked. Physical-notch expansion
  and perceived animation still require real hardware confirmation.
