---
status: active
contract_ids: [ACCOUNTS-ISOLATION-064]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-11-11
last_verified_commit: null
---

# Isolate Accounts with Per-Account Codex Homes

## Context

The standalone Codex Account Switcher kept one `auth.json` per account but
switched by overwriting `~/.codex/auth.json`. That was sufficient while the
Codex app treated the home as an implementation detail. The current Codex app
stores projects, thread assignments, session history and the per-account
thread catalog inside `CODEX_HOME` (`state_5.sqlite`, `thread_history_1.sqlite`,
`.codex-global-state.json`, `sqlite/codex.db`). Those stores have no account
column, so after the 0.166 app update every account displayed the same merged
project list once the file was swapped.

The desktop app already resolves `CODEX_HOME`, and it also honors
`CODEX_ELECTRON_USER_DATA_PATH` for its Electron profile (its own demo launcher
sets both). That makes full isolation possible without patching Codex.

## Decision

- Store one raw `auth.json` per account in
  `~/Library/Application Support/CodexNotch/Accounts/Vault/<uuid>.authdata`
  (directory `0700`, files `0600`).
- Give every account a private pair of directories under
  `Accounts/Homes/<uuid>/{codex,userdata}`; seed `auth.json` on first launch and
  copy `config.toml` / `AGENTS.md` from the legacy home once.
- Switch by quitting Codex and relaunching it through `open -n` with
  `CODEX_HOME` and `CODEX_ELECTRON_USER_DATA_PATH` set. Never write
  `~/.codex/auth.json`.
- Read quota, sessions and titles from the active account's home. Fall back to
  `CODEX_HOME` / `~/.codex` while the active home does not exist yet, so
  upgrading does not blank the notch on first launch.
- Adopt accounts from the standalone switcher's `accounts.json` and
  `AuthVault` on first run instead of asking for a new OAuth login.
- Keep the account list and notes in `Accounts/accounts.json`; CodexNotch is
  the only writer.

## Rejected Alternatives

- **Keep swapping `~/.codex/auth.json`**: minimal change, but it preserves the
  merged project list that this work exists to fix.
- **Copy `~/Library/Application Support/Codex` per account**: this is what the
  0.2.x shell script did; it duplicates a large Electron profile, and the
  project data now lives in `~/.codex` anyway, so it does not isolate projects.
- **Point the desktop app at a symlinked `~/.codex`**: the switcher would have
  to repoint the symlink before every launch, and a crash between the two
  operations leaves Codex reading the wrong account.
- **Keep the standalone switcher as the account owner**: two writers to the
  same `accounts.json` and vault invite divergence; the user chose CodexNotch
  as the single owner.

## Consequences

- Each account consumes its own session database; the first switch to an
  account starts with an empty project list and no history. Legacy `~/.codex`
  data is intentionally left untouched and remains readable by launching
  Codex without the isolation variables.
- Switching takes as long as quitting and relaunching Codex.
- Adding a brand-new account currently requires importing an `auth.json`
  exported elsewhere until the isolated OAuth login is ported.
