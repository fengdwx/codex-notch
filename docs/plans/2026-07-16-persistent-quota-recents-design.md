# Persistent Quota and Recent Conversations Design

## Goal

Keep CodexNotch visible as a calm quota indicator at all times, make running and just-completed work visually distinct, and turn the expanded notch into a useful two-item recent-conversation launcher.

## Compact states

- Idle keeps the ChatGPT mark and the weekly quota ring visible without motion.
- Running keeps the ChatGPT pulse, animates the quota arc from full to the real remaining value once, and adds a small travelling highlight in the current quota color.
- Just completed shows a short success contraction around the ChatGPT mark and one soft pulse around the quota ring, then returns to idle after 2.5 seconds.
- The ring always represents the real weekly remaining percentage. Animation must not change the displayed number or invent consumption.
- Quota color is continuous: 0 is red, 50 is amber/yellow, and 100 is green. Every quota animation uses the color calculated for the current percentage.
- Reduce Motion disables repeating movement and keeps only immediate state changes.

## Expanded layout

The panel remains attached to the physical notch. The quota section comes first and displays `51% remaining this week`, the horizontal progress bar, the exact reset timestamp, and a countdown to seconds. The compact ring continues to omit the percent sign.

Below a subtle separator, a `Recent conversations` section displays at most two conversations. Active conversations come first, followed by completed conversations sorted by last activity. Entries are deduplicated by thread ID. Each row uses the latest real user message as its title, with project name and status/time as secondary text. Clicking a row opens that thread in ChatGPT.

Running rows use a small pulsing status dot. Completed rows use a static checkmark. Rows share one quiet grouped surface instead of separate floating cards.

## Data flow and privacy

`RolloutEventParser` reads `event_msg/user_message` records already present in local Codex rollout files. Titles are whitespace-normalized and truncated in memory; they are not uploaded or written to a new database. `ActiveSessionStore` retains up to 24 hours of completed rollout summaries while preserving the existing six-hour protection against stale active tasks.

## Surface treatment

Remove the expanded panel's heavy black drop shadow. A very low-opacity outline on the attached notch shape provides separation without making it look like a detached card. Existing hover debounce and top anchoring remain unchanged.

## Verification

- Parser and reducer tests cover user-message titles, recent-thread deduplication, persistent idle quota, running priority, and the 2.5-second completion state.
- Color-scale tests cover red at 0, the midpoint, and green at 100.
- All Swift tests, the release build, signature verification, and screenshots of compact and expanded states must pass before publishing.
