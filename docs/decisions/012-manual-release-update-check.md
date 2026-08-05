---
status: active
contract_ids: [APP-UPDATE-001]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-08-05
last_verified_commit: null
---

# Check public releases manually from Settings

## Context

CodexNotch distributes verified ZIP and DMG archives through GitHub Releases.
Users need a way to tell whether the installed app is behind the latest stable
release, but a full updater would introduce archive installation, signing,
rollback, and background-network behavior that the app does not currently own.

## Decision

- Add a manual **Check for Updates** action to the existing Settings window.
- Query GitHub's public `releases/latest` metadata endpoint with an
  unauthenticated `GET` request.
- Compare the `tag_name` with the bundled `CFBundleShortVersionString` after
  normalizing an optional `v` prefix.
- Show an up-to-date result, a newer stable version with a link to the GitHub
  release page, or a non-blocking failure message.
- Do not download, install, poll in the background, or send Codex credentials,
  rollout data, quota data, or user content to GitHub.

## Rejected alternatives

- **Automatic background checks:** Adds network activity without an explicit
  user action and needs a lifecycle, frequency, and notification policy.
- **Automatic archive download/install:** Needs a trusted updater, signature
  policy, rollback behavior, and a separate permission boundary.
- **Scrape the GitHub releases HTML page:** Less stable than the public API and
  makes version and stable-release filtering harder to verify.
- **Use Sparkle now:** A dependency and signing/notarization workflow would be
  disproportionate to the requested manual visibility check.

## Consequences

- Settings can answer the common “am I current?” question without changing the
  notch runtime or exposing private data.
- Network failure is visible only in Settings and never replaces the last
  successful quota or task state.
- Installing a release remains a deliberate user action through the linked
  GitHub page.
