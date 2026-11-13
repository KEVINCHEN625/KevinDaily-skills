# HANDOFF — the only file a resuming coordinator must read first

<!-- Rewrite this file in place (never append) at every state change, before a long wait, and when the context is
     close to compaction. Keep it under 6 KB. It holds the PRESENT; history goes to DECISIONS.md. Point to files, do
     not copy them. The lines that start with an UPPERCASE key are read by scripts/goal-check.sh — keep the keys. -->

MAIN-GOAL: <goal-id> — <one line: what the user gets when it is done>
PREDICATE: <the checkable end state, e.g. "fresh account, all 7 onboarding steps pass on the real page, release build">
PROGRESS: <reached>/<target> — <what the number counts>; last advance <UTC>; known open blockers: <n>
ENV: <instance tree @sha · ports · replay instance · shared browser port · test account file path (never its content)>
NEXT: <the very next action for the main goal>
NEXT: <then>
NEXT: <then>

## WIP (track | id | what | state | where) — state: running, review, queued, parked, done
WIP: main | <lane or agent id> | <what> | running | <out dir or agent name; waiter armed yes/no>
WIP: side | <id> | <what> | parked | <why parked / resume condition>

## User directives in force (quote the user's words; newest first; delete a line when it is superseded)
- <date> D-<n>: "<the user's words>"

## Open blockers on the main path (all known, not only the current one)
- <signature> — <state: fix lane / acked D-n / unknown cause> — <evidence path>

## Waiting on the user
- <nothing | the exact decision or command>

## Pointers
- Routing now: ALLOCATION.md · Run ledger: RUNS.tsv · Last unstuck record: <path or none> · Last decisions: D-<n>…D-<m>
- Skills the next session should load: coordinator-review-drive<, …>
