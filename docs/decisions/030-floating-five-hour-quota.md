---
status: active
contract_ids: [NOTCH-VISIBILITY-048, QUOTA-SEMANTICS-054]
supersedes: [022-restore-left-status-without-five-hour-quota]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-07
last_verified_commit: null
---

# Show five-hour quota in both compact layouts

The released app receives both windows on the user's Mac but only selects the
five-hour left indicator on physical-notch displays. Extend the same priority
to the floating bar; without that window retain the selected status icon.
Keep the existing 30pt left lane, center battle, right weekly lane, and all
status artwork and motion settings. Pass the actual layout to the indicator
so floating bars do not acquire the physical-notch halo or its wider lane.

Keeping a status-only floating lane was rejected because it hides available
quota. Adding another lane was rejected because it changes accepted geometry.
The menu-bar-only route remains a status fallback. Tests cover quota presence
and absence in each route; hardware inspection is still required for notch
clearance and animation quality.
