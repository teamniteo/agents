---
name: dangling
description: Check whether closing the current session risks losing or interrupting work. Use for /dangling or questions about dangling leftovers and session closure.
---

# Dangling

Determine whether closing the current session could lose or interrupt its work. Inspect relevant current state, such as unsaved changes, running processes tied to the session, and results or decisions that exist only in session context. Do not treat work already preserved on disk or GitHub as at risk merely because it is unfinished.

Work includes ideas, discovered bugs, and findings from explorations, not just code or running tasks. Review the conversation for discoveries that have neither been saved in a durable place nor resolved. Report what would otherwise be forgotten and where it needs to be recorded.

Recheck any PR mentioned in the report on GitHub using `gh`, following the configured authentication rules. Never rely on remembered draft, CI, review, or merge status.

Completely skip the following. Do not inspect, mention, or offer to clean them up:

- Temporary checkouts and PR body files.
- Retained Passlet grants.
- Local or remote branches.

Report only work that could be lost or interrupted by closing now, with the action needed to preserve it.

Lead with whether the session can safely close. If no work is at risk, say so briefly. If a necessary check cannot be completed, state that limitation rather than claiming the session is safe to close.

This is a status check, not permission to delete files, stop processes, commit, push, or merge.
