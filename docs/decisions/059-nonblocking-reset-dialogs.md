---
status: active
contract_ids: [QUOTA-RESET-059, PRIVACY-BOUNDARY-006, SETTINGS-MOTION-021, NOTCH-HEIGHT-001]
supersedes: [058-manual-reset-credits]
owner: project-maintainer
created_at: 2026-10-13
---

# Present reset confirmation without blocking notch interaction

The user reported two dark-on-gray **Using** buttons and an expanded card that
would not collapse. A process sample of the failing installed app placed the
main thread in `useResetCredit` at its then-line 382, calling `NSAlert.runModal`.
Canceling the real dialog through computer use immediately restored the compact
card. Confirmation was not accepted and zero consumption POSTs were submitted.
This establishes the failure and cancellation behavior of the previous build;
it does not establish acceptance of the replacement build.

This L2 interaction repair preserves decision 058's entire redemption and
privacy boundary: an explicit per-credit confirmation, server-issued IDs,
expiry and authoritative availability checks, account consistency, one active
flow, stable retry keys after ambiguous errors, no automatic retry or purchase,
actual server outcomes and a fresh usage/credit read. It changes no mutation
request or permission. Compact geometry, camera clearance, motion, fixed-canvas
downward transitions, mouse recovery, quota values and task behavior stay
inherited through `QUOTA-RESET-059`.

Use an `NSAlert` window with ordinary native buttons and a completion callback,
without `runModal` or another application-modal loop. Hold one presenter window
at a time. Place it at `NSWindow.Level.popUpMenu + 1`, above the notch's level,
with `moveToActiveSpace` and `fullScreenAuxiliary` collection behavior. Retain
the window while visible and finish its callback once when an action, close
or dismissal occurs. Escape cancels; Return does not activate consumption.

Reset the hover state and request card collapse before presenting confirmation.
The native window must leave main-queue work, hover timers and clock updates
running. Mark the flow busy before showing the dialog, but distinguish the
pending phase with **Confirm… / 待确认…**. Change to **Using… / 使用中…** only after
explicit confirmation. Cancellation restores both flags and refreshes usage;
it never enters the redemption path. Result feedback uses the same nonmodal
presentation so it cannot recreate the collapse failure.

Give the reset action's label an explicit light foreground on the dark card.
System light appearance must not supply black text. Pending, submitting and
unavailable buttons retain readable text and their existing disabled guards,
dimensions, expiry labels and countdowns.

Rejected alternatives: merely raising an application-modal alert would leave
the event-loop coupling in place; replacing confirmation with direct submission
would change authorization; changing notch geometry or hover delay would hide
the symptom without addressing the sampled path; relying on global system dark
appearance would leave the button unreadable in other supported appearances.

`ResetCreditDialogPresenterTests` verifies native visibility, level, callback
completion, cancellation/close behavior, Return safety and continued main-queue
timer service. `ResetCreditActionViewTests` verifies pending labels and disabled
actions, and renders English/Chinese action rows in light/dark appearances for
available, pending, submitting and expired states to check text contrast. The
focused automated suites passed during this repair; these fixtures do not
constitute real-notch acceptance of the newly built app.

Run contract checks and full verification, rebuild/restart the installed app,
then verify visible confirmation, card collapse, continuing clocks, app/Space
switching, label contrast, cancellation, window close and result dismissal on
the actual notch. On 2026-10-13, the user confirmed readable light-text
**使用重置** buttons in the replacement build's expanded card. A subsequent
computer-use readback showed the compact card. The user then opened confirmation;
computer-use accessibility and screenshot readback verified the visible native
**使用这次额度重置？** dialog and two readable buttons. Clicking only
**取消** removed the dialog and restored the compact notch, confirmed by the
accessibility tree and screenshot. This provides real-device evidence for button readability, expansion, visible
confirmation and cancellation back to the compact state. The user subsequently
reported successful real-device checks of both Space switching and fullscreen
behavior, with no issues; these two scenarios are user-accepted. Clocks,
window close, result dismissal, animation and mouse recovery remain separately
unverified on the actual notch. This acceptance does not establish real credit
redemption. Do not
consume a real credit to validate this UI repair. Keep actual server redemption
unverified until the user deliberately performs it and the result is read back.

## Follow-up review

The full review reproduced an inconsistent credit response in an isolated
fixture: `available_count: 0` with a stale `status: available` row was empty
on display but still eligible in redemption preflight. Parse authoritative
zero as an empty available list at the shared DTO boundary. Preserve missing
count compatibility and all ID, expiry, account and idempotency checks. The
fixture submitted one mock request before the fix and zero afterward; this
does not establish that the live service has emitted such a response.

A result window could remain open while a new action looked enabled and did
nothing. Reuse and bring forward that existing window when another action is
invoked, without constructing a new confirmation or sending another request.
The existing confirmation and result lifecycle remains nonmodal.

Inject the existing view model and dialog presenter through defaulted runtime
initializer arguments to test the real coordinator path with fixture-only
authentication, isolated preferences and a URLProtocol that intercepts every
request. This adds no production mode or alternate reset implementation.
The runtime guards complement the earlier component tests; they do not
replace physical-notch acceptance or establish real server redemption.

Rollback the presenter and label changes to the preceding verified build if
needed, or remove the reset action to restore read-only details. Restoring a
build cannot recover a credit already consumed on the server.

## Button placement and user redemption acceptance — 2026-10-14

The user reported that a real reset succeeded, and requested Cancel on the
left and Use reset on the right. This records user-reported redemption
acceptance; the agent does not consume another credit to verify this change.

This L2 change is limited to the confirmation button order and its role
binding. Preserve QUOTA-RESET-059's explicit confirmation, Return safety,
Escape/close cancellation, single callback and nonmodal lifecycle. API changes,
credit consumption, notch geometry, the proposed style redesign and releases
are out of scope. Apple documents that NSAlert places its first button on the
right in left-to-right languages, so add Use reset first and Cancel second:
[NSAlert buttons](https://developer.apple.com/documentation/appkit/nsalert/buttons).
Bind confirmation to the actual button reference rather than its list index,
so swapping visual order cannot turn Cancel or Escape into confirmation.

The user's screenshot is the reproduction for the installed application.
Extend the existing Chinese/English hosted tests with actual window-coordinate
ordering checks while preserving click, Return, Escape and close checks. The
baseline hosted suite did not reproduce the installed screenshot's ordering,
so a passing hosted check alone is insufficient: rebuild, restart the exact
running bundle, open its real confirmation, inspect the two positions and
cancel without submitting. Run the full verification entry point as well.

Verification: full `scripts/verify.sh` passed with 292 tests (2 skipped, zero
failures), release build, resource and signature checks. Swift 6.4's new default
SwiftBuild backend nested copied resources differently and caused unrelated
image-resource checks to fail; the complete entry point was rerun with the
project's existing native backend, without skipping or changing any checks.
After restarting that exact rebuilt bundle, the user opened its confirmation.
Computer-use screenshot and accessibility readback showed Cancel on the left
and Use reset on the right. Clicking Cancel closed the dialog and returned to
the compact notch. No reset was submitted during this verification.
