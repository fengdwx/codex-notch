---
status: active
contract_ids: [ACCOUNTS-SHARED-HOME-065]
supersedes: [011-per-account-codex-home.md]
superseded_by: null
owner: project-maintainer
created_at: 2026-11-12
last_verified_commit: null
---

# Keep One Shared Codex Home for Every Account

## Context

Isolating each account in its own `CODEX_HOME` fixed the merged-project
problem, but it changed the product in a way the user does not want: every
project, session and window state is per account, and the first switch to an
account opens a fresh Codex that looks exactly like a new installation. The
user confirmed the opposite preference: all accounts should see the same pool
of projects and history, and switching should only change which account (and
quota) is active.

## Decision

- Keep the original `~/.codex` as the only Codex home.
- Switching captures the running tokens from `~/.codex/auth.json` into the
  account vault, writes the target account's `auth.json` back atomically
  (`0600`, directory `0700`), then quits and relaunches Codex without
  `CODEX_HOME` or `CODEX_ELECTRON_USER_DATA_PATH`.
- The notch always reads the shared home, so projects, recents and task state
  are identical across accounts; only quota and the active badge change.
- Per-account storage remains for credentials, notes and cached quota, never
  for projects or sessions.
- Quota for the active account prefers the shared `auth.json` because Codex
  refreshes its tokens in place there.

## Rejected Alternatives

- **Per-account `CODEX_HOME` + Electron user data**: guarantees isolation but
  produces an empty-looking Codex after the first switch and contradicts the
  user's preference for a shared project pool.
- **Per-account homes plus a one-time clone of `~/.codex`**: keeps history for
  the first account only, adds a multi-gigabyte copy, and still hides projects
  from other accounts.
- **Symlinking `~/.codex` to per-account directories**: two writers and a
  crash-prone swap path for no user-visible benefit now that sharing is the
  goal.

## Consequences

- Projects and sessions are intentionally shared; a thread created under one
  account is visible under every account.
- Switching is a token swap plus a Codex relaunch; nothing is migrated or
  copied.
- The notch can no longer show "which account created this thread"; it shows
  the currently logged-in account and its quota.
