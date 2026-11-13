# Routing: discovery, allocation, provider failures, quota

Read when: starting a goal, an agent/quota/auth changes, or you are choosing who does a task.
The CURRENT roster and routing live in `G/ALLOCATION.md` (rewritten in place; one file, see `STATE.md`).

## 1. Environment discovery (first step of a new goal)

1. Run `zsh $SKILL/scripts/probe-agents.sh` (binaries/versions/config presence/host capacity only; it never reads
   secrets and spends no quota).
2. Ask the user **one consolidated question** (AskUserQuestion or plain text): which agents may be used now and under
   which account; exact model ids/effort per role; quota windows and which are scarce; cost limits; authority (push,
   merge, deploy, real providers/paid calls, user data, browser accounts); record language.
3. Only with consent, run one tiny live probe per model ("Reply exactly PROBE_OK") through the matching wrapper into
   `G/model-probes/<name>/`; compare against a bogus-model control if errors look ambiguous.
4. Record **D-001** (what was probed, what the user confirmed, routing, authority), `GOAL-STATE.environment`, and fill
   `ALLOCATION.md`. Re-run discovery for an agent whenever the user reports quota/auth changes or a tool starts failing.
   Never assume an agent from a previous goal is still available.

## 2. Allocation by capability (fill concrete agents from step 1)

| Role | Gets | Never gets |
|------|------|-----------|
| **Main implementer** (cheap, reliable, parallel; e.g. a strong Codex model at high effort) | root causes, state/lifecycle/recovery, data safety, cross-module work, real-page testing, plans + RED tests for the cheap executors | its own reviews |
| **Cheap executor pool** (several fast/cheap models; e.g. a small Codex model, a flash model behind `dsh`) | well-specified tasks **with every decision already written into the brief** (cheap models stop at open decisions): small edits, review-finding fixes, harness/test tooling, diagnosis with clear acceptance, doc/amendment edits, long test runs, mechanical implementation of a plan + RED | lifecycle/state/multi-field UI, ambiguous root causes, open design choices |
| **Mandatory second reviewer** (read-only, another model family; e.g. a GLM model in ZCode plan mode) | every fix diff, P0–P3 with file:line; batched output with end marker; may be trialled as a small-edit executor (then someone else reviews) | being the only gate for key designs; reviewing its own change |
| **Key-design cross-reviewer** (expensive, rationed; e.g. the strongest model you can use, read-only) | key designs only, together with you (security/ownership/transactions, recovery protocols, gate/CI designs, plan-level designs, variant choices); one review per design version, looped until PASS | conformance re-checks, fix re-verification, spot checks |
| **Stronger subagent** (e.g. a strong Claude subagent via the Agent tool, own worktree) | a lane the main implementer failed twice, design-dense new implementation, hard integration conflicts/attribution, key-design review when the cross-reviewer is down, independent review of a change the usual reviewer authored | exemption from review; spawning its own sub-agents |
| **Cheap researcher / runner** (e.g. headless `claude -p` small model) | web research with sources, fixed-command test runs | judgement calls |
| **Coordinator (you)** | decisions, core review, commits/merges/deploys, sandbox-impossible steps (native tests, real DB clusters, shared git metadata), small key code | bulk implementation |

Rules: **same task type → same named session** (e.g. `impl-<area>`, `web-tester-<surface>`, `key-plans`; one task
at a time per session; keep the map in ALLOCATION.md).
**Parallelize independent lanes inside the WIP limit** (SKILL.md §1): main-track lanes first; an idle executor is not a
reason to start side work. Serialize lanes that share mutable state.
**One writer per worktree** when schema or test collection can be affected. Every executor's output — including the
strongest model's — goes through second review + your core review. Reallocate on the triggers in ALLOCATION.md.
**Author ≠ reviewer**: when the usual reviewer authored a change (e.g. the GLM second reviewer trialled as executor),
a different model reviews it (e.g. a strong subagent); a model never signs off its own work.
**Spend by value**: spread simple work across the whole cheap pool (never default to one executor); keep expensive
models for key design, key review and small key code. An expensive agent that is only waiting on a long test run or
polling is burning quota: hand the run to a cheap executor and have it finish its report from the evidence it has
(why: an agent polling a hung suite pushed the window ~20 points above the pacing line). When two lanes touch the same area, tell each about
the other's commits/branches in the brief (why: two lanes independently built the same decoupling).
- **Plan + RED handoff**: for large mechanical work, the main implementer writes the plan to file:function level and
  real failing tests; the cheap executor implements until RED is GREEN without editing the RED assertions.
