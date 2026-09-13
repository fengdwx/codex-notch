---
status: active
contract_ids: [SETTINGS-WINDOW-019, SETTINGS-PREFERENCES-018]
supersedes: []
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Bring the existing Settings window forward on every request

The user reported that reopening Settings did not reliably bring an already
open window above another application. All three entry points used
`SettingsLink`, while explicit app activation ran from the settings view's
`onAppear` or `NSWindow.didBecomeKeyNotification`. An existing scene does not
necessarily produce either callback on another click.

Use one `NotchSettingsButton` for the expanded card, context menu and app
command. Every action explicitly activates the app and raises the existing
Settings window, restoring it if minimized. Invoke SwiftUI's `openSettings`
only when no Settings window exists, with the existing deferred presentation
and initial-appearance handling for window creation. Keep Command-comma and
the normal window level. Do not make Settings permanently floating or change
notch geometry, animations, data or update behavior.

Regression checks hide and reveal the same window repeatedly, ensure no
duplicate scene is requested and no level changes, and check that an unrelated
window cannot suppress creation of Settings. Required installed-app acceptance
is reopening while another app covers Settings and closing/reopening the scene.

Runtime inspection also found an existing Settings window with normal opacity
but absent from the active desktop while the notch remained visible. Configure
`moveToActiveSpace` and `fullScreenAuxiliary` before activating the app; clear
their mutually exclusive flags first. Keep the normal window level and avoid
showing Settings persistently on every desktop. These behaviors follow
[Apple's Space activation semantics](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/movetoactivespace)
and [full-screen auxiliary windows](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary).

Keeping only `SettingsLink` and appearance callbacks was rejected because a
retained scene can skip the presentation callback. A permanently floating
Settings window was rejected because it would cover other applications after
the user leaves Settings.

Verification on macOS 26.6.2: the full check passed with 87 contracts and 212
tests (two existing opt-in tests skipped), and the installed binary matched the
verified build. Accessibility interaction opened the scene with preferences
preserved; Window Server inspection later confirmed it was on screen at normal
level. Background automation did not reliably transfer foreground activation
or raise the other application's window, so it did not establish the covered
window or cross-Space acceptance cases. These still require a physical mouse
check; neither the unit tests nor the off-screen window capture proves focus.
