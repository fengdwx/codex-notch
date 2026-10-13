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
accessibility tree and screenshot. This
provides real-device evidence for button readability, expansion, visible
confirmation and cancellation back to the compact state. Clocks, app/Space
switching, window close, result dismissal, animation and mouse recovery remain
unverified on the actual notch. No real credit was consumed. Do not
consume a real credit to validate this UI repair. Keep actual server redemption
unverified until the user deliberately performs it and the result is read back.

Rollback the presenter and label changes to the preceding verified build if
needed, or remove the reset action to restore read-only details. Restoring a
build cannot recover a credit already consumed on the server.