- **Reallocation**: failed twice → stronger subagent; wrong root cause on lifecycle/state → main implementer;
  reviewer truncates → batched output with end marker, then change reviewer; agent unavailable → rediscover.

### 2.1 Provider failures, quotas and fallback routing
Providers fail mid-goal; route around them instead of stalling, and record every reroute as a DECISIONS entry.
- **Fallback order comes from the user** (e.g. "cheap executor exhausted → trial the reviewer model as executor for
  small fixes → main implementer → strongest model within quota"). Keep it in ALLOCATION.md; reroute the stuck lane
  to the next agent in the **same worktree** (it continues from the current state), with the same card.
- **Quota exhaustion** (e.g. HTTP 429 until a stated reset date, 402 insufficient credits): stop dispatching to that
  provider until the reset; note the reset time in GOAL-STATE; re-probe after it. A run whose attempts were all
  upstream errors produced nothing; do not count it as a try.
- **Auth revoked** (e.g. Codex `401` / refresh token revoked): every lane on that CLI is blocked. Tell the user the
  exact fix (`codex logout && codex login`), move urgent work to the fallback agent, and once the user reports done
  verify with one trivial exec ("Reply exactly PROBE_OK") before re-dispatching.
- **Your own quota (5-hour / weekly windows)**: measure, do not guess — prefer the official used % and reset time
  (`scripts/quota-pace.py` reads statusline snapshots or `--used/--resets-at`); else a meter calibrated against a
  window the user saw at a known % (`scripts/claude-quota.py`). Then **pace, do not burst**:
  - at each reset write a WINDOW-PLAN in DECISIONS: an ordered queue of important, bounded strong-model tasks with
    cost estimates (big implementation ~15–25 %, review/design ~5–10 %, coordination reserve ~10–15 %) summing to
    ~95 %;
  - run 1–2 strong agents at a time (hard cap e.g. ≤ 4, each told "no sub-agents or forks") and follow the straight
    line `target × elapsed / window`: check `quota-pace.py` about every 30 min (a cron/loop) — START the next queued
    task when behind, HOLD when ahead, FINISH-ONLY in the last ~40 min;
  - never kill a strong task midway for quota (lost context and cache) unless the window is really at the limit;
    prefer not starting over stopping. Why: bursting 4 agents at a reset hit ~90 % in 2.5 h, tasks were stopped
    mid-way and the rest of the window had nothing left for review;
  - before a longer non-renewing quota (e.g. weekly) resets, deliberately spend what is left on queued important work.
  Resuming a subagent with hundreds of K tokens of context re-sends it every step: prefer a fresh compact brief
  unless the old context is small and directly needed (an agent stopped mid-redesign is the exception).
- **Trialling a new executor**: timebox it, give it a small clear task, judge the evidence (not the claim), and keep a
  track-record row (rounds, residual defects after review) in AGENT-LESSONS before widening its scope.

**Low-quota mode** (your quota scarce; record the switch): read only first lines/verdicts, lengthen waiter timeouts,
move spot checks to the named substitute reviewer, keep personally: data safety, P0/P1, pre-deploy approval, merges,
pre-commit total review. Restore and re-plan routing as soon as the quota refreshes.

## 3. Provider notes (observations; verify against the installed version before relying on them)
- **ZCode headless model choice.** Headless `zcode -p` was observed to ignore the `model.main` value of its CLI config
  and to run its default model. Choosing a model per session needs the app-server protocol (a small stdio client
  that sets the model on session create/send; not bundled here). Verify which model actually ran in ZCode's own
  usage records, never from the model's self-report. Account plans that need the desktop host to push credentials
  cannot be used headless; never read credentials to work around this.
- **Exact model ids.** Aliases can resolve to older models and suffixes matter; record the id the CLI reports.
