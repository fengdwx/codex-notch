# Notch Display Control Redesign

## Goal

Make the notch display state immediately understandable while keeping the
control beside Settings in the expanded card footer.

## Chosen Design

Use a compact status toggle immediately to the left of Settings:

- The label states the result directly: `Notch On` / `Notch Off`, localized as
  `刘海开启` / `刘海关闭`.
- Enabled state uses the same dark surface language as Settings, with a subtle
  green tint and border plus a bright-green `eye.fill` icon.
- Disabled state uses a neutral gray capsule and an `eye.slash.fill` icon.
- The status toggle and Settings use the same 24pt height and stay on one line.
- The entire status capsule is clickable, not only its icon or text.

## Layout Impact

The expanded card keeps its existing width and height. Its top attachment,
compact header, downward-only expansion, hidden-state hover sensor, and
in-card recovery behavior remain unchanged.

## Verification

- Keep the existing geometry expectations because the controls share one row.
- Run `swift test`, `./scripts/check_contracts.sh`, and `./scripts/verify.sh`.
- Restart the app and inspect the enabled and hidden states on a physical notch.
