# Quota Indicator and Settings Design

## Goal

Free the notch quota display from a single ring direction. Users can switch between two styles immediately in the native macOS Settings window and observe the result on the actual notch.

## Visual Options

1. **Clockwise ring (default)**: The end of the filled arc stays at 12 o'clock, and the gap grows clockwise from there as quota falls. It is closest to a familiar progress ring and preserves the existing compact layout.
2. **Wave ball**: The liquid level inside a circular container represents remaining quota; the wave flows slowly while running and keeps one subtle pulse on completion. At small sizes it reads more like a status badge than a ring.

Both styles keep the number inside the indicator. The ring uses a direct centered readout; the wave ball adds only a very thin dark outline and shadow around the glyph so the number is not swallowed by the moving wave without hiding the liquid level. Both styles reuse the same quota colors: 100% is green, 50% is the midpoint color, and 0% is red; running animation still uses the color for the current quota.

## Settings and Data Flow

`QuotaDisplayStyle` is persisted in `UserDefaults`. `NotchView` and the Settings window read the same `@AppStorage` key, so a change updates the notch without a restart. The Settings window is provided by a SwiftUI `Settings` scene, and both the notch context menu and app menu provide an entry point; the number remains inside the indicator and has no separate position setting.

The expanded panel shell connects to the physical notch at the top of the screen. The screen's `safeAreaInsets.top` is used only as top content padding, so the horizontal quota bar and text avoid the camera while the card does not float below the notch.

## Verification

- Add unit tests for the style enum and progress direction.
- Run the full Swift test suite and rebuild the signed release package.
- Restart the app and capture each style to confirm that neither blocks text or causes hover flicker in the compact notch; the left ChatGPT pulse should be clear but not distracting while running.
