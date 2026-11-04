# Review-and-Drive Coordinator — PLAYBOOK (tool-agnostic)

This is the plain-markdown version of the `coordinator-review-drive` skill, for any agent (Claude Code, Codex,
dsh, others). It assumes only a shell and the ability to read/write files. Claude-specific notes are marked
**[Claude Code]**; generic equivalents are given next to them.

`SKILL` below means the absolute directory holding this file, resolved from the active harness's skill location
or `<checkout>/skills/coordinator-review-drive`. Keep its scripts and templates together when installing.

Built-in CLI adapters cover Codex, Claude Code, ZCode and dsh. Other harnesses need an adapter matching their
supported local interface. Historical model observations and quota estimates must be rechecked for each setup.

## Contents

- [Coordinator responsibilities](#0-what-the-coordinator-is)
- [Goal directory](#1-goal-directory-g)
- [Environment discovery](#2-step-one-environment-discovery-before-allocating-anything)
- [Task allocation](#3-allocation-by-capability)
- [Dispatch](#4-dispatch)
- [Lane reporting](#5-waiting--getting-lane-reports-reliably-waiters)
- [Review pipeline](#7-review-pipeline-every-fix)
- [Verification and deployment](#8-batches-verification-deploy-retests)
- [Decision authority](#9-decisions-decide-within-the-rules)
- [Records](#11-records-and-reporting)
- [Other harnesses](#12-using-this-playbook-from-other-agents)

---

## 0. What the coordinator is

You run a long software goal with several agents. Executors implement, test and pre-review. You:

- plan and write rulings (DECISIONS.md),
- allocate tasks to the right agent and keep every independent lane busy,
- review every result yourself before it is committed,
- commit, merge, verify, deploy (only with authority) and do the steps sandboxes cannot do,
- keep records that let anyone resume, and report to the user briefly and honestly.

You do not hand-run long test suites or bulk edits. You may write small, high-stakes code (merge conflicts,
integration fixes, data-safety one-liners) when delegating would be slower or riskier.

---

## 1. Goal directory `G`

Create it outside the product repo: `zsh SKILL/scripts/init-goal.sh <G> "<goal title>"`.

```
G/
  DECISIONS.md          numbered rulings (append only)
  GOAL-STATE.json       machine-readable state for resuming
  AGENT-LESSONS.md      lessons cited in every task card
  ALLOCATION.md         confirmed roster + session affinity map
  POLICY-HEADER.txt     prepended to every executor prompt (edit per project)
  LANES.txt             optional lane bookkeeping (read only by the legacy wait-lanes.sh)
  lanes/<area>/         task cards, plans, attribution reports, out dirs
  STAGE-REVIEWS/        second reviews and key-design reviews (PROMPT.md + out/)
  sessions/codex|claude named-session ids + locks (managed by wrappers)
  e2e-web/              real-page testing evidence
  model-probes/         live model probes (only with user consent)
```

Resuming a goal: read GOAL-STATE.json (`next`, `lanes`, `batches`, `pending_user`), the last ~30 DECISIONS
entries and AGENT-LESSONS.md; check which out dirs have FINISHED_UTC without `HANDLED`; continue. Never restart.
Only the legacy list waiter uses `.seen`; its reporting marker is not proof that the coordinator processed a result.

---

## 2. Step one: environment discovery (before allocating anything)

1. Run `zsh SKILL/scripts/probe-agents.sh`. It lists binaries and versions, the presence (not contents) of a few
   config locations, the browser/DevTools port, and host capacity. It never reads credentials and calls no model.
2. Ask the user one consolidated question:
   - Which agents may be used now, under which account? (e.g. Codex model ids, zcode/GLM, dsh provider+model,
     Claude Opus/Sonnet/Haiku subagents, headless `claude -p`, others)
   - Exact model id + effort for each role you intend to use.
   - Quotas and windows (5-hour / weekly / credits); which are scarce; cost ceilings.
   - Authority: push, merge to main, deploy (which targets), real providers or paid calls, user data, browser
     accounts for testing.
   - Language for records and reports.
3. Only with consent: one tiny live probe per model through its wrapper ("Reply exactly PROBE_OK") into
   `G/model-probes/<name>/`. If an error is ambiguous, compare with a deliberately bogus model id.
4. Record D-001 (probe results, user answers, routing, authority), `GOAL-STATE.environment`, `GOAL-STATE.authority`,
   and fill ALLOCATION.md. Redo discovery for an agent whenever quotas/auth change or it starts failing.

---

## 3. Allocation by capability

| Role | Typical agent | Use for | Do not use for |
|------|---------------|---------|----------------|
| Main implementer | cheap, reliable, parallel (e.g. Codex sol high) | root causes; state/lifecycle/recovery; data safety; cross-module; real-page testing; writing plan + RED for the cheap executor | reviewing itself |
| Cheap executor pool | several fast/cheap models (e.g. a small Codex model, a flash model, dsh Muse) | well-specified tasks with every decision written into the brief (cheap models stop at open decisions): small edits; review-finding fixes; harness/test tooling; diagnosis with clear acceptance; doc edits; long test runs; mechanical implementation of a plan + RED | lifecycle/state/multi-field UI; unclear root causes; open design choices |
| Mandatory second reviewer | read-only (e.g. zcode GLM plan) | every fix diff; P0–P3 with file:line; optional small-edit executor trial | sole gate for key designs; reviewing its own change |
| Key-design cross-reviewer | expensive (e.g. Codex astra) | key designs only, jointly with the coordinator; one review per design version, looped until PASS (§7.1) | re-checks, conformance checks, spot checks |
| Stronger subagent | strongest available (e.g. Claude Opus) | lanes that failed twice; design-dense new work; hard integration; key-design review when the cross-reviewer is down; independent review of a change the usual reviewer wrote | skipping review; spawning sub-agents |
| Cheap researcher/runner | small model headless | web research with sources; fixed-command test runs | judgement |
| Coordinator | you | decisions, core review, commit/merge/deploy, sandbox-impossible steps, small key code | bulk implementation |

Rules:
- **Session affinity**: the same task type always goes to the same named session (`<agent>-<tasktype>`, e.g.
  `sol-impl-import`, `sol-web-tester-stage`, `astra-key-plans`). Resumed sessions reuse memory and prompt caches.
  One task at a time per session (wrappers enforce a lock).
- **Parallelism**: run every independent lane concurrently; serialize only when lanes share mutable state (one
  worktree, one hot-reloaded instance, one test account). Never let independent stages wait behind one blocker.
- **One writer per worktree** whenever schema or test collection may be affected.
- **Pipelining**: build the next surface while the previous one is being tested.
- **Plan + RED handoff**: for large mechanical work, the main implementer writes the plan to file:function level and
  real failing tests; the cheap executor implements until RED is GREEN without editing the RED assertions. Full
  verification before merge is still required (cheap executors tend to run fewer tests).
- **Reallocation**: failed twice → stronger subagent; wrong root cause on lifecycle/state → main implementer;
  reviewer truncates → batched output with end marker, then change reviewer; agent unavailable → rediscover.
- **Author ≠ reviewer**: if the usual second reviewer wrote a change (e.g. trialled as executor), another model
  reviews it. No model signs off its own work, including the strongest one.
- **Spend by value**: spread simple work over the whole cheap pool; expensive models only for key design, key
  review and small key code. An expensive agent that only waits on a long run or polls is burning quota: hand the run
  to a cheap executor and let the agent report from its evidence. Tell lanes that touch the same area about each
  other's commits/branches (two lanes once built the same decoupling independently).
- **Strong-model concurrency and pacing** (§3.1): hard cap (e.g. ≤ 4, each told "no sub-agents or forks"; ~16 parallel
  strong agents once used up a 5-hour window in under an hour); normally 1–2 at a time along a planned straight line.
- **Low-quota mode** (coordinator quota scarce): read only verdict lines, lengthen waits, move spot checks to a named
  substitute reviewer, keep personally data safety, P0/P1, deploy approval, merges, pre-commit total review; switch
  back when the quota refreshes. Record both switches.

### 3.1 Provider failures, quota pacing and fallback routing

Record the user's fallback order in ALLOCATION.md (e.g. *cheap executor exhausted → trial the reviewer model as
executor for small clear fixes → main implementer → strongest model within quota*). On any failure below, reroute the
stuck lane to the next agent in the **same worktree** with the same card (it continues from the current state), and
write a DECISIONS entry naming the failure, the reset/fix, and the new route.

| Failure | Signal | What to do |
|---------|--------|------------|
| Subscription/quota exhausted | HTTP 429 with a reset date; all attempts upstream errors, no edits | stop dispatching to that provider until the reset; GOAL-STATE notes the date; re-probe after it |
| Credits exhausted | HTTP 402 / insufficient funds mid-run | check balances with the user before long loops on metered routes |
| CLI auth revoked | HTTP 401, refresh token revoked | every lane on that CLI is blocked; tell the user the exact fix (e.g. `codex logout && codex login`); after "done", verify with one trivial exec (`Reply exactly PROBE_OK`) before re-dispatching |
| Your own window | `quota-pace.py` every ~30 min | follow the WINDOW-PLAN below: START when behind the line, HOLD when ahead, FINISH-ONLY in the last ~40 min; never kill a running strong task for quota unless truly at the limit |
| Weekly quota | meter / user report | scarce → reserve for key reviews and decisions; resetting soon with quota left → deliberately spend it on queued important work |

**Pacing the coordinator's window (WINDOW-PLAN).** At each reset write a DECISIONS entry: an ordered queue of
important, bounded strong-model tasks with cost estimates (big implementation ~15–25 %, review/design ~5–10 %,
coordination reserve ~10–15 %) summing to ~95 %. Run 1–2 at a time and follow the line `target × elapsed / window`
with `python3 SKILL/scripts/quota-pace.py` (official used % from statusline snapshots, or `--used/--resets-at`).
Prefer not starting over stopping: a burst of 4 agents at a reset hit ~90 % in 2.5 h, tasks were stopped mid-way
(lost context and cache) and nothing was left for review. Long or unbounded work goes to cheap executors.

**Measuring the coordinator's quota without an official %.** Usage dashboards may use block boundaries that differ from the official window,
so calibrate: `python3 SKILL/scripts/claude-quota.py --ref-start <t0> --ref-end <t1> --cur-start <t2>` weights tokens
(input 1, output 5, cache-read 0.1, cache-create 1.25) for the current window and divides by a reference window that
hit 100 %. Check it reproduces a percentage the user read in the UI, then use it before every batch. Resuming a
subagent that carries hundreds of K tokens re-sends that context every step: prefer a fresh compact brief unless the
previous context is small and directly needed (e.g. a same-page follow-up).

**Trialling an executor** (new model, or the reviewer model as executor): timebox (~45 min), small clear scope, judge
evidence not claims, and keep a track-record row in AGENT-LESSONS (task · rounds · first-round defects · residual after
review · notes). Example from one run: a reviewer model in a CLI "edit" mode wrote correct, in-scope code but its
sandbox blocked python/node, so it ran nothing; the coordinator ran the tests and fixed three test-side issues.
Verdict: usable for small, clearly scoped edits with the coordinator running tests and another model reviewing.

---

## 4. Dispatch

1. Write the ruling (DECISIONS entry) first.
2. Create a lane worktree if the lane edits code:
   `zsh SKILL/scripts/make-lane-worktree.sh <repo> <worktrees-root> <slug> <base-sha> [dep-relpath …]`
3. Write the task card from `templates/TASK-CARD.md` (implementer cards reference `PREAMBLE-IMPLEMENTER.md`; read-only
   roles reference `PREAMBLE-READONLY.md`). Save under `G/lanes/<area>/TASK-<SLUG>[-N].md`; never overwrite a card.
4. Choose a NEW out dir (`G/lanes/<area>/out-<slug>[-rN]`) and start the wrapper detached with `launch-lane.sh`
   (`bash SKILL/scripts/launch-lane.sh <out> zsh SKILL/scripts/<wrapper> … <out>`; it returns at once and records
   `WRAPPER_PID`). Wrappers:

```
zsh SKILL/scripts/run-codex.sh      <G> <session> <cwd> <read-only|workspace-write> <model> <effort> <card> <out>
zsh SKILL/scripts/run-codex-web.sh  <G> <session> <cwd> <model> <effort> <card> <out>
zsh SKILL/scripts/run-dsh.sh        <G> <workdir> <card> <out> <provider> <model> <effort> [read-only|workspace-write]
zsh SKILL/scripts/run-zcode-review.sh <G> <worktree> <prompt> <out> [model-label]
zsh SKILL/scripts/run-zcode-exec.sh   <G> <worktree> <card> <out> [model-label]
zsh SKILL/scripts/run-claude.sh     <G> <session|-> <cwd> <model> <prompt> <out> [allowed-tools]
```
   Then arm exactly one waiter for the lane (§5). Claude subagents go through the Agent tool with the same card text
   (one worktree/branch per subagent); they need no waiter.
5. **Verify the launch**: `<out>/STARTED_UTC` exists within ~10 s (always call wrappers as `zsh <script>`: without +x a
   nohup launch fails silently), and the tool log soon shows a keyword from the card. The prompt argument is a FILE
   path; passing text instead leaves the executor with only the policy header. A model-id typo fails within seconds:
   if `FINISHED_UTC` appears almost at once, read the first error line of the tool log.
6. Optionally note `<out> <label>` in `G/LANES.txt` for bookkeeping (the per-lane waiter does not read it).

### Card hygiene (every brief)
- Write cards with a **quoted heredoc** (`cat > TASK.md <<'EOF' … EOF`), then fill placeholders with `sed`. An
  unquoted heredoc runs backticked words as commands and silently deletes them from the card.
- Name the goal's forbidden tests and demand an explicit exclusion on every broad run (e.g. `pytest --ignore=<path>`);
  check reused runner scripts for the exclusion too.
- Size-uncertain work carries a **stop threshold** (`templates/TASK-CARD.md` §G).
- Web cards: "never close, kill or restart the shared browser; close only the tabs you opened".
- Review prompts for models that tend to plan-then-wait: "Do NOT enter plan mode; print the COMPLETE review as your
  final message; last line REVIEW-END". (The CLI's read-only permission mode stays on; this line is about the model's
  answer style.)
- Executors that cannot run tests or git (edit-only sandboxes) are told so: "do not run git or tests; the coordinator
  runs them" — and you do.
- Every card ends with the Cleanup line and the RESOURCE-HANDOFF table requirement.

### Process hygiene for launches and long-lived helpers
- Launch each lane independently with `launch-lane.sh` (detached, PID recorded), then start its waiter separately in
  the harness's background mode: a lane started with `&` inside the waiter dies when the waiter exits, and a waiter
  started with `nohup`/`&` never notifies you.
- Long-lived services started from a tool shell (dev servers, the shared headless browser) need a detached start
  (`( nohup … & )` double fork, or `&!`/disown in a script) and a port check after the command returns; otherwise they
  are reaped with the tool shell.
- Aborting a wrapper: killing the wrapper does not stop its child CLI process; find and stop the child by its recorded
  PID / exact session or workdir, confirm with `ps`, then relaunch. Otherwise two runs write one worktree.
- **Live runs** serve from a dedicated detached worktree at their pinned SHA; never commit into a tree serving a live
  run (an autoreload reset in-flight requests). Agents and harnesses write docs/logs/run output outside product
  worktrees (or into an ignored folder), otherwise clean-tree gates refuse to run.
- Do not move the coordinator's own session into a worktree while subagents run (some harnesses then confine every
  subagent's shell to it).
- Pollers must not use an unanchored `pgrep -f <pattern>` (it matches the poller's own argv); use recorded PIDs, log
  markers or an anchored pattern (`pgrep -f "^/bin/zsh /abs/path/script.sh"`). After subagents finish, look for
  leftover `until … sleep` shells and stop them.
- **Shared headless browser for web lanes**: one coordinator-owned Chrome with a dedicated profile and a DevTools port,
  kept alive by `scripts/chrome-supervisor.sh <port> <profile-dir>` (started detached; one supervisor per profile;
  restarts only after 3 failed checks, killing the old Chrome first; gives up after 3 restarts in 10 min — a version
  without these limits stacked Chromes until an OOM reaper killed every lane).
- **Host capacity**: at most 2–3 heavy jobs at once (parallel test runs, executor lanes, builds, deploys); one browser
  tester at a time, ≤ 3 tabs each; check free memory and load before each wave; never deploy during a broad suite. Testers never close, kill or restart it; they close only their own tabs. At each check, list
  `http://127.0.0.1:<port>/json/list` and close only duplicate tabs owned by a finished lane (leaked tabs push load up
  and slow every lane).

### Out-dir contract (all wrappers)

| File | Meaning |
|------|---------|
| `WRAPPER_PID`, `LAUNCHED_UTC`, `launcher.log` | written by `launch-lane.sh` before the wrapper starts |
| `STARTED_UTC`, `PID`, `DISPATCH.json` | written at start (tool, session, requested model/effort, cwd, mode) |
| `PROMPT.sent.md` | exactly what was sent (policy header + card) |
| tool logs | `codex.log` / `stderr.attemptN.log` + `RETRIES.log` / `REVIEW.md` + `REVIEW-STATUS` / `result.json` + `MODEL-USAGE.txt` |
| `LAST-MESSAGE.md` | the executor's final reply (first line = status keyword) |
| `EXIT_CODE` then `FINISHED_UTC` | written last, in that order, also on TERM/INT |
| `HANDLED` | written by YOU after the result is processed (never earlier) |
| `.seen` / `.stall-reported` / `.dead-reported` | written only by the legacy `wait-lanes.sh` |

Never reuse an out dir. If a name must be reused, move the old markers into `<out>/prev-<UTC>/` first (keep them).

---

## 5. Waiting — getting lane reports reliably (waiters)

**How returns reach you:** headless executors (codex/dsh/zcode/claude -p) never message you; they only write
`LAST-MESSAGE.md`/`REVIEW.md`, `EXIT_CODE` and finally `FINISHED_UTC` in their out dir. You pull. The wake-up is the
harness noticing that a background waiter YOU started has exited. Agent-tool subagents are the exception: their final
report is pushed to you as a notification (still verify their diff/worktree).

### 5.1 One waiter per lane, in the harness's background mode
```
# launch (foreground, returns at once; writes <out>/WRAPPER_PID, LAUNCHED_UTC, launcher.log)
bash SKILL/scripts/launch-lane.sh $OUT zsh SKILL/scripts/run-dsh.sh $G $WT $CARD $OUT <provider> <model> <effort>
# waiter — [Claude Code] Bash with run_in_background: true
bash SKILL/scripts/wait-lane.sh $OUT --stall 2400 --max 21600
```
- Every detached lane gets **exactly one** waiter. Start it with the harness's background mode, **never with `nohup`
  or `&`**: a detached waiter exits unseen and no notification ever arrives.
- `--stall` = seconds with no file change anywhere in the out dir (default 2400); raise it for executors that write
  nothing until the end (dsh) or long quiet test runs. `--max` = waiter lifetime (default 21600), not a lane timeout.
  `--output FILE` names the reply file if it is not `LAST-MESSAGE.md` / `REVIEW.md` / `RESULT.md`.
- **[Generic]** no background notifications (plain CLI, other agents): run `wait-lane.sh $OUT --max 540` in the
  foreground between other work, or run the sweep (§5.3) from cron.

### 5.2 Read the FIRST line, then act
The waiter **always exits 0** (its exit status means nothing). Its first line is the verdict; below it come known
error signatures found in the logs (counts) and the tail of the reply or logs.

| First line | Meaning | Do |
|---|---|---|
| `LANE DONE exit=0 output=ok` | finished with a reply | process it (§6), then `touch $OUT/HANDLED` |
| `LANE DONE exit=N output=EMPTY` / `MISSING`, or signatures `at capacity`, `model_not_found`, provider `"type":"500"`/`系统异常`, `429` | finished without a usable reply | relaunch the **same session** into a NEW out dir (`$OUT-r2`; the wrappers resume a named session) with a short "continue; print your final report" card; `model_not_found` → fix the model id first (a typo fails within seconds) |
| `LANE DIED wrapper pid=… gone without FINISHED_UTC` | wrapper killed/crashed | read `launcher.log` and the tool log tail, kill any orphaned child CLI, relaunch into a new out dir |
| `LANE STALL idle=Ns` | no file change for `--stall` s | inspect log tail, `ps -p $(cat $OUT/WRAPPER_PID)`, recent worktree changes; still working → re-arm with a longer `--stall`; hung → kill wrapper + child, resume the session into a new out dir |
| `LANE TIMEOUT still-running` | waiter hit `--max`; lane alive | arm a new waiter on the same out dir; nothing else |
| `PID EXITED` / `PID STALL` / `PID TIMEOUT` | `--pid` form (§5.4) | read the log tail; restart the loop or re-arm |

### 5.3 State lives in the out dir, not in the waiter
- `FINISHED_UTC`, `EXIT_CODE` and the reply file are the source of truth. Waiters keep no state, so re-arming one on a
  finished lane just reports DONE again — safe.
- Mark a lane handled (`touch $OUT/HANDLED`) **only after** you processed its result (reply read, triaged, recorded).
- **Never kill a waiter to add new lanes**: a new lane gets its own new waiter. Stop a waiter only when its lane is
  abandoned, and then by its exact task id/PID.
- Optional fallback sweep every ~20 min (ScheduleWakeup / cron / loop) catches any report that slipped through:
  ```
  find $G/lanes -name FINISHED_UTC | while read f; do d=${f%/FINISHED_UTC}; [ -e "$d/HANDLED" ] || echo "UNHANDLED $d"; done
  ```

### 5.4 Long-running loops
For a process that is not a wrapper (e.g. a demo runner loop): `bash SKILL/scripts/wait-lane.sh --pid <PID> --log <file>
--stall 3600` (background mode as above). It reports `PID EXITED`, `PID STALL` (log quiet, process alive) or
`PID TIMEOUT`.

### 5.5 Pitfalls (real incidents)
- **Unanchored `pgrep -f <out-dir or script name>`** matches the waiter's own argv: a chained waiter waited 2.5 h on
  itself, and waiters matched each other. Liveness only via the recorded PID (`kill -0 $(cat $OUT/WRAPPER_PID)`) or an
  anchored pattern: `pgrep -f "^/bin/zsh /abs/path/script.sh"`.
- **zsh globs with no match abort the whole command** (`no matches found`): use `find`, or `setopt NULL_GLOB`.
- **`grep -c` exits 1 when the count is 0**: inside a waiter that made a finished lane look like a failed waiter. Do
  not let a grep status become the waiter's status (wait-lane.sh always exits 0).
- **Marking "handled" before the notification was delivered, then killing the waiter, lost the report** (Windows
  coordinator, 2026-11-04). Mark handled only after processing; never kill a waiter to make room.
- **A model-id typo fails the lane instantly**: a DONE within seconds means read the first error line, not the reply.
- **Chaining** ("after A, start B"): wait on A's `FINISHED_UTC` or A's recorded PID, never on a process pattern that
  also appears in the chain's own argv.
- **Mass kills** (OOM reaper, reboot, harness killing background shells): waiters and chains may be gone while lanes
  look alive. Check each lane's `WRAPPER_PID`/markers, kill orphaned children, relaunch dead lanes into new out dirs,
  re-arm one waiter per live lane. Give executors a runtime cap; compare "waiting on background" lanes against
  wall-clock progress about hourly.

### 5.6 Legacy list waiter
`zsh SKILL/scripts/wait-lanes.sh <G> <lane-list> [stall=1800] [poll=30]` watches a lane list and exits on the first
`DONE` (marks `.seen` when it reports — i.e. before you handled it), `STALL`, `DEAD` or `ALL-SEEN`. Use it only where
per-lane waiters are impossible, and never on the same lanes as `wait-lane.sh`.

---

## 6. Handling hand-backs (first line of LAST-MESSAGE.md)

| First line | Action |
|------------|--------|
| READY-FOR-REVIEW | review pipeline (§7) |
| NEED-DECISION | read the proposal (`templates/PROPOSAL-NEED-DECISION.md` shape), decide within the rules (§9), record, re-dispatch to the same session; a stop-threshold hand-back (RED + DESIGN) goes to the key-design review first (§7.1) |
| NEED-RESTART | restart the instance yourself: find the real listening PID, stop it, wait until the old PID has exited, start, require a new PID + health 200; then resume the tester |
| BLOCKED / sandbox refusal | do the step yourself (bounded script, hard timeout, own process group, own temp root, cleanup) or hand the user exact commands |
| PLAN-READY | review the plan; key design → cross-review; then dispatch implementation |
| REPORT | read, verify one key number, record |
| no report / no temp-env table | not ready: send back |

Treat executor root-cause statements as INFERRED until you or the second reviewer confirm them in code.

---

## 7. Review pipeline (every fix)

1. **Second review** with `templates/REVIEW-SECOND.md` via `run-zcode-review.sh` (or the confirmed reviewer).
   REVIEW-STATUS INCOMPLETE → rerun into a new out dir with "output directly, batched parts, end marker". When the
   second reviewer authored the change, a different model does this review.
2. **Coordinator core review** with `templates/CORE-REVIEW-CHECKLIST.md`: scope incl. untracked files, read key
   product diffs (locks, transactions, ownership/privacy gates, user-facing text, counters/money, schema, public
   shapes), verify each P0–P2 finding in code, recompute or rerun at least one number, node-level baseline comparison.
3. **Key designs**: you review first; then the cross-review loop (§7.1) until PASS; finalize the ruling with the
   adopted changes ("adopt APPROVE-WITH-CHANGES: …").
4. **Findings loop**: back to the same session; P0–P2 fixed or explicitly deferred with a decision; P3s batched for a
   pre-commit cleanup (cheap executor). A narrow follow-up with a clear RED may be accepted by you without another
   review round — record that you did so.
5. **Commit** on the lane branch: `git status --porcelain` (all entries incl. `??`), review each, `git add <explicit
   paths>`, message names the decision. Never `git add -A`/`.`. Executors in sandboxes that cannot write the shared
   `.git` metadata (e.g. Codex workspace-write) only edit files; you do the git operations.

### 7.1 Key-design cross-review loop and stop thresholds

```
designer (strong model)  ──DESIGN.md──▶  coordinator review  ──▶  cross-reviewer (independent model)
      ▲                                                                  │ PASS → ruling → implement
      └──── DESIGN-v2.md / v3.md (new file each round) ◀── FAIL + numbered P1/P2 ──┘
```
- Each round: the reviewer re-checks every previous finding (CLOSED / OPEN / PARTIAL) and looks for new ones. Keep
  every version and every review side by side; the DECISIONS entry per round lists what closed and what remains.
- Between rounds the coordinator steers to keep the loop converging: cut scope ("renames may be declared unsupported
  if that does not block the release"), pin open questions to defaults, or split a follow-up design.
- When only narrow residual MUSTs remain, the coordinator may close them in a written revision/amendment and ask the
  reviewer to confirm just those.
- When the usual cross-reviewer is unavailable (auth, quota), a strong subagent may do the key-design review; record
  the substitution.
- Pre-registered experiments/plans change only through a written amendment made before any result exists; drafts
  stay inactive until reviewed; no rule is lowered after seeing data.
- **Stop thresholds**: a size-uncertain card says "if this needs more than ~N lines of product change or a lifecycle
  redesign, STOP after the RED and a written design; do not ship a half implementation". When a lane stops, the
  key-design review chooses:
  - (a) implement the design now (if the release can absorb it), or
  - (b) **ship it disabled**: a shared availability helper; a typed refusal (e.g. `<feature>_unavailable`) at every
    entry point *before* any write or send, allowlisted in the public error mapping; an availability flag in the read
    projections computed by the same helper; the UI disables the action before consent with reason copy; the original
    RED kept as a strict expected-failure; the full design (often a smaller safe variant) goes to the backlog.
  Check first whether the feature ever worked in any mode; disabling something that never worked removes nothing.

---

## 8. Batches, verification, deploy, retests

Follow `templates/BATCH-VERIFY-DEPLOY-CHECKLIST.md`. In short:

1. Temporary batch branch from the integration head; `--no-ff` merge lane branches in a written order; truthful
   conflict resolution recorded per file.
2. Full verification by one executor in the batch tree: node-level comparison against the saved baseline log (§8.1;
   new failures = 0; inherited failures listed by node), metric budgets not grown, regenerated artifacts checked.
   Integration-only test fixes are reviewed and committed separately.
3. Sandbox-impossible checks by you, natively and bounded. HANG ≠ PASS: attribute against the baseline.
4. Approve (bound to the exact committed HEAD) → prepare → deploy only with authority and only through the guarded
   entry the user allowed (§8.2). Blocked by a permission classifier → give the user the exact ordered commands; never
   retry or bypass. Health by real PID. Back up changed start scripts.
5. `--ff-only` the integration branch to the verified head.
6. Parallel real-page retests (one tester per surface, own project/session/page).
7. Resource teardown from an exact list (every lane's RESOURCE-HANDOFF table, checked against reality, plus a sweep of
   the batch roots); the batch is not closed until done. See SKILL.md §6.1 and templates/RESOURCE-HANDOFF.md.

### 8.1 Gate integrity
A gate is only as good as its comparison. Observed failure mode: a run accepted "zero regressions" because per-file
failure counts matched a clean HEAD, then treated a list of named clusters as dispositions; weeks of affected-subset
testing had let the integrated suite drift to well over a thousand failures plus setup errors, and the protected
release step (which accepts only a green suite) could not run. Rules:
- **Unit of comparison** = (test node id, phase, failure signature). Phase ∈ collection / setup / call / teardown;
  signature = exception type + normalized message or reason code. Per-file counts and samples are not regression proof.
  A new reason on a known-failing node is a new failure.
- **Errors ≠ failures.** Setup/collection errors mean the body never ran: classify them separately and state how many
  tests never executed.
- **Disposition per node, not per cluster.** Root-cause clusters are for understanding and burn-down; an accepted
  failure needs its own ledger entry (node, phase, signature, version, evidence, impact, owner, deadline), confirmed
  deferrable by an independent review. No cluster or wildcard exemptions; collection errors cannot be ledgered.
  MUST-FIX regardless: new regressions, and anything touching permissions, data integrity, transactions/concurrency,
  metering/budget, privacy, or the release's core features.
- **A ledger-based gate** (if the user chooses one) blocks: new failures, a new reason on the same node, missing tests,
  unapproved skips; fixed entries leave the ledger and a later failure blocks; expired entries block. The ledger
  scheme itself is a key design → cross-review loop (§7.1).
- **Gate drift**: write the gate's exact wording into DECISIONS when it is set and re-read it at each batch; "no new
  failures in this lane" is not the same gate as "the integrated suite is resolved".
- **Periodic broad runs**: at every RC / integration milestone, run the broad canonical suite (sharded if needed, with
  an environment preflight: interpreter, DB kind, required env vars) and compare node by node. Incremental testing
  between milestones stays as in the test cost rules below.
- **Language**: "gate passed with N reviewed ledger entries" — never "green" or "all passing".
- **Real-model smoke gates** prove only the steps they cover; a broader e2e run found real bugs right after a smoke
  PASS. Extend coverage stepwise, with call/time limits derived from measured runs; offer per-path runs for cheap
  retries, but only one all-paths PASS on the frozen SHA counts; validate harness request payloads offline against the
  product's real request models first (two live runs failed on harness payloads). Run a minimal real-model smoke after
  every merge that touches a generation path.
- Ask an independent reviewer "why are there so many failures?" when counts are large: the answer (contract changes
  without consumer updates, receipts checked against moved bytes, default switches, wrong DB kind, sandbox/network,
  incomplete env) usually reveals process gaps, not just bugs.

### 8.2 Deploy pipeline (local/test instance, only with authority)
Use `templates/DEPLOY-HANDOFF.md`. Shape that worked across many deploys:
1. **Rebind** the deploy toolkit to the exact candidate HEAD (an executor, offline): pin over the deployed file set,
   file count updated, offline self-check PASS. Any later commit → rebind again; merge everything first, then rebind
   once.
2. Coordinator runs: **inspect-live** (know the expected refusals, e.g. an anonymous capability readback is REFUSED by
   design), **approve-source** (sealed to HEAD), **dry-run** (source-only validated).
3. **run-deploy** through the single allowed guarded entry, within the user's recorded authorization. A new subcommand
   does not grant new authority or widen its scope. If the auto-mode classifier blocks it, hand the user the one exact command (absolute paths, no `cd &&`
   prefix) and keep other lanes moving.
4. **Verify receipts**: HEAD, build byte-equality, migration head, health by real PID, login smoke, expected provider
   call count; then dispatch acceptance lanes.
5. **Refusals**: a guarded step that refuses mid-run is diagnosed, not retried blindly; fix narrowly, add a resume
   subcommand ("continue after X refusal") instead of re-running finished phases.

### Test cost rules
- Small checkpoints run only the tests tied to the change (plus targeted counterexamples for concurrency/migration/
  ownership changes). No full suite per small patch.
- Freeze the candidate, then run the whole-stage matrix ONCE. After a matrix finding: first failure reason → targeted
  RED→GREEN → rerun only the lanes the new diff invalidates; list which results still bind unchanged bytes.
- Compare against saved baseline logs instead of re-running pristine HEAD (by node, phase and signature — §8.1).
- Before any long run write: scope, expected duration, freeze identity, why incremental is insufficient; use a load
  gate (1-minute load ≤ N); never start a duplicate matrix or contend for the same owned database.
- Incremental is the rule between milestones, not forever: a broad canonical run at each RC/milestone (§8.1) catches
  the debt that affected-subset runs cannot see.

### Real-page testing
- Use `templates/WEB-TESTER-TASK.md`. Staged: one stage passes before the next; no fallback paths; the tester may fix
  in place only in a designated fix worktree (root cause + tests + fix log; HIGH-RISK flagged) and escalates after two
  failed attempts or when a design/migration/API decision is needed. Testers reply NEED-RESTART after backend changes.
- The coordinator prepares the instance and browser natively, confirms which code is running, and never restarts a
  hot-reloaded instance while someone is mid-edit in that tree. Do not run live tests against an instance whose files
  (verified by bytes or version at runtime) an implementer is editing: you get version-skew false failures.
- Acceptance judges real capability and persistence (refresh + read-only DB/API check), not "it responded".
- If the acceptance object carries edge history (an old job, legacy data), run a parallel lane on a **fresh** object
  for the normal new-user path while the edge case is fixed.
- **Live failures need typed, content-free diagnostics.** A generic refusal (`state_conflict`, an unclassified
  `ValueError`) is not a root cause: have the owner add fixed sub-reason codes at the boundary (one safe log line;
  same-family identifiers such as row id, attempt, token counts, finish reason; never prompts, responses, user text or
  secrets), redeploy, re-run once, and fix the exact predicate named. Tolerances are narrow and evidence-backed; never
  loosen claim/accounting/authorization. Record model-call counts per acceptance.
- **Design iteration keeps a "liked effects" list** (things the user explicitly liked); review/scoring rules may not
  remove items on it without asking the user.
- Report each acceptance round to the user with `templates/ACCEPTANCE-REPORT.md` (one row per stage).

---

## 9. Decisions: decide within the rules

- Decide design, policy and lifecycle questions yourself: plan, appropriate review, choose the option most
  conservative toward approved rules and best for the project, record the reasoning. Do not interrupt the user.
- Ask the user only for genuinely new authority or major requirement changes: push/merge to main/deploy beyond the
  grant, real providers or spending beyond limits, widened permissions, user-data handling, stopping the run, or a
  real change to what the product must do. Batch such questions; keep other lanes moving meanwhile.
- User instructions about the way of working get their own DECISIONS entry with a verbatim quote and override this
  playbook.
- Prefer the smaller design that keeps the same guarantees; record rejected alternatives in one line each. Fixes
  target the feature with the smallest change owned by one module; when unsure, 2–3 parallel cheap research lanes,
  then decide; ask for a simplification review before accepting a complex fix and push back on MUSTs that add
  machinery without user value.
- Every ruling cites its evidence (tests, measurements, verdicts, sources; measured vs inferred).

### 9.1 Fix the class, not the instance
- After 2–3 failures of the same class, stop patching: audit the whole class and fix it with one general mechanism
  (one shared helper/step, distinct reason codes). Repeated review rounds on one mechanism mean the design is wrong.
- Read the raw evidence first: keep the runtime of failing live runs and have the designer read the actual outputs.
- Audit prompts for self-contradiction (a stated limit plus "do not truncate"; "drop" plus "never delete"; prompt
  stricter than schema) before adding machinery.
- Provenance over values: record whether a limit is user-set, declared by the provider/route, or a default; enforce
  only the first two as hard limits; defaults are estimates.
- Error transparency: never collapse unknown errors into a specific misleading code; a misleading user message is a
  product bug — map each cause to an accurate, fixable message.
- Sealed/versioned contracts (pinned schemas, manifest hashes, registered packs) are immutable: decouple consumers via
  a frozen copy plus a drift test; never regenerate the sealed artifact; changes go into a new version.
- Approve directly anything that advances the project and follows an earlier recorded decision (cite it); still ask
  for new scope, irreversible/outward actions not yet granted, and anything contradicting earlier consensus.
- Narrowing a safety guard or changing its checked value is the user's security decision: stop and present options.
- When a gate conflicts with an earlier ruling (e.g. a strict main-merge gate vs. an accepted red baseline), do not
  pick silently: give the user 2–3 options with cost and time, recommend one, and keep the other lanes moving.
- Before blocking on "the user must provide a key/account", check the recorded environment and memory first.
- **Classifier-blocked steps**: never retry or rephrase. Batch so the user runs as few commands as possible (merge
  everything, rebind once, then one deploy command). Give exact absolute-path commands, in order, with time limits.

---

## 10. Safety rules (non-negotiable)

- No `git add -A` / `git add .`; protect dirty trees (work in your own worktree; never stash/reset/checkout over
  others' changes; if you must stash, use a uniquely tagged entry and apply by sha); no force push; no push, merge to
  main or production deploy without explicit user authorization.
- No permission-bypass flags or modes (`--dangerously-bypass*`, `danger-full-access`, yolo,
  `--dangerously-skip-permissions`). Do not bypass permission classifiers; give the user exact commands instead.
- Never read, print or forward secrets, tokens, auth/session files or .env files. Pass paths, not contents.
- Real manuscripts/user data are never uploaded or sent to models; use synthetic data. Contributor/training-tier model
  sessions never see private fixtures, evidence dirs or imported user text; screenshots go only to reviewers whose
  image path stays local (some CLIs upload images to an external host).
- Diagnostics added for live failures are content-free (fixed reason codes, ids, counts); never log provider
  content, user text or secrets.
- Never close, kill or restart the shared browser/instances other lanes use; close only what your lane opened.
- No SQL resets/backfills or direct counter edits; use the product's real, audited paths (e.g. formal grants).
- Never relabel failures, skips, hangs or sandbox denials as passes. RED first. Never weaken or delete assertions,
  add skip/xfail or loosen guards to get green.
- One writer per worktree when schema/test collection is affected. Never reuse an out dir. One task per session.
- MANDATORY test resource reclaim (SKILL.md §6.1): every card carries the Cleanup line; every reply ends with a
  RESOURCE-HANDOFF table (no table = not accepted); you verify and remove leftovers after each lane and sweep at batch
  and goal close; deletions only from an exact reviewed list; broader disk cleanup only on request.
- Executors never call paid reviewers or start other agents (policy header).

---

## 11. Records and reporting

- **DECISIONS.md**: `## D-NNN <result-first title>（<who>，<YYYY-MM-DD>）`; facts → severity (P0–P3) → root cause
  (CONFIRMED / INFERRED) → ruling (constraints) → dispatch → acceptance; follow-ups as `- D-NNN 补充 / follow-up:`
  bullets under the newest entry. User's language, plain words, numbers with units. Append only; never renumber.
- **GOAL-STATE.json**: update at every state change (lanes, batches, sessions, followups, backlog, pending_user,
  next). Another window must be able to resume from it alone.
- **AGENT-LESSONS.md**: symptom → root cause → from now on, with the proving D-number; cite relevant numbers in cards.
- **User updates**: in the user's language (briefs to agents may stay English); result first; one short table per
  acceptance stage (`templates/ACCEPTANCE-REPORT.md`: stage · result · evidence/numbers · next); what is running; and
  a plain "Needs you:" line with exact commands, or "Needs you: nothing". Honest about HANG, NOT RUN, sandbox denials,
  inferences and gate status ("gate passed with N ledger entries", never "green"). No narration.
- **Final report**: outcomes per area, open followups/backlog, resources left (with reason), decisions the user may
  want to revisit.

---

## 12. Using this playbook from other agents

- **Codex**: add to the repo's or the user's `AGENTS.md`:
  `When asked to act as coordinator (主控/审核推进), read and follow <absolute-skill-directory>/PLAYBOOK.md;
  scripts are in its scripts/ dir; never run them with bypass flags.` A Codex coordinator inside a sandbox may be
  unable to start other CLIs, write shared git metadata or run native tests: then write the exact commands for the
  user (or a bounded script) instead of looking for a workaround.
- **dsh**: put the same sentence in the task/system prompt; run with a workspace-write sandbox rooted at G or the repo.
- **Any agent**: shell runners use zsh/bash and quota helpers use Python. Codex, Claude and dsh accept model
  arguments; ZCode's model label only records a request and its local provider configuration selects the model.
  Background notifications and the Agent tool are harness-specific; use the documented fallback when absent.
- **Other CLIs** (e.g. `muse exec`): wrap them the same way as `run-dsh.sh` — sandbox and approvals on with a
  never-prompt approval mode (refusals are reported, never auto-approved), policy header prepended, retries only on
  upstream model/transport errors, the out-dir contract (`STARTED_UTC` … `EXIT_CODE`, `FINISHED_UTC`). Use exact model
  ids (suffixes matter) and confirm the model actually used.

## Cheap-model page testers (historical observations, 2026-10-29)
- A cheap model (DeepSeek v4.1 Flash max via dsh) can be the main real-page tester. Give it a headless Chrome through the chrome-devtools MCP (registered via the overlay's `insert:`). Pass credentials through a redacting stdio adapter (`@file:` references), never in plain text.
- Separate concurrent testers by hostname, not port (cookies are per host). Each project gets its own Chrome/port.
- Let it fix UI/display issues. Route data-semantics fixes (facts, identity, author values, write-back, persistence, privacy, safety guards) to the strong executor. Have every cheap-model fix reviewed by a different model.
- Plan for its context cap: small snapshots, scripted reads, split rounds, and continuation tasks seeded with the evidence gathered so far.
- It can't stage/commit or kill processes in its sandbox: the coordinator stages, commits and cleans up. Make it restart services only through the managed scripts.
