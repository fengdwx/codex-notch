# CodexNotch

English · [简体中文](README.zh-CN.md)

CodexNotch is a standalone native macOS app. While a Codex task is running, it lives around the MacBook notch and shows activity plus weekly quota. When idle, it keeps a compact quota indicator; hovering the physical notch opens the details. It has no dependency on Atoll, CodexIsland, CC Switch, or another host app.

## Features

- Keeps the running Codex state visible beside the notch even when another app is frontmost; a compact weekly-quota indicator remains when idle.
- Hover the physical notch to reveal a card that expands only downward, with weekly quota, reset time, countdown, and recent conversations.
- Both compact indicators use matching 24pt alignment containers. The left ChatGPT mark is optically corrected to 22pt; a running task uses a restrained static blue echo, while a completed task has one green echo and a checkmark. The right side can show a clockwise ring or a wave ball.
- The app bundle carries an original deep-green terminal icon: a small top notch slot, terminal title bar, and high-contrast green `>_` prompt. It is recognizable in Finder, Launchpad, and the installer, and never uses account or conversation data.
- The **Settings** control at the lower-right corner of the expanded card, the notch context menu, and the app menu can all change the quota indicator style and recent-conversation limit. Settings come to the front automatically. The physical notch is the live preview, so Settings does not duplicate it with a static preview card. The number always stays inside the indicator. The wave ball outlines only the glyphs and never masks the liquid; the liquid moves only while a task runs. Changes apply immediately and are saved locally.
- A weekly quota at or above 20% is green; below 20% it is red. While a task runs, a soft gradient flows along the remaining-quota arc. The ring is still when idle, completed, or when Reduce Motion is enabled. Missing weekly quota is gray.
- The expanded card shows active tasks, a horizontal weekly-quota bar, exact current reset time, and a second-by-second countdown. Its readable quota, reset, and conversation text scales up appropriately. The entire **N reset credits available** row is clickable; it expands downward to list the precise expiry time and countdown for each available reset credit without repeating its name. The ring is only used in the compact state. Clicking a task opens `codex://threads/<thread-id>`.
- Quota windows are identified from the returned `limit_window_seconds`; no five-hour assumption is hard-coded.
- Macs without a notch use a menu-bar fallback and never read or reveal user-message bodies.

## Installation for regular users

Download `CodexNotch-...zip` from Releases, unzip it, and drag `CodexNotch.app` into Applications. Swift, Swift Package Manager, and Xcode are not required.

The local release is ad-hoc signed by default, so macOS may warn that the developer cannot be verified. Choose **Open Anyway** in **System Settings → Privacy & Security**, or Control-click the app and choose **Open**. Public distribution should use a Developer ID signature and notarization.

Before running the app, sign in to ChatGPT and use Codex. The app reads the default `~/.codex` directory. If Codex uses a different directory, set `CODEX_HOME`.

## Build from source

Contributors need macOS 14 or later and Xcode 15 / Swift 5.9 or newer:

~~~sh
swift test
./scripts/build_app.sh
open dist/CodexNotch.app
~~~

Create a distributable archive:

~~~sh
./scripts/release.sh
~~~

The script runs tests, builds the release `.app`, validates its code signature, and produces a zip plus SHA-256 file. The default signature is an ad-hoc local signature. To skip signing entirely:

~~~sh
SIGN_IDENTITY=none ./scripts/build_app.sh
~~~

## Data and privacy

- The authentication token is read only from `CODEX_HOME/auth.json` and remains in process memory; CodexNotch never writes it to a cache or log.
- Quota and available reset-credit details are read separately from ChatGPT's usage and reset-credit endpoints.
- Task state is parsed only from local rollout JSONL files in `CODEX_HOME/sessions`.
- The app never records Authorization headers, complete usage responses, or user-message bodies.

The usage endpoint is an internal ChatGPT endpoint and its fields may change. If it fails, the last successful quota is retained while task monitoring continues.

## Current boundaries

This is a v1 preview. It does not terminate Codex tasks, estimate cost, sync to the cloud, send remote notifications, animate a pet, or support Mac App Store distribution. ChatGPT Classic is not a monitored target.

## License

CodexNotch is released under the MIT License. See [LICENSE](LICENSE).
