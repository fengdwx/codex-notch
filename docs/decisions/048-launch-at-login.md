---
status: active
contract_ids: [APP-LOGIN-001, SETTINGS-PREFERENCES-018, SETTINGS-WINDOW-019]
supersedes: []
owner: project-maintainer
created_at: 2026-09-13
---

# Optional launch at login using the system registration

Issue #3 requests automatic startup, which the maintainer approved separately
from the menu-bar layout discussion. Add a bilingual Launch at login toggle
to Settings. Use Apple's `SMAppService.mainApp` (available before the app's
macOS 14 minimum) to register and unregister the main app as a login item.
Opening the app or Settings must never register it. No helper, launch-agent
plist, third-party dependency or duplicate UserDefaults flag is needed.

System status is the source of truth, including an existing user registration.
Read it when Settings appears, when the app becomes active again, and after
every attempted change. A pending approval remains switchable off and has an
explicit not-yet-active message with a user-initiated System Settings button.
Failures show their error and the actual system state rather than an optimistic
saved preference. Other settings, window activation, task and quota behavior,
notch geometry, signing and update behavior remain unchanged.

Tests use an injected service to verify opt-in, removal, external changes,
approval and failures without changing the developer's login items. Full
verification builds and signs the app. Manual acceptance still needs a bundled
app: toggle on/off and check System Settings, return after an external change,
then log out/in with the option enabled to verify actual automatic launch.
The application must not log the user out or reboot as part of automated checks.

On macOS 26.6.2, the signed local bundle initially reported `notFound` before
its first registration. An actual Settings toggle successfully registered it
and read back `enabled`; toggling off removed it and restored the off state.
Therefore `notFound` alone is not an installation warning: show that guidance
only alongside an actual failed operation. This check restored the original
off preference. Actual launch after logout/login and the reporter's macOS
15.7.1 remain unverified.

References:

- https://github.com/fengdwx/codex-notch/issues/3
- https://developer.apple.com/documentation/servicemanagement/smappservice
- https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum
