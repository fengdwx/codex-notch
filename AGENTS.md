# CodexNotch Project Handoff Notes

## What This Is

CodexNotch is an independent, open-source native macOS SwiftUI/AppKit app. It does not depend on Atoll. It displays the current ChatGPT/Codex weekly quota, running tasks, and recently completed conversations beside the physical MacBook notch, with clickable navigation back to the corresponding ChatGPT task.

## Behavior-Change Harness (Required Entry Point)

Before editing any user-visible interaction, quota semantics, session state, privacy data, window geometry, settings, packaging, or release behavior, read:

1. [Project harness](docs/agent-harness.md)
2. [Active behavior contracts](docs/contracts/behavior-contracts.yaml)
3. The relevant [architecture decisions](docs/decisions/)

Before writing code, state what will change, what must remain stable, what is out of scope, and the risk level. Prefer adding or locating an outcome-oriented guard. If a UI behavior cannot be verified automatically, the completion report must say that real hardware confirmation is required; it must not be assumed to pass. `swift test` is the fast check, `./scripts/verify.sh` is the full check, and `./scripts/release.sh` is reserved for release packages. Do not delete existing regression tests to accommodate a new implementation; resolve contract conflicts explicitly with a superseding contract. See the harness for details.

## Current Location and Git

- Working repository: `/Users/david/projects/codex-notch`
- Personal remote: `https://github.com/fengdwx/codex-notch.git`, with `main` as the default branch
- Current development branch: `feat/codex-notch-v1`; at the user's request, it was previously synchronized directly to remote `main` with `git push origin HEAD:main`. Check the worktree before pushing, and push only when requested.
- `/Users/david/projects/tmp/codex-notch` is another `main` worktree; do not delete or confuse the two worktrees.
- The user prefers one commit per meaningful change. Push to the personal repository, never to an organization repository.

## Common Commands

```bash
swift test
./scripts/verify.sh
./scripts/build_app.sh
open dist/CodexNotch.app
```

- `./scripts/build_app.sh` runs the tests and builds `dist/CodexNotch.app`.
- Latest complete verification: 63 tests passed.
- After changing the UI, rebuild and restart the `.app`, then have the user confirm it on a real notch. Do not claim that an animation is correct based only on screenshots.

## Runtime and State Model

- The current ChatGPT/Codex app has bundle identifier `com.openai.codex`; `com.openai.chatgpt.classic` is Classic and must not be treated as the current target.
- Quota comes from the local Codex/ChatGPT login state. Never commit authentication files, access tokens, or any private `~/.codex` content.
- Session activity comes from local rollout/session logs. `ActiveSessionStore` retains recent completion records for 24 hours.
- An active task always shows the running state. With no active task but a recent completion, the compact notch remains in the completed state with a green check; a new task immediately switches back to the running animation.

## Confirmed Visual and Interaction Constraints

- Quota always appears in the right notch safe area, with the number inside the ring or wave ball and no duplicate number beside it.
- The quota ring has a gap at 12 o'clock and expresses progress clockwise; its color transitions smoothly from high-quota green to low-quota red.
- The left and right icons must remain centered in their respective safe areas, never drop below the notch, and never be covered by the physical camera cutout.
- Hover expansion must grow downward from the existing compact island. It must not burst out of the physical notch, expand upward, or cause window jumping.
- Expansion intentionally follows Atoll's layered approach: `NotchWindowController` prepares the final transparent canvas once, and SwiftUI expands the visible island inside that canvas. Do not restore the old frame-per-frame `NSPanel` resizing approach; it was not smooth and once caused crashes during SwiftUI text layout.
- Reclaim the transparent canvas after collapse so it does not intercept mouse events outside the compact notch.
- The running state uses a blue ChatGPT visual echo on the left; the completed state uses one green echo and a clear green checkmark. Preserve static state cues when motion is reduced.
- The expanded card shows weekly quota, the exact reset time, and recent conversations. Settings control the number of recent conversations (1–5), and the Settings window must be able to come to the front automatically.

## User Collaboration Preferences

- Use concise Chinese, lead with the result, and then explain the approach; the user may provide screenshots for pixel-level feedback.
- Do not expand this into an Atoll plugin or add an Atoll dependency; this is the user's independent app.
- The user values real-machine appearance, smoothness, and notch geometry over changes based only on guessed parameters.
- When a UI regression appears, inspect the actual runtime state and corresponding state machine before changing styles.
