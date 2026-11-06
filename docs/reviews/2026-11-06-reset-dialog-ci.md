# Reset dialog verification on older AppKit

The macOS 15 / Xcode 16.2 diagnostic run reproduced the previous macOS 14
assertion exactly: Cancel's frame ends at x=132 while Use reset's starts at
x=128. Both English and Chinese use frames (10,10,122,40) and (128,10,122,40).
Their alignment insets are 6pt on all sides. The actual alignment rectangles
are (16,16,110,28) and (134,16,110,28), with an 8pt gap and matching vertical
centers. Local macOS 27.2 returns those same alignment rectangles with zero
frame insets. No real reset was submitted.

Evidence: https://github.com/fengdwx/codex-notch/actions/runs/42154120867

Apple documents that Auto Layout uses alignment rectangles rather than frames,
so ornamentation such as shadows does not affect alignment:
https://developer.apple.com/documentation/appkit/nsview/frame(foralignmentrect:)

The test now checks alignment rectangles, retaining strict left/right ordering
and adding an explicit 8pt gap and same-row assertion. Production behavior is
unchanged. This corrects the measurement, not the expected layout.

The original macOS 14 hosted image is now retired. New attempts are cancelled
before any test starts with 'macos-14-arm64-us-default is not supported'.
https://github.com/actions/runner-images/issues/13518

The isolated diagnostic branch uses macOS 15 with the same Xcode 16.2, then
runs the full verify script after the assertion correction. macOS 14 has not
been reverified; production CI and package workflows still need a supported
runner migration before publication. No release or feed is published here.
