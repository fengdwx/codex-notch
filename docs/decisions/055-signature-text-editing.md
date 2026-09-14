---
status: active
contract_ids: [SETTINGS-TEXT-023, SETTINGS-WINDOW-022, SETTINGS-MOTION-021]
supersedes: []
owner: project-maintainer
created_at: 2026-09-14
---

# Give signature editing a stable native text field

On the installed v0.2.2 release under macOS 26.6.2, typing `ab`, three
individual spaces and then `c` reproduced the user's issue: accessibility
reported `ab   ` immediately, while the right-aligned visible `ab` did not
move until the final `c`. This happened below the character limit, in the
Settings editor itself. The preview was displaying elapsed time, so the
floating signature renderer was not involved in this visual symptom.

Extract the existing editor into FloatingCenterTextField for hosted testing.
Use an explicit localized label and a native rounded-border TextField with
its implicit Form label hidden, leading alignment and the available row
width. This gives text a stable starting position and leaves space for the
caret to advance on each typed space. Keep the SwiftUI/native editing path
and the existing binding and character limit. No custom NSTextView, synthetic
placeholder characters, replacement of spaces or display normalization is
needed.

This L2 change preserves saved raw text, composed characters, the twelve
Character cap, empty display fallback, keyboard editing, style routing,
preview and live signature semantics. Task count, app focus, motion, window
geometry, quota and release behavior are out of scope. Tests must exercise
the native editor inside the same grouped Form context and check caret
movement, visibility, stable bounds and accepted text, with live rebuilt
Settings confirmation as a separate gate.

Apple documents TextField's context-dependent default style and the native
rounded-border alternative in its [TextField documentation](https://developer.apple.com/documentation/swiftui/textfield).
The diagnosis above comes from this machine's observed behavior, not a claim
that Apple has acknowledged a matching operating-system defect.

## Verification

The hosted grouped-Form regression failed on the original automatic field
and passed after the editor change. Full verification passed 96 contracts
and 235 tests (two existing opt-in skips, zero failures), the production
build, bundle resources and signature checks.

Installed the verified local build into Applications, keeping a rollback
copy of the published bundle, and restarted it explicitly. In the actual
Settings window, individual space presses after `ab` immediately advanced
the visible caret; inserting and deleting `c` retained all three spaces.
The twelfth space was accepted and a thirteenth character was rejected.
Native paste and middle insertion preserved Chinese text and a composed
family emoji. Restored the prior text and style. Input-method candidate
composition and other operating-system/display combinations remain
unverified. Version metadata remains 0.2.2/build 20; this is a local fix,
not a new public release.
