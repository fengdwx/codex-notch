# CodexNotch active-task redesign

## Goal

CodexNotch behaves like a quiet macOS Live Activity rather than a persistent
quota widget. Its visible compact state appears only while at least one Codex
task is running. While idle, a transparent sensor remains over the physical
notch so hovering it can reveal quota details. Expanded content grows from the
same top edge without becoming a detached black card.

## Compact state

- Keep the 38-point wings on each side of the physical notch.
- Render the ChatGPT mark from its 2x template asset at an exact 18-point size.
- Add a low-frequency breathing halo while a task is active; respect Reduce
  Motion.
- Keep the circular quota gauge and borrow only the familiar battery color
  rule. The weekly quota alone controls its color: weekly remaining quota at or
  above 20% is green and below 20% is red. A missing weekly window is neutral
  gray; other windows never act as a fallback.

## Expanded state

- Use a 420 x 158 active panel and a 420 x 104 idle quota panel with no reserved
  empty list area.
- Show a compact running header, at most two task cards, and one weekly quota
  card.
- The weekly card contains the remaining percentage, the local reset timestamp
  in `yyyy-MM-dd HH:mm:ss`, and a countdown updated to the second.
- Remove the running-title row below the notch. Keep only the ChatGPT mark and
  weekly ring at the physical notch height; each task card remains the direct
  navigation target.
- Animate only the window growth/collapse and the running pulse. Keep motion
  short and restrained to avoid reintroducing hover flicker.

## State and verification

When the active-session list becomes empty, the reducer returns hidden unless
the pointer is over the transparent physical-notch sensor, in which case it
returns the idle weekly-quota panel. Hover state is reset when a running task
finishes so a later task starts compact. Unit tests cover visibility,
weekly-window selection, the 20% battery threshold, exact reset formatting,
countdown formatting, and notch geometry. Final verification includes the full
Swift test suite, a release build, compact and expanded screenshots, and a real
hover transition trace.
