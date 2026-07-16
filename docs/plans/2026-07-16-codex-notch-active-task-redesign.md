# CodexNotch active-task redesign

## Goal

CodexNotch behaves like a quiet macOS Live Activity rather than a persistent
quota widget. It is visible only while at least one Codex task is running. The
compact state sits around the physical notch, and the expanded state grows from
the same top edge without becoming a detached black card.

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

- Use a 420 x 190 top-attached panel with no reserved empty list area.
- Show a compact running header, at most two task cards, and one weekly quota
  card.
- The weekly card contains the remaining percentage, the local reset timestamp
  in `yyyy-MM-dd HH:mm:ss`, and a countdown updated to the second.
- Remove the large “Open ChatGPT” title action. Each task card remains the
  direct navigation target.
- Animate only the window growth/collapse and the running pulse. Keep motion
  short and restrained to avoid reintroducing hover flicker.

## State and verification

When the active-session list becomes empty, the reducer always returns hidden,
even if ChatGPT is frontmost or a task just completed. Hover state is reset at
the same boundary so a later task starts compact. Unit tests cover visibility,
weekly-window selection, the 20% battery threshold, exact reset formatting,
countdown formatting, and notch geometry. Final verification includes the full
Swift test suite, a release build, compact and expanded screenshots, and a real
hover transition trace.
