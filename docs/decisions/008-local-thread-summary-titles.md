---
status: active
contract_ids: [CONVERSATION-TITLE-041, PRIVACY-BOUNDARY-005, ACTIVITY-STATE-004]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-07-26
last_verified_commit: null
---

# Resolve Conversation Labels from Codex Thread Summaries

## Context

One rollout may contain several user turns. The previous reducer parsed each
`event_msg/user_message` record and used its most recent value as the row
title. That made a short follow-up replace the actual conversation label and
put raw message text on the notch.

Codex already maintains a concise `title` for each immutable thread ID in
`CODEX_HOME/state_5.sqlite`. Its `first_user_message` and `preview` columns
are message-derived data and are outside CodexNotch's display boundary.

## Decision

- Rollout JSONL continues to supply only session lifecycle, thread ID, project
  directory, and timestamps. The parser ignores `user_message` payloads.
- `CodexThreadTitleReader` joins each visible thread ID to `threads.title` in
  `state_5.sqlite`, opened with SQLite read-only flags.
- The reader caches normalized short titles only in process memory. It does not
  persist them, write to the state database, or query message-derived columns.
- When the database cannot be read or has no matching row, the view retains its
  project-name fallback and thread navigation still uses the original ID.

## Rejected Alternatives

- **Use the newest rollout message**: It changes the label after every
  follow-up and exposes raw user content.
- **Use `first_user_message` or `preview`**: They remain message-derived and
  violate the privacy boundary even if they look more descriptive.
- **Fetch titles from a remote API**: Adds network dependence and credentials
  to a local status indicator when Codex already has a local summary.
- **Write a separate title cache**: Creates an unnecessary local content store
  and requires its own retention and deletion policy.

## Consequences and Verification

Rows now have stable Codex-maintained labels when the state database is
available. A missing or temporarily locked database can make a row less
descriptive, but it cannot block task state, quota, or navigation. Unit tests
protect the summary-only query and the ignored rollout payload. Real hardware
must confirm a multi-turn thread keeps the same visible title as the Codex app.
