---
status: active
contract_ids: [ACTIVITY-STATE-006]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-06
last_verified_commit: null
---

# Publish changed rollout activity directly

The previous path used 0.25s FSEvents delivery, a 0.5s scan coalescer, and a 1s
UI snapshot timer. It discarded FSEvents paths and enumerated the entire history
for every callback, then replayed each recent file's cached lifecycle events.
A 15s recovery sweep handled missed notifications. These waits explain ordinary
latency, but do not prove the cause of an individual long or missed transition.

Use 0.1s delivery and 0.1s bounded coalescing. Preserve callback paths and process
only changed JSONL files; directory/root and dropped-event notifications request
a full scan. Queue store publications in scan order and notify the main runtime
after each commit. The coordinator requests a snapshot immediately and rejects
older asynchronous deliveries. Its existing 1s clock/stale-state tick remains.

Shorten recovery to 5s while skipping file reads when inode, size, and modification
time are unchanged. Retain incremental line buffering, reset on replacement or
truncation, remove deleted files, and normalize paths on both enumeration and
event delivery (macOS temporary paths can alternate between /var and /private/var).
Discover newest files first so an old large rollout does not precede the current
one. Retry a failed event subscription during recovery.

Do not increase quota HTTP requests or add a constant subsecond polling loop.
Do not infer completion from silence, a tool response, or an assistant message;
only the existing lifecycle and stale rules control task state. If Codex has not
written an event yet, faster local observation cannot discover it. Apple documents
FSEvents latency as a coalescing tradeoff rather than a hard delivery deadline:
https://developer.apple.com/documentation/coreservices/1443980-fseventstreamcreate

Acceptance covers actual temporary-file FSEvents start/terminal notifications,
unchanged recovery and targeted-read counts, atomic replacement, deletion,
partial terminal lines, and stopped monitoring. Compare CPU with the same local
sampling method and report it as process CPU, not whole-system power. Real Codex
UI-to-notch latency remains a separate hardware acceptance path.

## Local verification, 2026-09-06

- macOS 26.6.2, Swift 6.3.3; installed Codex 26.901.31953 (build 7868).
- A temporary JSONL harness compiled the released monitor at `d5b46bb` and the
  updated monitor separately. Six starts and six completions per implementation
  measured file-write-to-store latency: old mean 519/520ms; new mean 121/121ms.
  This excludes Codex's own pre-write delay and the old 0–1s UI polling wait.
- The integration test exercising real FSEvents and the main-queue notification
  measured 122ms for start and 120ms for completion during full verification.
- Thirty one-second `ps` samples of the running app averaged 0.38% CPU before
  and 0.19% after. These are short process samples during ongoing work, not a
  controlled power benchmark. RSS was approximately 131MiB before and 150MiB
  after restarting the build; this sample does not establish a steady memory
  regression or attribute memory changes to the monitoring path.
- 180 tests, 67 contracts, and the full build/bundle/signing check passed.
- The rebuilt local app showed the white flower outline and correct active
  task count. A user's next real start/finish and perceived animation on the
  physical notch still need observation; synthetic file timing is not that path.
