---
status: active
owner: project-maintainer
created_at: 2026-07-17
last_verified_commit: 0d37196
---

# CodexNotch Agent Change Harness

## Goals and Adoption Level

CodexNotch uses a lightweight harness with executable acceptance checks. It is a continuously maintained native macOS app, but it currently has no online service, database migration, or required CI check. The harness prevents fixes to notch visuals or the state machine from overwriting confirmed user experience, privacy boundaries, and packaging behavior.

Completion does not mean that the code compiles. Completion must demonstrate that the requested outcome occurred, protected behavior did not regress, historical failures have guards, and any unperformed real-hardware verification is explicitly called out.

## Authority Order

When current behavior conflicts, use this order:

1. `active` contracts in `docs/contracts/behavior-contracts.yaml`;
2. `active` decisions in `docs/decisions/`;
3. Executable tests, fixtures, and verification scripts;
4. Current code and configuration;
5. README files, completed plans, chat history, and agent memory.

When tests conflict with a contract, do not delete or rewrite tests to fit the implementation. First identify which contract is being replaced and record `supersedes` in the contract.

## Before Each Change

For every L1 or higher change, state the following first. The statement may be included in the turn update, plan, or commit message:

| Item | Requirement |
|---|---|
| Change | Observable result to change |
| Preserve | Related contract IDs that must not regress |
| Out of scope | Unauthorized refactors, visual redesigns, data cleanup, releases, or permission changes |
| Risk | L0 / L1 / L2 / L3 |
| Acceptance | Automated guards, full checks, and required real-hardware checks |

Assess risk by impact, not line count:

- **L0**: Documentation, comments, or behavior-neutral cleanup; review the diff.
- **L1**: Local implementation or low-risk bug; run focused tests and `swift test`.
- **L2**: User-visible UI, quota semantics, session state, settings, or packaging; add or locate positive and negative guards, run `./scripts/verify.sh`, and inspect affected states on a physical notch.
- **L3**: Authentication, privacy, token handling, external API permissions, or a formal public release; in addition to full checks, perform human review and define a rollback path. This project has no automatic deployment, so a local package must not be described as published.

## Implementation and Regression Rules

1. Check the worktree before editing and preserve unrelated user changes.
2. For a reproducible bug, make a test or fixture fail before the fix. If it cannot be automated, record the smallest manual reproduction and an alternative acceptance method.
3. Change the smallest complete behavior; do not casually alter adjacent interactions or architecture.
4. Keep an outcome-oriented regression guard for every fixed bug; do not assert only internal calls.
5. UI changes must consider compact, expanded, running, completed, no-quota, no-notch fallback, and Reduce Motion states.
6. Never commit `CODEX_HOME/auth.json`, Authorization headers, access tokens, complete usage responses, or user-message bodies.
7. Commit each meaningful change separately; push to the personal GitHub repository only when explicitly requested.

## Verification Entry Points

| Level | Command | Scope |
|---|---|---|
| contracts | `./scripts/check_contracts.sh` | Validate the behavior-contract YAML structure and required fields |
| fast | `swift test` | Fast deterministic check for all code changes |
| full | `./scripts/verify.sh` | L2/L3: tests, release build, app bundle, and signing validation |
| release | `./scripts/release.sh` | When distributable ZIP and DMG artifacts are required; creates only local artifacts and does not upload them |

`full` does not send notifications, request real task operations, or change remote state by default. Only the local `dist/` packaging directory is updated, and that directory is ignored by Git.

## Real-Hardware Acceptance

Automated tests cannot replace visual inspection on a real notch. When a change touches the following contracts, the completion report must say whether each item was checked or still needs user confirmation:

- Whether the left and right icons are centered in their notch safe areas;
- Whether anything is covered by the camera cutout or falls below the notch;
- Whether hover expands only downward from the compact island and whether collapse stops intercepting the mouse;
- Whether the running animation, completion checkmark, quota ring/wave ball, and Reduce Motion behavior are clearly legible.

Do not use a static screenshot as proof that an animation is correct; describe the observed state and trigger.

## Documentation Lifecycle

- New behavior or an important bug fix: update the corresponding behavior contract and turn the real failure into a test or fixture.
- Important implementation choices: create a decision record in `docs/decisions/` with `status`, contract IDs, and rejected alternatives.
- Old plans are historical references only; a plan without `active` status cannot explain current behavior by itself.
- When a contract is replaced, retain the old entry, mark it `superseded`, and fill in the replacement ID.

## Project Adaptation Table

| Project question | Current answer |
|---|---|
| Key user and entry points | Mac users with a notch who are signed in to ChatGPT/Codex; compact notch, hover expansion, settings, and menu-bar fallback |
| Must not regress | Physical notch geometry, downward-only expansion, activity/completion priority, weekly quota semantics, privacy boundaries, and a runnable release app |
| Frequent hotspots | `NotchView`, `NotchRuntimeCoordinator`, `NotchWindowController`, `NotchPresentationReducer`, and quota parsing |
| Current contracts | `docs/contracts/behavior-contracts.yaml` |
| L3 | Authentication/token handling, privacy data, usage API permissions, and formal public release |
| Required CI check | Not configured; do not claim CI provides coverage |
| Deployment target | None; a release is a locally distributable archive, not automatic deployment |
| Template sections not adopted | Required CI checks, online deployment evidence, canaries, and data migrations; this project has no corresponding runtime or data layer |
