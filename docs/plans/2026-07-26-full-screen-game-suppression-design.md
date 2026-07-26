# Full-Screen Game Suppression

## Goal

Keep all CodexNotch surfaces off the notch display while another application
uses the complete display, including borderless games that do not enter a
native macOS full-screen Space.

## Design

Use a process- and geometry-based detector rather than application names. The
detector reads the frontmost process identifier and Core Graphics metadata for
on-screen windows. A layer-zero window counts as immersive full screen only
when it covers at least 98 percent of the notch display and reaches all four
display edges within 2pt. No pixels, titles, or user content are read or logged.

Application activation and active-Space notifications trigger immediate
checks. A one-second poll catches borderless mode changes made while the same
application remains frontmost. When suppression begins, the window controller
orders out the complete panel and disables its mouse hit region while retaining
the requested notch mode. Leaving full screen renders that requested mode
again.

## Stable Boundaries

- Ordinary application and Space switches retain the notch.
- A user-hidden notch retains its hover recovery sensor during ordinary use.
- Native and borderless full screen suppress both visible content and the
  transparent hover sensor.
- Menu-bar fallback, quota semantics, task state, panel level, and geometry do
  not change.

## Verification

- Unit-test full-screen coverage, normal maximized windows, background owners,
  overlay layers, and application-switch restoration suppression.
- Run `swift test` and `./scripts/verify.sh`.
- Reproduce with a local borderless full-screen window, then confirm the
  reported game and native full-screen behavior on physical-notch hardware.
