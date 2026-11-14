---
status: active
contract_ids: [ACCOUNTS-PROJECT-CONTINUATION-067]
supersedes: [013-sync-project-pool-across-accounts.md]
superseded_by: null
owner: project-maintainer
created_at: 2026-11-15
last_verified_commit: null
---

# Share Active Project and New Chat Continuation Across Account Switches

## Context

In earlier Codex Desktop versions (`013`), switching accounts inside shared `~/.codex` swapped `electron-account-renderer-state-v1` globals. Newer Codex Desktop releases migrated the shared project pool (`local-projects`, `project-order`, `thread-project-assignments`) to top-level scope and removed `electron-account-renderer-state-v1`, which meant the legacy synchronizer found nothing to copy.

At the same time, current Codex Desktop still partitions active workspace continuation per account owner hash (`ownerHash = sha256(JSON.stringify([userId, accountId]))`):

- `electron-owner-value:<key>:<ownerHash>` stores `selected-project`, `active-workspace-roots`, `electron-saved-workspace-roots`, and workspace hints.
- `electron-account-remote-preference:<key>:<ownerHash>` stores `selected-remote-host-id`, `active-remote-project-id`, and remote connection preferences.
- `electron-owner-atoms:<ownerHash>` stores sidebar/composer atoms plus `new-task-project-by-computer` keyed by `[accountId, userId, hostId]`, which directly drives the New Chat composer's project dropdown.
- Future Codex builds also activate `.codex-global-state.sqlite` (`PRAGMA user_version != 0`, table `settings(scope, key, value)`) mirroring those scopes.

As a result, switching from Account A to Account B left Account B either on an older unrelated project (for example `skillops`) or with missing workspace roots and New Chat falling back to its cached/empty target.

## Decision

1. **Identify outgoing and incoming owner hashes cleanly**: parse `userIdentifier` (`chatgpt_user_id` / `user_id`) alongside `accountIdentifier` in `AccountIdentity` and compute Codex's exact lowercase hex SHA-256 `ownerHash`.
2. **Synchronize both legacy and modern stores before relaunching Codex**:
   - In `AccountsService.switchTo(_:)`, extract outgoing `sourceIdentity` before overwriting `~/.codex/auth.json` and pass `(sourceIdentity, targetIdentity)` to `SidebarProjectSynchronizer.synchronizeCodexHome(_:)`.
   - Copy `electron-owner-value:*` continuation keys, safe `electron-account-remote-preference:*` keys (removing stale `active-remote-project-id` when switching from a local project selection), whitelisted sidebar/composer atoms, and rewrite/seed `new-task-project-by-computer` entries for destination owners — including creating entries for a target account that has never signed into the current Codex Desktop build.
   - Keep `electron-renderer-content-owner` untouched so Codex executes its normal `confirmContentOwner` transition on launch, backfill missing workspace roots from discovered owners rather than wiping folders, and never copy account-private atoms or `app-server-pending-project-deletions-by-host`.
   - Also sync `.codex-global-state.sqlite` whenever `PRAGMA user_version != 0`, keeping `.pre-sync` backups before writing either store.

## Consequences

- Switching accounts inside CodexNotch lands on the exact same sidebar project, workspace folders, and New Chat project picker as the previous account.
- Existing private per-account UI caches (`cloud-aeon-profiles-v1:*`, `space-page-pin-projection-owners-v1`, `query-seed:*`, onboarding flags) remain isolated per owner.
