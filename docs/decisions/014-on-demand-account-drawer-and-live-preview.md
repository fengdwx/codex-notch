---
status: active
contract_ids: [ACCOUNTS-SWITCHER-UI-066]
supersedes: [012-shared-codex-home-for-accounts.md]
superseded_by: null
owner: project-maintainer
created_at: 2026-11-14
last_verified_commit: null
---

# On-Demand Vertical Account Drawer and Hover-Live Top Quota Preview

## Context

The previous expanded-card account switcher (`d878ac0`) always rendered an open 4-row `28pt` list inside every notch hover (`+140pt` vertical height even when the user only glanced at current quota), used a `3.2s` auto-dismiss timer for confirmation that dropped pending confirmation before slow mouse movement finished, held switching/error state only inside transient SwiftUI `@State` (lost on `0.12s` hover collapse), and showed only countdown text in the header when hovering standby accounts. For users managing `5~20` accounts, scrolling through a fixed 4-row strip every hover created visual bloat and made high-quota standbys hard to scan.

## Decision

1. **Keep the shared-home backend unchanged**: keep `ACCOUNTS-SHARED-HOME-065` storage (`~/.codex/auth.json`), vault permissions (`0700`/`0600`), and `.codex-global-state.json` project-pool sync intact, and align `AccountsSettingsView` copy with the actual shared-`~/.codex` model.
2. **Quota-first vertical order with a `36pt` collapsed anchor bar**: place `AccountSwitchList` directly below `QuotaWindowsProgressView` (`ResetScheduleDisclosure`). Hide completely (`0pt`) for `<= 1` account; default-collapse to a `36pt` Anchor Bar (`+44pt` total overhead, `-96pt` saved) with deterministic monogram avatar, `K/N 可用` pool count (amber `最高 XX%` cue when active is `<= 20%`), and a `1.8s` `✓ 已切换` completion pill.
3. **On-demand vertical drawer for `5~20` accounts**:
   - Auto-trigger `refreshStaleQuotas(ttl: 120)` when opening the drawer; show lightweight `旧` tags when `> 1h` old or failed.
   - Render pure-mouse filter pills (`余量优先 (K)`, `最近使用`, `全部 (N)`) for `>= 5` accounts (`NotchPanel.canBecomeKey == false`, persisted in `UserDefaults`) plus an empty-filter rescue button (`[查看全部 N 个账号]`).
   - Cap list height at `5` visible `40pt` cards (`306pt` total drawer section) with vertical scrolling and an untimed `+36pt` inline confirmation footer.
4. **Hover-live top quota preview (`0.0pt` vertical height shift)**:
   - Hovering (or click-locking) a standby card previews its `7d`/`5h` quotas in the right-wing ring and `QuotaWindowsProgressView` bars via `AccountPreviewResolver`, marked by an inline blue pill and subtle border while locking `5h` row presence to the active account's height and keeping `ResetScheduleDisclosure` disabled (`仅当前账号`).
5. **Persistent switch lifecycle**: store `AccountSwitchPhase` (`.idle` / `.switching` / `.failed`) on `AccountsService` with concurrency protection and sanitized non-secret errors so state survives hover collapse.

## Rejected Alternatives

- **Horizontal scrollable chip strip above or below quotas**: becomes exhausting past 6–8 accounts (`"一直划"`) and cannot display rich dual-window quota context cleanly.
- **Placing the account switcher above the quota bars**: pushes daily quota bars downward and breaks the primary "open notch -> read quota first" visual rhythm.
- **Changing the top `5h` row presence dynamically during hover**: causes a `58pt` vertical jump directly underneath the cursor inside the drawer.

## Consequences

- Default notch hovers are substantially more compact (`-96pt`) while supporting `5~20` accounts cleanly on demand.
- Physical notch verification is required after building `.app` to confirm real-machine animation timing, hover preview clarity, scroll behavior, and downward expansion boundaries.
