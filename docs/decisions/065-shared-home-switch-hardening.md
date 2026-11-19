---
status: active
contract_ids: [ACCOUNTS-SHARED-HOME-065]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-11-19
last_verified_commit: null
---

# Harden Shared-Home Account Switching

## Context

The shared `~/.codex` design keeps every entry point (Dock, Spotlight, terminal
CLI, IDE, CodexNotch) in one world, but the 1.0.0 switch path had three gaps:

- it captured the outgoing token **before** quitting Codex, so a token rotated
  during shutdown could be missed and a stale Vault copy could win;
- it never compared freshness, so an older auth payload could overwrite a newer
  one;
- it only quit `com.openai.codex`, while standalone `codex` CLI/IDE processes
  can keep writing the same `auth.json`, and a failed relaunch left Codex
  closed with the target account already written.

## Decision

`AccountsService.switchTo(_:force:)` now runs in this order:

1. Refuse to switch when `cdx` CLI/IDE sessions are detected, unless `force` is
   true. Detection ignores processes under `/Applications/ChatGPT.app`.
2. Best-effort capture of the current `~/.codex/auth.json` into the Vault.
3. Quit Codex and wait for it to exit (including the renderer flush delay).
4. Capture again; this authoritative capture only replaces the Vault copy when
   `AccountAuthFreshness` says the file is newer (`last_refresh`, JWT `iat`).
5. Write the target `auth.json` atomically and synchronize the project
   continuation state (contract 067).
6. Relaunch Codex. On any failure after step 3, restore the previous auth and
   relaunch the previous account before rethrowing; the active account is
   persisted only after a successful launch.

Explicitly rejected: per-account `CODEX_HOME`, APFS cloning/merging of
`state_*.sqlite`, rewriting `creator_account_id`, and rotating
`installation_id`. Those either break the one-world property or fake client
identity without preventing server-side correlation.

## Consequences

- Switching is a token swap plus a Codex relaunch; no multi-GB copies.
- A stale Vault copy can no longer overwrite a fresher rotated token.
- Standalone CLI sessions block switching with a clear, non-sensitive message.
- A failed relaunch restores the previous account instead of leaving Codex
  closed.
