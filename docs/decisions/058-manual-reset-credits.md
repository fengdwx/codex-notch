---
status: superseded
contract_ids: [QUOTA-RESET-058, PRIVACY-BOUNDARY-006, SETTINGS-MOTION-021, NOTCH-HEIGHT-001, QUOTA-ALIGNMENT-056]
supersedes: []
superseded_by: 059-nonblocking-reset-dialogs
owner: project-maintainer
created_at: 2026-10-13
---

# Confirm and use an existing reset credit from the notch

The user explicitly requested viewing and using their existing Codex reset
opportunities in CodexNotch because resetting in the main app is unavailable.
This is an L3 change: redeeming a credit changes remote account state and cannot
be undone by restoring the app. No purchase, automatic reset, authentication
write, task-state change, visual redesign or release is included.

`QUOTA-RESET-058` replaces only the reset-action prohibition in the historical
`QUOTA-SEMANTICS-008` and `QUOTA-SEMANTICS-004` contracts. Their existing
supersession chain still records subsequent quota-color and display decisions.
Current quota semantics, precision, expiration countdowns, language settings,
compact artwork, motion gates, fixed-canvas downward expansion, physical-camera
clearance and collapsed mouse recovery remain inherited and protected.

## Interaction and mutation boundary

Keep opening reset details read-only. Add a localized **Use reset** button to
each available credit row. Only a real nonempty server identifier can be used
for redemption; a fallback ID generated for displaying a malformed row must
never become a redemption ID. Disable expired credits and all credit buttons
while one confirmation or redemption flow is active anywhere in the app.

Use a native confirmation alert that explains a successful eligible reset
consumes the selected credit. Cancellation sends no mutation. Native result
and error alerts must remain visible independently of whether the hover card collapses. Reuse the
existing panel and native alert focus behavior without adding a new window
animation or changing the notch geometry.

Before sending the request, reread the local credentials and verify the
account context that supplied the displayed credits. Fetch the authoritative
available-credit list, verify that the selected server ID remains available
and unexpired, and recheck credentials after that read. Any failed read,
changed account, missing credit or expired credit stops before the mutation.
Allow at most one in-flight redemption across all surfaces.

Generate a UUID idempotency key for the logical account-and-credit attempt
and retain it only in process memory. After an ambiguous error, a fresh
user-confirmed retry of that same attempt reuses its key. There is no automatic
retry and no fallback to another credit. App restart does not provide durable
attempt recovery; the next attempt must still reread server availability.

Refresh usage and credits after the attempt and present the actual server
outcome or error. Never set a quota percentage locally because a mutation
request completed. An authoritative zero count or empty list replaces stale
credit details, including after the last credit is consumed. A failed read
must not be misreported as zero available credits or successful redemption.
Authentication headers, tokens and complete server responses must not enter
logs, repository files or an app cache.

## API evidence and response meaning

The [official Codex backend client](https://github.com/openai/codex/blob/main/codex-rs/backend-client/src/client/rate_limit_resets.rs),
checked on 2026-10-13, reads credits with `GET /wham/rate-limit-reset-credits`
and consumes one with `POST /wham/rate-limit-reset-credits/consume` under
ChatGPT's `https://chatgpt.com/backend-api` base. The JSON body carries
`redeem_request_id` and an optional `credit_id`; CodexNotch always specifies the
selected credit. The [official protocol schema](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/typescript/v2/ConsumeAccountRateLimitResetCreditParams.ts)
recommends a UUID for one logical attempt and reusing that value for its retry.
These source observations do not establish a stable public API commitment.

The [official response types](https://github.com/openai/codex/blob/main/codex-rs/backend-client/src/types.rs)
distinguish `reset`, `nothing_to_reset`, `no_credit` and `already_redeemed`.
Present these as separate outcomes; an unknown response is an error, not a
successful reset. OpenAI's [banked-reset explanation](https://help.openai.com/en/articles/20001498-how-banked-codex-resets-work)
states that a credit is consumed only when at least one eligible window is
reset. Therefore `nothing_to_reset` must explain that no reset was needed and
must not report a consumed credit. The returned usage read remains the source
of quota percentages and reset times.

## Alternatives rejected

- Redeem directly from the disclosure control: ordinary inspection would
  unexpectedly consume a limited account resource.
- Rely only on a cached displayed credit: the credit or account can change
  before the user confirms.
- Retry a failed mutation automatically or assign every retry a new key:
  an ambiguous response does not prove that the first request had no effect.
- Optimistically refill quota or retain a previous nonempty list after an
  authoritative empty result: either would present invented account state.
- Purchase more credits or reset when quota reaches a threshold: neither
  behavior is part of the user's request.

## Validation and rollback

Use stubbed transport and injected credentials to verify request construction,
outcome decoding, malformed IDs, expiry, availability, account changes,
concurrent calls, stable retry keys, and the final-credit empty response. Native
UI guards cover read-only disclosure, eligible button actions and disabled
states. Run `./scripts/check_contracts.sh`, focused tests and the full
`./scripts/verify.sh` checks. Review the credential and mutation paths as an L3
change. These checks must never redeem a real user's credit.

After rebuilding and restarting the app, inspect the disclosure, button,
confirmation cancellation, alert focus recovery, downward expansion, compact
state and collapsed mouse recovery on real-notch hardware. Automated tests
and screenshots do not establish successful real redemption or hardware
acceptance. An actual server redemption remains unverified until the user
deliberately accepts that credit-consuming action and the server result and
refreshed quota are read back.

Rollback by restoring the previously verified local app build or removing the
new action and rebuilding to restore read-only credit details. No data migration
is required. Rollback cannot recover a credit already consumed on the server.
