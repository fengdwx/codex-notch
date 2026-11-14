---
status: superseded
contract_ids: [ACCOUNTS-SHARED-HOME-065]
supersedes: []
superseded_by: docs/decisions/015-shared-project-continuation-across-accounts.md
owner: project-maintainer
created_at: 2026-11-12
last_verified_commit: null
---

# Synchronize the Project Pool Across Accounts

## Context

Sharing `~/.codex` does not automatically share the visible project list.
Codex keeps the project pool (projects, ordering, thread assignments, workspace
root hints) as **per-account UI state** inside `.codex-global-state.json`:

- the signed-in account's copy lives at the document root;
- every other account's copy lives under
  `electron-account-renderer-state-v1.inactive[*].globals`.

On sign-in the app swaps the stored copy into the root. Accounts that never had
a project list therefore opened with `local-projects = {}`, which the desktop
sidebar renders as “没有项目”, even though the app-server still served the same
projects and the shared thread history was intact.

## Decision

- Before relaunching Codex on an account switch, copy the current project pool
  from the document root into every stored account entry (and keep it at the
  root). The keys are: `local-projects`, `project-order`,
  `thread-project-assignments`, `thread-project-membership-host-ids`,
  `thread-workspace-root-hints`, `thread-projectless-output-directories`,
  `projectless-thread-ids`, `project-appearances`,
  `sidebar-project-thread-orders`,
  `app-server-project-id-by-legacy-project-id-by-host`,
  `app-server-projects-migration-by-host`.
- Run the copy after Codex has fully quit (so the renderer flushed its state)
  and before the new instance launches.
- If the current root pool is empty, fall back to the account entry that holds
  the largest `local-projects`; if none has data, leave the file untouched.
- Keep one rollback snapshot next to the state file
  (`.codex-global-state.json.pre-sync`) before every write.
- Never delete project data. Existing per-account fields unrelated to projects
  stay untouched.

## Rejected Alternatives

- **Only swap `auth.json`**: leaves the other accounts with their old empty UI
  state, which is exactly the reported “没有项目” bug.
- **Migrate every account to a per-account `CODEX_HOME`**: changes the product
  into the isolated-home model the user explicitly rejected.
- **Patch the running renderer through DevTools**: fragile across app updates
  and cannot run before sign-in.

## Consequences

- Switching accounts preserves one project pool; accounts still keep their own
  selected project, window state and quota.
- The synchronization is idempotent and runs on every switch, so accounts that
  were previously empty become populated after their first switch.
