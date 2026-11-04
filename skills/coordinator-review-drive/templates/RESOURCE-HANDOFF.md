# RESOURCE-HANDOFF (end of every executor reply — mandatory)

List EVERY resource this task created, even ones already removed. Exact identifiers only; no wildcards.

| Kind | Exact path / PID / port / URL / branch | Created by | State | Command to remove (if not removed) |
|------|----------------------------------------|-----------|-------|------------------------------------|
| temp dir / basetemp | /abs/path | this task | removed | — |
| test DB / DB copy | /abs/path.db | this task | removed | — |
| PG cluster | data dir /abs/path, port 55432, pid 1234 | this task | removed (pg_ctl stop + rm data dir) | — |
| process | pid 5678 (pgid 5678), port 8099 | this task | kept-running-on-purpose: <why, until when> | `kill -TERM -5678` |
| browser page/profile | tab/page id or profile dir | this task | removed | — |
| test project/account in instance | instance :8077, project id 42 | this task | kept-as-evidence: <report ref> | — |
| worktree / branch | /abs/worktree, branch x | this task | needs-coordinator (sandbox cannot write git metadata) | `git worktree remove /abs/worktree` |
| evidence kept | <out>/evidence/… (size) | this task | kept-as-evidence | — |

States: `removed` · `kept-as-evidence` (moved under `<out>/evidence/`, small) · `kept-running-on-purpose` (why, until
when) · `needs-coordinator` (exact command) · `could-not-remove` (why).

"Nothing created" is a valid table only if true: write one row `none | — | — | — | —`.

## Coordinator check (after every lane, again at batch close)
- [ ] table present and complete (compare with the task's own scripts/logs)
- [ ] every `removed` row actually gone (`ls`, `ps -p`, `lsof -i :PORT`, `git worktree list`)
- [ ] every `needs-coordinator` row: read the command, run it only on the exact target, then re-check
- [ ] kept items justified and recorded in GOAL-STATE `environment` / DECISIONS
- [ ] batch-close / goal-close sweep of the goal's own roots recorded in DECISIONS
