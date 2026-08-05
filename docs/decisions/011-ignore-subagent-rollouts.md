---
status: active
contract_ids: [ACTIVITY-STATE-005, CONVERSATION-TITLE-041]
supersedes: []
superseded_by: null
---

# Ignore Child-Agent Rollouts in the Notch Activity Feed

Codex stores child-agent work as separate rollout JSONL files. Those files are
implementation details of the user's top-level task, not independent
conversations for CodexNotch to show beside the notch.

## Decision

When `session_meta.payload` contains either the structured
`source.subagent.thread_spawn` marker or a non-empty `parent_thread_id`, the
parser emits a child-rollout marker. The activity reducer drops all activity
and completion events for that rollout. A normal string source such as
`"vscode"` remains a top-level rollout.

## Rejected alternatives

- Filter by `cwd`: parent and child agents commonly share the same project
  directory, so this cannot distinguish them.
- Filter by `originator`: child rollouts currently use the same `Codex Desktop`
  originator as top-level work.
- Display child rows but hide only their titles: the child task would still
  incorrectly keep the running state alive.
- Reduce the stale timeout to a short fixed interval: that would hide legitimate
  long-running top-level tasks when their rollout has no new line for a while.

## Consequences

- The expanded list and recent-conversation history contain only top-level
  Codex conversations.
- An abandoned child rollout cannot keep the compact notch in the running
  state; top-level abnormal-exit recovery continues to use its existing stale
  fallback.
- The parser reads only metadata needed for classification and still ignores
  rollout message bodies.
