<div align="center">

<img src="Resources/AppIcon.svg" width="180" alt="CodexNotch app icon">

# CodexNotch

**Weekly & 5-hour Codex quota, exact reset countdowns, live task state, and shared-home multi-account switching—right beside your MacBook notch.**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)](https://github.com/fengdwx/codex-notch/releases/latest)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](Package.swift)
[![Latest Release](https://img.shields.io/github/v/release/fengdwx/codex-notch?label=release&color=2ea44f)](https://github.com/fengdwx/codex-notch/releases/latest)
[![MIT License](https://img.shields.io/badge/License-MIT-4c8bf5)](LICENSE)
[![LINUX DO](https://img.shields.io/badge/LINUX-DO-FFB003.svg)](https://linux.do)

[**Download Latest Release**](https://github.com/fengdwx/codex-notch/releases/latest) · [**Watch 1080p Video**](docs/assets/codex-notch-demo-en.mp4) · [**v2.1.0 Release Notes**](docs/releases/2.1.0.md) · [简体中文](README.zh-CN.md)

</div>

[![CodexNotch v2.1.0 product demo](docs/assets/codex-notch-demo-en.gif)](docs/assets/codex-notch-demo-en.mp4)

<p align="center"><sub>Real v2.1.0 UI demo (synthetic sample accounts): notch quota & task pulse, live hover comparison & shared-home account switching, External Island modes, and macOS Settings.</sub></p>

---

## At a Glance

CodexNotch keeps your ChatGPT/Codex quota and task state pinned beside your physical notch (or centered at the top of external/notchless displays as an **External Island**) without depending on any third-party notch host.

| What you need | How CodexNotch handles it |
| --- | --- |
| **Always-visible quota** | Weekly quota stays in the right lane (`Clockwise ring` or `Wave ball`); on notched displays, 5-hour quota appears on the left when returned, otherwise showing your chosen status mark (`Codex` / `ChatGPT` / `Off`). |
| **Exact resets & credits** | Hover to view 5h and 7d progress bars, exact reset timestamps, live second-by-second countdowns, and manually confirmable **Use reset** credits. |
| **Live task pulse & jump** | Distinguishes running, idle, and a ~5s green completion check. Click any active or recent conversation to open `codex://threads/<thread-id>` directly. |
| **Multi-account switching** | Save multiple logins locally (`0700`/`0600` vault), compare `5h + 7d` limits by hovering standby cards, and switch on one shared `~/.codex` workspace without losing projects or threads. |
| **Lightweight & reversible** | Show or hide anytime with `⌥⌘N`, customize in native macOS Settings (`Cmd+,`), and update safely via Ed25519-verified Sparkle releases. |

---

## Core Features

### 1. Notch & External Island Display

- **Physical-notch Macs**: Left and right compact indicators align inside `24pt` safe-area containers clear of the camera housing. Hovering expands smoothly downward inside a pre-allocated transparent canvas and releases hit-testing immediately on collapse.
- **External & notchless screens (External Island)**: Renders a pill centered at the top edge of the display with four center styles previewable in **Settings → External Island**:
  - **Signature**: Animated rhythm bars + subtle text shimmer while running (supports custom text up to 12 characters).
  - **Orbit text**: Orbiting dot beside custom text while running; ring and dash at rest.
  - **Task timer**: Live elapsed task timer while running (`MM:SS` / `H:MM:SS`).
  - **Minimal flow**: Centered light flow while running, dimmed at rest, with a brief green checkmark on completion.
- **Accurate window & color semantics**: Quota windows are classified dynamically from `limit_window_seconds`, preventing 7-day-only plans from masquerading as 5-hour windows. Colors reflect remaining quota (`> 20%` green, `11–20%` amber, `<= 10%` red, gray when unavailable).

### 2. Shared-Home Multi-Account Switching

Rather than creating fragmented per-account `CODEX_HOME` folders that break your project list and session history, all accounts share `~/.codex`:

1. **Three clean onboarding paths** (**Settings → Accounts**):
   - **+ Sign in**: Browser-sandbox OAuth login via an isolated `app-server` process—adds or refreshes an account without signing out of your running Codex desktop session.
   - **Import auth.json**: Import an exported `auth.json` file directly into the vault.
   - **Adopt local login**: Capture the currently active `~/.codex/auth.json` session.
2. **Quit-first atomic swap & project continuation**:
   - Before switching, CodexNotch inspects active processes and refuses cleanly if external Codex CLI/IDE sessions hold `~/.codex/auth.json`.
   - Quits Codex first so rotated tokens flush to disk, compares token freshness (`last_refresh`, JWT `iat`/`exp`) so older copies never overwrite newer tokens, atomically swaps `~/.codex/auth.json`, synchronizes `.codex-global-state.json` project/New-Chat continuation state, and automatically restores the previous session if relaunch fails.
3. **On-demand notch drawer & live hover preview**:
   - Collapses to a compact `36pt` anchor bar by default (`K/N` healthy pool summary and `Switched` badge).
   - Expands into a scrollable drawer (`Available`, `Recent`, and `All` filter pills when 5+ accounts are saved).
   - Hovering any standby card previews its `5h` and `7d` limits at the top of the card with zero vertical height jump, and clearly flags signed-out (`Re-auth`) or unavailable accounts.

---

## Install

Requires **Apple Silicon** and **macOS 14 Sonoma or later** (no Xcode or Swift toolchain needed).

1. Download the latest `.dmg` (recommended) or `.zip` from [**GitHub Releases**](https://github.com/fengdwx/codex-notch/releases/latest).
2. Drag `CodexNotch.app` into `/Applications`.
3. Sign in to ChatGPT / Codex at least once, then launch **CodexNotch**.
   - Public builds currently use ad-hoc code signing (not notarized by Apple). On first launch, choose **Open Anyway** in **System Settings → Privacy & Security**, or Control-click the app and choose **Open**.
   - By default CodexNotch reads `~/.codex` (or `$CODEX_HOME` if exported before launch).

---

## Controls & Settings

Press **`⌥⌘N`** globally, right-click the notch/island, or use the top-right controls inside the expanded card (`Notch On/Off` pill & `Settings` button / **`Cmd+,`**):

| Tab | What you can configure |
| --- | --- |
| **General** | Launch at login · Live Chinese / English UI switch (`English` default) · Recent tasks in expanded card (`Hide`, `1`, `2`, `3`) |
| **Appearance** | Live physical-notch preview · Right quota style (`Clockwise ring` / `Wave ball`) · Left indicator (`Codex` / `ChatGPT` / `Off`) · Animations toggle (honors both in-app toggle and system **Reduce Motion**) |
| **External Island** | Live external/notchless stage preview (`Running` / `Idle` / `Completion cue`) · Center style & up-to-12-character custom text |
| **Accounts** | Browser-sandbox **+ Sign in**, `auth.json` / local-session import, inline name & local-only note editor, per-account/bulk quota refresh, Finder reveal (`~/.codex`), export, delete, and switch/relaunch |
| **Sidebar Footer** | **Check Updates** (manual Ed25519-verified Sparkle updates) · **GitHub** repository shortcut |

> When the notch/island is hidden, press **`⌥⌘N`** again or hover the physical notch top edge to bring controls back.

---

## Privacy & Scope

- **Local `0700`/`0600` credential vault**: Account payloads reside strictly in `~/Library/Application Support/CodexNotch/Accounts/Vault` with owner-only POSIX permissions and are never uploaded or logged.
- **Read-only quota polling**: Usage endpoints are read-only; reset credits are only redeemed after an explicit confirmation dialog (**Use reset**).
- **Minimal local log access**: Task activity reads rollout JSONL streams in `CODEX_HOME/sessions`; conversation titles read `session_index.jsonl` and read-only `state_5.sqlite` metadata without retaining message bodies.
- **Zero telemetry**: Update checks fetch a static public `appcast.xml` via Sparkle 2.9.6 without sending account, quota, or usage identifiers.
- **Intentional non-goals**: CodexNotch monitors `com.openai.codex` (not ChatGPT Classic `com.openai.chatgpt.classic`), never kills background Codex sessions silently, does not calculate API billing, and performs no cloud sync or unattended updates.

---

<details>
<summary><strong>Build & Verify from Source</strong></summary>

Requires Xcode 16+ targeting macOS 14.0+ (GitHub CI builds on `macos-15` with Xcode `16.2`):

```sh
swift test
./scripts/verify.sh
./scripts/build_app.sh
open dist/CodexNotch.app
```

Create distributable ZIP, DMG, SHA-256 checksums, and a Sparkle-signed `dist/appcast.xml` (requires publisher Keychain Ed25519 key; see [docs/updating.md](docs/updating.md) and [docs/agent-harness.md](docs/agent-harness.md)):

```sh
RUN_TESTS=0 ./scripts/release.sh
```

Skip ad-hoc signing during local iteration:

```sh
SIGN_IDENTITY=none ./scripts/build_app.sh
```

</details>

---

## Acknowledgments & References

CodexNotch is a standalone native macOS app with zero runtime dependency on external notch hosts. Thanks to the open-source projects, frameworks, and community efforts that inspired or support this project:

- [**Atoll**](https://github.com/Ebullioscopic/Atoll) — Inspired CodexNotch's fixed transparent canvas layering, damped spring transitions, and non-intrusive hover interaction beside the physical notch (documented in [ADR 001](docs/decisions/001-fixed-canvas-notch-motion.md), [ADR 035](docs/decisions/035-spring-card-transitions.md), and [ADR 045](docs/decisions/045-hover-response-and-shadow.md)).
- [**Codex Account Switcher (`pengshengege/CodexAccountSwitcher`)**](https://github.com/pengshengege/CodexAccountSwitcher) — Inspired CodexNotch's isolated `CODEX_HOME` OAuth login flow, `0700`/`0600` local credential vault, local account notes, and archive-before-swap `~/.codex/auth.json` Desktop switching model.
- [**Sparkle**](https://github.com/sparkle-project/Sparkle) — Powers Ed25519-verified, user-initiated in-app updates ([Documentation](https://sparkle-project.org/documentation/)).
- **macOS & Codex Open-Source Ecosystem** — Fellow explorations around local AI quota visibility and developer workflows such as [**CodexBar**](https://github.com/steipete/CodexBar) and [**CC Switch**](https://github.com/farion1231/cc-switch), plus real-hardware feedback from the [LINUX DO](https://linux.do) community.

---

## License

Released under the [MIT License](LICENSE). If CodexNotch keeps your quota in sight and saves a few context switches, consider giving it a Star.
