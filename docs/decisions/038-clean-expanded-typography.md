---
status: active
contract_ids: [NOTCH-READABILITY-007, SETTINGS-PREFERENCES-018, NOTCH-LAYOUT-038]
supersedes: [037-stable-type-motion]
superseded_by: null
owner: project-maintainer
created_at: 2026-09-13
---

# Lighter type and fewer nested surfaces in the expanded card

The expanded card gave quota labels, progress, task rows and utility controls
similar visual weight. Small rounded semibold text and multiple inset borders
made the surface feel crowded. The user approved trying a calmer hierarchy.
This L2 change replaces decision 037's typography freeze while retaining all of
its opening, closing, text-motion, canvas and camera-clearance behavior.

Use the native system typeface with regular weight for most expanded content.
Task titles use 13pt, with medium weight and white text only for the same primary
running task already selected by the header. Other task titles use 82% white.
Metadata uses 10.5pt regular at the existing 60% white, with tabular digits for
time. Section labels use 11.5pt regular. Quota labels use 12pt regular at 78%
white; values use 14pt medium and the existing quota color scale. Exact reset
timestamps and second-level countdowns stay visible in 10pt regular type.

Draw task rows directly on the black surface, without a permanent list box or
row separators. Keep 40pt row hit areas and every task's status and navigation.
Use spacing to separate quota and history. Reset controls and expanded credit
rows retain only a faint fill; an unavailable-credit control has no fill.
Footer controls keep their 24pt height, subtle neutral fill, labels and native
semantics. The display toggle keeps its green enabled icon and accessible state.
Keep the existing press feedback and non-key-panel interaction behavior.

Quota bars use a 3pt stroke centered in their existing 6pt slot. Their width
still represents the returned remaining percentage, and labels retain the
original warning colors. Window size calculation, compact artwork, language,
zero-through-five recent-history preference, empty/unavailable states and all
data formatting are unchanged. No font dependency or new setting is added.

Rejected: making every label smaller, using monospaced text throughout, hiding
reset information, changing compact fonts, or altering the accepted rebound.

Validation uses the existing geometry, quota/text, state, preference and motion
guards, plus the native motion fixture. Its optional dense scenario covers
long Chinese/English titles, running/completed rows, both quota windows and
three reset credits including a missing expiry; the empty scenario covers no
quota and no history. Chinese preview preferences use an isolated test suite.
Inspect recordings for readable content and retained opening/closing/reentry,
then run full verification and rebuild/restart the installed app. Physical
camera clearance, real hover/navigation and subjective legibility still need
real-hardware confirmation; screenshots alone do not prove those interactions.
