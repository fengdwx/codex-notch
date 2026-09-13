---
status: active
contract_ids: [SETTINGS-WINDOW-022, SETTINGS-MOTION-021]
supersedes: []
owner: project-maintainer
created_at: 2026-09-13
---

# Leave native Settings popup focus alone

The user reported that Number of recent tasks would not open. On macOS
26.6.2 the native accessibility action could open all six choices and select
three, but clicking the arrow on an inactive window did not leave a visible
menu. Earlier language-menu checks also intermittently lost the menu before
selection. This is an intermittent focus symptom, not missing picker values.

AppDelegate still observed every Settings didBecomeKey notification and
scheduled another app activation, makeKeyAndOrderFront and orderFrontRegardless.
That observer predates the explicit Settings request introduced in decision
046. Remove it now that the card, context menu and command all explicitly
request presentation. Keep initial appearance as a creation fallback and
leave an already visible/key Settings window on the current Space in the active app alone when
the deferred request runs. Do not replace native pickers or their bindings.

This L2 change preserves explicit reopens, reuse, normal level, current Space
behavior, defaults, saved preferences, animation independence and all notch
behavior. Picker redesign, unrelated settings, releases and data changes are
out of scope. Existing presentation tests guard hidden-window recovery and
creation/reuse. Native menu tracking and first-click focus require a live UI
check; selection state alone or a synthetic key notification is not proof of
an open usable popup. Use full verification and inspect both pickers after
restarting the verified app, then restore the initial count and language.

## Verification

Full verification passed 93 contracts and 231 tests (two existing opt-in skips,
zero failures), production build, bundle resources and signing checks. Existing
Settings reuse/creation tests remain intact and passed.

Restarted the rebuilt app and selected recent-task count 5, then restored 2.
Selected Chinese and then restored English through the native language popup.
All four menu opens and selections completed without losing the popup. Closed
Settings, reopened with Command-comma, and opened the recent-task menu again;
all six choices remained available and 2 was selected. Left that menu open
for the user. Launch at login remained enabled. These are native accessibility
interactions; first physical-mouse clicks from another app and cross-Space
reopening still require user confirmation, not inferred success.
