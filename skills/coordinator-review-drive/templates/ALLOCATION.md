# ALLOCATION — confirmed roster and task routing (fill after environment discovery; update with a D-entry on change)

Confirmed with the user on <UTC> (D-<NNN>). Only agents listed here may be dispatched.

Distinguish requested model labels from verified runtime model IDs. Keep observations specific to the task,
harness version and date; prior examples and quota percentages are planning estimates, not provider limits.

| Role | Agent / tool | Exact model + effort | Wrapper | Session names (task-type affinity) | Quota / cost notes |
|------|--------------|----------------------|---------|------------------------------------|--------------------|
| Coordinator (decide, core review, commit/merge/deploy, sandbox-impossible steps, small key code) | <this session> | <model> | — | — | <window> |
| Main implementer (cheap, reliable, parallel; root causes, state/lifecycle, data safety, cross-module, real-page tests, plans+RED) | <e.g. Codex> | <model, effort> | run-codex.sh / run-codex-web.sh | <impl-area-a>, <impl-area-b>, <web-tester-x> | <…> |
| Cheap executor pool (well-specified tasks with the decisions in the brief; small edits; review-list fixes; harness/test tooling; long test runs; mechanical plan+RED implementation) — list every cheap model and spread the load | <e.g. small Codex model; flash model; dsh> | <model, effort each> | run-codex.sh / run-dsh.sh | (stateless or per task type) | <…> |
| Mandatory second reviewer (read-only; every fix diff; P0–P3 with file:line; never its own change) | <e.g. zcode> | <model label> | run-zcode-review.sh (exec trial: run-zcode-exec.sh) | (stateless) | <…> |
| Key-design cross-reviewer (rationed; key designs only, jointly with coordinator; loop per design version until PASS) | <e.g. Codex> | <model, effort> | run-codex.sh (read-only) | <key-plans>, <lane-review> | expensive |
| Stronger subagent (looped twice; design-dense new work; hard integration conflicts; substitute key-design reviewer; independent reviewer of the reviewer's own changes) | <e.g. Claude subagent> | <model> | Agent tool / run-claude.sh | one per task, own worktree; ≤ <4> in parallel; no sub-forks | <window meter> |
| Cheap researcher / fixed-command runner | <e.g. headless claude> | <full model id> | run-claude.sh | (one-off) | verify MODEL-USAGE.txt |

## Session affinity map (same task type → same named session, one task at a time per session)
| Task type | Session name | Agent |
|-----------|--------------|-------|
| <area A fixes> | <name> | <agent> |
| <stage web tests> | <name> | <agent> |
| <key-design cross-review> | <name> | <agent> |

## Low-quota mode (when the coordinator's own quota is scarce; record the switch in DECISIONS)
- Coordinator reads only first lines/verdicts of hand-backs, not full logs; longer waiter timeouts; batch results.
- Spot checks normally done by the coordinator move to <named reviewer>; the second reviewer stays mandatory.
- Coordinator still personally decides: data safety, P0/P1, pre-deploy approval, merges, pre-commit total review.
- Switch back (and re-plan the routing) as soon as the quota refreshes.

## Fallback order (from the user; quote it in DECISIONS)
<e.g. cheap executor exhausted → 1) trial the second-reviewer model as executor for small clear fixes (coordinator runs
tests; another model reviews) → 2) main implementer → 3) strongest model within its quota limits>

## Provider status (update on every change; DECISIONS entry per change)
| Agent | Status | Since | Reset / fix | Verified by |
|-------|--------|-------|-------------|-------------|
| <cheap executor> | OK / 429 exhausted / 402 credits / 401 auth revoked | <UTC> | <reset date / "user runs `<cli> logout && <cli> login`"> | <probe out dir> |

## Quota pacing (coordinator's own model)
- Meter: `python3 $SKILL/scripts/quota-pace.py` (official % from statusline snapshots, or `--used/--resets-at`);
  fallback `claude-quota.py` calibrated against a % the user read in the UI on <date>. Check about every 30 min.
- WINDOW-PLAN at each reset (DECISIONS): ordered queue of bounded strong-model tasks with % estimates summing to ~95 %;
  1–2 at a time on the straight line; START behind / HOLD ahead / FINISH-ONLY in the last ~40 min; never kill a
  running task for quota unless truly at the limit.
- Weekly window: <used %>, resets <time>; scarce → key reviews/decisions only; resetting soon with quota left → spend
  it on queued important work.

## Executor track record (new models / executor trials)
| Model | Task (D-NNN) | Rounds | First-round defects (by whom) | Residual after last round | Verdict / scope |
|-------|--------------|--------|-------------------------------|---------------------------|-----------------|

## Reallocation triggers
- Main implementer failed to converge twice on the same problem → stronger subagent (own worktree/branch).
- A cheap executor produced a wrong root cause or touched lifecycle/state → move that class to the main implementer.
- A reviewer truncates/does not finish → rerun with batched output + end marker; if still failing, change reviewer.
- An agent becomes unavailable (auth revoked, quota gone) → follow the fallback order (same worktree, same card), tell
  the user any fix only they can do, re-probe after the fix/reset, and record both switches.
- The usual reviewer authored a change → a different model reviews it.
