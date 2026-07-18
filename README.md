<div align="center">

# CodexNotch

### Your Codex quota—always in sight.

**Weekly quota, exact reset times, and task status stay beside your MacBook notch.**<br>
Your browser, IDE, or any other app can be frontmost—your quota remains visible.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)](https://github.com/fengdwx/codex-notch/releases/latest)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](Package.swift)
[![Latest release](https://img.shields.io/github/v/release/fengdwx/codex-notch?label=download&color=2ea44f)](https://github.com/fengdwx/codex-notch/releases/latest)
[![MIT License](https://img.shields.io/badge/License-MIT-4c8bf5)](LICENSE)

[**Download the latest release**](https://github.com/fengdwx/codex-notch/releases/latest) · [**Watch the 26-second demo**](docs/assets/codex-notch-demo-en.mp4) · [简体中文](README.zh-CN.md)

</div>

[![CodexNotch English product demo](docs/assets/codex-notch-demo-en.gif)](docs/assets/codex-notch-demo-en.mp4)

<p align="center"><sub>Real app capture with English product callouts: weekly quota, exact reset time, every reset-credit expiry, cross-app visibility, and live task status.</sub></p>

## Why CodexNotch exists

Codex quota is easy to lose behind other windows. CodexNotch keeps the answers that matter beside your MacBook notch, wherever you work:

- **How much weekly quota is left?**
- **Exactly when does it reset?**
- **Is the task still running?**

They remain beside the physical notch while you code, browse, write, or work in another app.

> **One glance at the notch: quota, reset time, and task status—without changing apps.**

## At a glance

| What you want to know | What CodexNotch shows |
| --- | --- |
| **How much quota remains?** | A persistent weekly-quota ring or wave ball beside the notch, with the number inside the indicator. |
| **When will quota reset?** | The exact reset timestamp plus a second-by-second countdown in the expanded card. |
| **When does each reset credit expire?** | Click **N reset credits available** to reveal every precise expiry time and countdown. |
| **What happens when I switch apps?** | Nothing disappears. Quota and status stay visible while another app is frontmost. |
| **Is the task running?** | A blue activity echo while Codex works, then a clear green check when it finishes. |

## The experience

### Quota at a glance, in every app

The weekly-quota indicator stays beside the physical notch even when no task is active. Switch to your browser, IDE, or another app and the remaining percentage stays visible.

### Exact reset timing, not just a percentage

Hover over the notch to reveal:

- Weekly quota and a horizontal progress bar
- The exact reset timestamp and live countdown
- The precise expiry time of every available reset credit
- Active tasks and recent conversations

Quota windows are identified from the returned `limit_window_seconds`; CodexNotch does not hard-code a five-hour assumption.

### Your quota follows you across apps

CodexNotch is a standalone native macOS app. It does not depend on Atoll, CodexIsland, CC Switch, or another host. Your browser, IDE, or any other app can stay in front while quota, reset time, and task status remain visible.

### Task status in the same place

While Codex works, a blue activity echo shows that the task is still running; completion switches to a clear green check. Click a task in the expanded card to open `codex://threads/<thread-id>` instead of searching for the conversation again.

## Install

Download `CodexNotch-...zip` from [**GitHub Releases**](https://github.com/fengdwx/codex-notch/releases/latest):

1. Unzip the archive.
2. Drag `CodexNotch.app` into Applications.
3. Sign in to ChatGPT, use Codex once, then launch CodexNotch.

Swift, Swift Package Manager, and Xcode are not required.

> The current public build uses an ad-hoc signature. On first launch, macOS may say the developer cannot be verified. Choose **Open Anyway** in **System Settings → Privacy & Security**, or Control-click the app and choose **Open**.

CodexNotch reads the default `~/.codex` directory. If Codex uses another directory, set `CODEX_HOME` before launching the app.

## Make it yours

Hover over the physical notch and use **Settings** at the lower-right of the expanded card. You can also open Settings from the notch context menu or app menu.

- Switch between the clockwise quota ring and wave ball
- Show 1–5 recent conversations in the expanded card
- Apply changes immediately and save them locally
- Respect Reduce Motion while preserving static status cues

Macs without a notch automatically use a menu-bar fallback.

<details>
<summary><strong>Visual and interaction details</strong></summary>

- Both compact indicators use matching 24pt alignment containers, keeping icons clear of the camera cutout.
- The quota ring starts at 12 o'clock and progresses clockwise. It is green at 20% or above, red below 20%, and gray when data is unavailable.
- The gradient or wave moves only while a task is running. It remains still while idle, completed, or when Reduce Motion is enabled.
- The card expands downward from the compact island. Its transparent canvas is reclaimed after collapse so it does not intercept clicks outside the notch.
- The quota number stays inside the indicator and is never repeated beside it.

</details>

## Data and privacy

- The authentication token is read only from `CODEX_HOME/auth.json` and remains in process memory. CodexNotch never writes it to a cache or log.
- Quota and reset-credit details come from ChatGPT's read-only usage and reset-credit endpoints.
- Task state is parsed only from rollout JSONL files in `CODEX_HOME/sessions`.
- CodexNotch never records Authorization headers, complete usage responses, or user-message bodies.

The usage endpoint is an internal ChatGPT endpoint and its fields may change. If it fails, CodexNotch keeps the last successful quota while task monitoring continues.

<details>
<summary><strong>Build from source</strong></summary>

Contributors need macOS 14 or later and Xcode 15 / Swift 5.9 or newer:

```sh
swift test
./scripts/build_app.sh
open dist/CodexNotch.app
```

Create a distributable archive:

```sh
./scripts/release.sh
```

The release script runs tests, builds the release app, validates its code signature, and produces a ZIP plus SHA-256 file. To skip signing entirely:

```sh
SIGN_IDENTITY=none ./scripts/build_app.sh
```

</details>

## Current boundaries

CodexNotch is currently a v1 preview. It does not terminate Codex tasks, estimate cost, sync to the cloud, send remote notifications, animate a pet, or support Mac App Store distribution. ChatGPT Classic is not a monitored target.

## License

CodexNotch is released under the [MIT License](LICENSE). If it helps you stay focused—and a little less anxious about quota—consider giving the project a Star.
