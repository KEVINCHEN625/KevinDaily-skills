---
name: coordinator-review-drive
description: Coordinate multi-agent software work across available local harnesses. Discover authorized agents and models, route tasks using observed capabilities and quota limits, dispatch isolated lanes, independently review changes, and maintain decisions, progress, and model lessons. Use when asked to act as coordinator, 主控, 审核推进 or 主控调度, to drive a project with multiple agents, or to resume a coordinated goal. Includes CLI wrappers for Codex, Claude Code, ZCode and dsh.
---

# Coordinator: review and drive (主控 / 审核推进)

You coordinate a long multi-agent software project. Executors implement, test and pre-review; you **plan, decide,
review, commit, merge, deploy (only when authorized) and keep every lane moving** without waiting on the user. Do not
hand-run long suites or bulk edits; you may write small, high-stakes code yourself (merge conflicts, integration
fixes, data-safety one-liners, a test seeding fix).

- `SKILL` = the absolute directory containing this `SKILL.md`, resolved from the current harness's skill location
  (or `<checkout>/skills/coordinator-review-drive`). Keep `scripts/`, `templates/`, `PLAYBOOK.md` and `README.md`
  together. Read the relevant PLAYBOOK sections for the current stage; do not assume a Claude-specific install path.
- `G` = the project goal dir, **outside** the product repo (e.g. `~/.codex/outputs/<project>-goal-<YYYY-MM-DD>/`),
  created with `scripts/init-goal.sh <G> "<title>"`. Holds DECISIONS.md, GOAL-STATE.json, AGENT-LESSONS.md,
  ALLOCATION.md, POLICY-HEADER.txt, LANES.txt, lanes/, STAGE-REVIEWS/, sessions/, e2e-web/, model-probes/.
- **Resuming**: if G exists, read GOAL-STATE.json (`next`, lanes, batches, pending_user), the last ~30 DECISIONS
  entries and AGENT-LESSONS.md, check which out dirs finished, then continue. Never restart a goal from scratch.

Built-in CLI adapters cover Codex, Claude Code, ZCode and dsh. Discovery of another binary does not add an adapter:
confirm its supported interface before following the extension procedure in PLAYBOOK §12. Model examples and
quota estimates below are author observations, not current provider guarantees; verify them in this environment.

## 1. Environment discovery — always the first step, before allocating anything

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
| **Main implementer** (cheap, reliable, parallel; e.g. Codex sol high) | root causes, state/lifecycle/recovery, data safety, cross-module work, real-page testing, plans + RED tests for the cheap executors | its own reviews |
| **Cheap executor pool** (several fast/cheap models; e.g. a small Codex model, a flash model, dsh Muse) | well-specified tasks **with every decision already written into the brief** (cheap models stop at open decisions): small edits, review-finding fixes, harness/test tooling, diagnosis with clear acceptance, doc/amendment edits, long test runs, mechanical implementation of a plan + RED | lifecycle/state/multi-field UI, ambiguous root causes, open design choices |
| **Mandatory second reviewer** (read-only; e.g. zcode GLM plan mode) | every fix diff, P0–P3 with file:line; batched output with end marker; may be trialled as a small-edit executor (then someone else reviews) | being the only gate for key designs; reviewing its own change |
| **Key-design cross-reviewer** (expensive, rationed; e.g. Codex astra) | key designs only, together with you (security/ownership/transactions, recovery protocols, gate/CI designs, plan-level designs, variant choices); one review per design version, looped until PASS | conformance re-checks, fix re-verification, spot checks |
| **Stronger subagent** (e.g. Claude Opus via Agent tool, own worktree) | a lane the main implementer failed twice, design-dense new implementation, hard integration conflicts/attribution, key-design review when the cross-reviewer is down, independent review of a change the usual reviewer authored | exemption from review; spawning its own sub-agents |
| **Cheap researcher / runner** (e.g. headless `claude -p` small model) | web research with sources, fixed-command test runs | judgement calls |
| **Coordinator (you)** | decisions, core review, commits/merges/deploys, sandbox-impossible steps (native tests, real DB clusters, shared git metadata), small key code | bulk implementation |

Rules: **same task type → same named session** (e.g. `sol-impl-<area>`, `sol-web-tester-<surface>`,
`astra-key-plans`; one task at a time per session; keep the map in ALLOCATION.md and GOAL-STATE.sessions).
**Parallelize every independent lane** and keep every executor busy; serialize only lanes that share mutable state.
**One writer per worktree** when schema or test collection can be affected. Every executor's output — including the
strongest model's — goes through second review + your core review. Reallocate on the triggers in ALLOCATION.md.
**Author ≠ reviewer**: when the usual reviewer authored a change (e.g. the GLM second reviewer trialled as executor),
a different model reviews it (e.g. an Opus subagent); a model never signs off its own work.
**Spend by value**: spread simple work across the whole cheap pool (never default to one executor); keep expensive
models for key design, key review and small key code. An expensive agent that is only waiting on a long test run or
polling is burning quota: hand the run to a cheap executor and have it finish its report from the evidence it has
(why: an agent polling a hung suite pushed the window ~20 points above the pacing line). When two lanes touch the same area, tell each about
the other's commits/branches in the brief (why: two lanes independently built the same decoupling).

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

## 3. The operating loop

### 3.1 Plan before code
- Scope + acceptance written in G (or the goal doc). Key plans: draft → cross-review → (web research of best practice
  when the area is product-shaping, via the cheap researcher) → revise → implement only after the review passes.
- **Key-design loop**: designer writes `DESIGN.md` → you review → independent cross-review → designer writes
  `DESIGN-v2.md` (never overwrite; v1/v2/v3 side by side) → re-review of the same reviewer against the previous findings
  → … until PASS. Between rounds steer scope (e.g. "declare X unsupported if that does not block the release") rather
  than letting the loop grow. When only narrow residual MUSTs remain, you may close them yourself in a written
  revision/amendment and ask the reviewer to confirm just those (saves a full designer round). Implementation starts
  only after PASS (`templates/REVIEW-KEY-DESIGN.md`). Every ruling is recorded with its reason and its evidence.
- **Simple, decoupled fixes**: target the feature behaviour with the smallest change owned by one module. When the
  right approach is unclear, run 2–3 parallel cheap research lanes and compare before deciding; before accepting a
  complex fix, ask for a simplification review, and push back on review MUSTs that add machinery without user value
  (why: patch-on-patch fixes grew counters and ledgers that a 3-part redesign later cut by ~30 %).
- **Pre-registered experiments/plans** change only through a written amendment made before any result exists (no
  rule is lowered after seeing data); drafts stay inactive until reviewed.
- **Stop thresholds** in every card whose size is uncertain: "if this needs more than ~N lines of product change or a
  lifecycle redesign, STOP after the RED and a written design" (`templates/TASK-CARD.md` §G). A stop is a success: it
  goes to a key-design review that chooses between implementing now and **shipping the feature disabled** (typed
  refusal before any write/send, availability flag in the read projection, UI disabled before consent, reason copy),
  with the full design moved to the backlog.
- Write the ruling first (DECISIONS entry), then the task card. Cards point to files; they never paste secrets.

### 3.2 Dispatch
- Lane isolation: one worktree + branch per lane (`scripts/make-lane-worktree.sh <repo> <root> <slug> <base> [deps…]`).
- Card from `templates/TASK-CARD.md` (+ `PREAMBLE-IMPLEMENTER.md` / `PREAMBLE-READONLY.md`), saved under
  `G/lanes/<area>/TASK-<SLUG>.md` (new file per round: `-2`, `-3`, …). Cite AGENT-LESSONS numbers relevant to it.
- Start the wrapper **detached with `launch-lane.sh`** into a **new** out dir (it returns at once and records
  `WRAPPER_PID`; then arm the lane's waiter, §3.3):
  `bash $SKILL/scripts/launch-lane.sh <out> zsh $SKILL/scripts/<wrapper>.sh <wrapper args…ending in the same <out>>`
  - `run-codex.sh <G> <session> <cwd> <read-only|workspace-write> <model> <effort> <card> <out>`
  - `run-codex-web.sh <G> <session> <cwd> <model> <effort> <card> <out>` (browser testers)
  - `run-dsh.sh <G> <workdir> <card> <out> <provider> <model> <effort> [mode]` (cheap executor; upstream-error retries)
  - `run-zcode-review.sh <G> <worktree> <prompt> <out> [model-label]` (second review, plan/read-only)
  - `run-zcode-exec.sh <G> <worktree> <card> <out> [model-label]` (reviewer model as small-edit executor, edit mode;
    it usually cannot run python/node, so **you run the tests**)
  - **GLM via ZCode — historical setup observed 2026-10-27; verify the installed version and account:** headless use went through `bigmodel-api`
    (GLM-5.3 reviews; GLM-5.3-Flash for simple tasks). The ZCode account plans (`account:bigmodel-start-plan`, free
    23:00–09:00 GMT+8; `account:bigmodel-individual-coding-plan`) can't be reached headless: the app-server needs the
    desktop host to push the account config and runtime credentials. Never read credentials to work around this.
    Headless `zcode -p` ignores `~/.zcode/cli/config.json` `model.main`, which is legacy migration input only, and it
    silently runs its default model. Pick the model per session through the app-server protocol (a small stdio client
    that sets `model: {providerId, modelId}` on `session/create` and on `session/send`). Verify which model actually
    ran in `~/.zcode/cli/db/db.sqlite` → `model_usage` (provider_id, model_id); never trust the model's self-report.
    These ZCode wrappers accept a `model-label` for records only; it does not select the runtime model. The app-server
    client described above is not bundled. Select through supported local configuration and verify actual usage.
    Treat prior GLM-5.3-Flash results as a local track record, and trial each new executor before widening its scope.
  - `run-claude.sh <G> <session|-> <cwd> <model> <prompt> <out> [allowed-tools]` (headless claude)
  - Claude subagents: Agent tool (model=opus/sonnet; isolation worktree or an explicit lane worktree), same card text.
- Wrappers refuse a used out dir (lesson: stale markers), refuse a busy session, prepend `G/POLICY-HEADER.txt`, record
  DISPATCH.json, and always end with `EXIT_CODE` then `FINISHED_UTC`.
- **Card hygiene**: write cards with a quoted heredoc (`cat > card.md <<'EOF'`, then `sed` for placeholders): an
  unquoted heredoc executes backticks and silently drops words. Pass the card **file path** to the wrapper, never its
  text. Every card names the goal's forbidden tests and requires an explicit exclusion (e.g. `--ignore=<path>`) on
  every broad selection; web cards say "never close, kill or restart the shared browser — close only your own tabs";
  read-only review prompts for models with a plan-then-wait habit say "Do NOT enter plan mode; print the complete
  review as your final message"; every card ends with the RESOURCE-HANDOFF requirement.
- **Verify the launch**: invoke wrappers as `zsh <script>` (a missing +x fails silently under nohup); within ~10 s
  check `<out>/STARTED_UTC` exists, and soon after that the tool log mentions a keyword from the card (a session that
  only received the policy header looks alive but does nothing). A model-id typo fails within seconds: if
  `FINISHED_UTC` appears almost at once, read the first error line of the tool log (`model_not_found` etc.).
- Optionally note `<out-dir> <label>` in `G/LANES.txt` for your own bookkeeping (the per-lane waiter does not read it).

### 3.3 Getting lane reports reliably (waiters)
**Who signals whom (read this first):**
- Headless executors (codex / dsh / zcode GLM / `claude -p`) **cannot message you**. They only write files into their
  out dir, always in this order: reply (`LAST-MESSAGE.md`, or `REVIEW.md` for reviewers) → `EXIT_CODE` →
  `FINISHED_UTC` **last**. Only `FINISHED_UTC` means "done"; never read a reply before it exists (it may be partial).
- **You are woken by the harness, not by the executor.** Each detached lane gets **exactly one waiter**, started in the
  harness's background mode (Claude Code: Bash with `run_in_background: true`). When the waiter exits, the harness
  sends you a task notification, which starts your next turn. **Never start a waiter with `nohup` or `&`**: then no
  notification arrives and you never hear about the lane.
- **Exception:** Claude subagents started with the Agent tool push their final report to you as a notification. Treat
  it as a claim: still read their diff/worktree yourself.

**The loop, for every lane:**
1. Launch (foreground; returns at once):
   `bash $SKILL/scripts/launch-lane.sh $OUT zsh $SKILL/scripts/run-codex.sh $G sol-impl-x $WT workspace-write <model> high $CARD $OUT`
2. Arm its waiter (Bash, `run_in_background: true`):
   `bash $SKILL/scripts/wait-lane.sh $OUT --stall 2400 --max 21600`
   (raise `--stall` for executors that write nothing until the end, e.g. dsh, or long quiet test runs).
3. Meanwhile do coordinator work. **Never sleep-poll in the foreground.**
4. On the notification read the waiter's **FIRST line** (it always exits 0, so the exit status tells you nothing):

| First line | Do |
|---|---|
| `LANE DONE exit=0 output=ok` | process the result (step 5) |
| `LANE DONE … output=EMPTY\|MISSING`, non-zero exit, or an error signature printed below it (`at capacity`, `model_not_found`, provider `500`, `429`) | relaunch the **same session** into a NEW out dir (`$OUT-r2`; the wrappers resume a named session) with "continue; print your final report"; for `model_not_found` fix the model id first |
| `LANE DIED` | wrapper gone without `FINISHED_UTC`: read the log tail, kill any orphaned child CLI, relaunch into a new out dir |
| `LANE STALL idle=…` | inspect log tail, `ps -p $(cat $OUT/WRAPPER_PID)` and recent worktree changes; still working → re-arm with a longer `--stall`; hung → kill wrapper + child, resume the session into a new out dir |
| `LANE TIMEOUT still-running` | the lane is still running: just arm a new waiter on the same out dir |

5. Process the result: `EXIT_CODE`, the reply (for reviews check the end marker, e.g. `REVIEW-END`), the files it
   points to, its RESOURCE-HANDOFF table (§6.1); triage by its first line (§3.4). **Only after that** mark it handled:
   `touch $OUT/HANDLED`.

**Rules:**
- The out-dir markers (`FINISHED_UTC`, `EXIT_CODE`, the output file) are the source of truth; waiters keep no state.
  Re-arming a waiter on a finished lane simply reports DONE again — harmless.
- New lane = new waiter. **Never kill a running waiter to add lanes**; stop a waiter only when its lane is abandoned.
- Optional fallback sweep every ~20 min (ScheduleWakeup / cron) for lanes that finished but were never handled:
  `find $G/lanes -name FINISHED_UTC | while read f; do d=${f%/FINISHED_UTC}; [ -e "$d/HANDLED" ] || echo "UNHANDLED $d"; done`
- Long-running loops (e.g. a demo runner loop): `bash $SKILL/scripts/wait-lane.sh --pid <PID> --log <file> --stall 3600`
  → `PID EXITED` / `PID STALL` / `PID TIMEOUT`.
- Pitfalls (real incidents, details in PLAYBOOK §5): liveness only via the recorded PID or an anchored pattern
  (`pgrep -f "^/bin/zsh /abs/path/script.sh"`) — an unanchored `pgrep -f <out-dir|script name>` matches the waiter's
  own argv (2.5 h lost; waiters matching each other); a zsh glob with no match aborts the command (use `find` or
  `setopt NULL_GLOB`); `grep -c` exits 1 on zero matches and makes a finished waiter look failed; marking a lane
  "handled" before its notification was delivered and then killing the waiter lost the report.
- **Chaining** ("when lane A finishes, start B"): wait on A's `FINISHED_UTC` or its recorded PID (`kill -0`), never on
  a process pattern that also appears in the chain's own argv.
- **Mass kills** (OOM reaper, reboot, harness killing background shells): waiters and chains may be gone while lanes
  look "running". Check each lane's `WRAPPER_PID`/markers, kill orphaned children, relaunch dead lanes into new out
  dirs and **re-arm one waiter per live lane**. Give each executor a runtime cap; compare lanes "waiting on background
  work" against wall-clock progress about hourly.
- Harness without background-exit notifications (plain CLI, other agents): run `wait-lane.sh $OUT --max 540` in the
  foreground between other work, or run the fallback sweep from cron.
- `wait-lanes.sh` (one waiter over a lane list, marks `.seen` when it reports) is legacy: use it only where per-lane
  waiters are impossible, and never on the same lanes as `wait-lane.sh`.

### 3.4 Triage the hand-back by its first line
- `READY-FOR-REVIEW` → §4 review pipeline.
- `NEED-DECISION` → read the proposal; decide within the rules (§5) and record; re-dispatch to the same session. A
  lane that hit its stop threshold replies NEED-DECISION with RED + DESIGN paths: route it to the key-design review
  (§3.1), not back to the executor.
- `NEED-RESTART` → restart the instance yourself (by real PID; old PID must exit; health 200), then resume the tester.
- `BLOCKED` / sandbox refusal → do the sandbox-impossible step yourself, bounded; or give the user exact `!` commands.
- `PLAN-READY` → review the plan (key design → cross-review), then dispatch implementation.
- No report / no temporary-environments table → not ready; send it back.

## 4. Review pipeline (every fix, no exceptions)

1. **Second review** (`templates/REVIEW-SECOND.md`) on the uncommitted diff; it may run in parallel with a real-page
   retest when the fix is already deployed to a test instance — pause that acceptance if a P0/P1 appears. If the
   second reviewer authored the diff, a different model reviews it (§2).
2. **Your core review** (`templates/CORE-REVIEW-CHECKLIST.md`): read the key product diffs yourself, verify each flagged
   finding against the code, recompute/rerun at least one key number, check failures against the baseline by node (§4.1).
3. **Key designs**: you review first, then the cross-review loop until PASS (§3.1, `templates/REVIEW-KEY-DESIGN.md`),
   then finalize the ruling.
4. Findings → back to the same session (P0–P2 must be fixed or consciously deferred with a decision; P3s are batched
   into a pre-commit cleanup, usually for a cheap executor). Narrow follow-ups with an explicit RED may be accepted
   by you without another review round — say so in the record.
5. **Commit** on the lane branch: list everything with `git status --porcelain` (including `??`), add explicit paths,
   message names the decision; record the sha.
6. **Batch**: `templates/BATCH-VERIFY-DEPLOY-CHECKLIST.md` — temp batch branch, `--no-ff` merges in a written order,
   full verification by one executor (node-level comparison vs saved baseline, §4.1), your native checks,
   approve/prepare/deploy only with authority (§4.2), `--ff-only` the integration branch, parallel real-page retests,
   resource teardown.
7. **Real-page testing** (`templates/WEB-TESTER-TASK.md`): staged, one stage passes before the next; no fallback paths;
   build the next surface while the previous one is being tested; never gate independent stages on one blocker. When
   the object under acceptance carries odd history (an old job, legacy data), open a parallel lane on a **fresh**
   object to prove the normal new-user path, while the edge case is fixed separately.

### 4.1 Gate integrity (do not let a gate quietly change meaning)
- **Compare by node, phase and signature**, never by per-file counts or samples: test node id × phase (collection /
  setup / call / teardown) × failure signature (exception type + normalized message/reason code). Equal per-file
  counts can hide a fixed failure plus a new one. "Same node, new reason" is a new failure.
- **Errors are not failures**: setup/collection errors mean the test body never ran. Report them separately as
  NOT EXECUTED, with the count of tests that never executed.
- **Naming a cluster is not a disposition.** Each accepted failure binds node, phase, signature, version and evidence,
  with impact, owner and deadline, and is confirmed deferrable by an independent review. No cluster or wildcard
  exemptions. Failures touching permissions, data integrity, transactions/concurrency, metering/budget, privacy or the
  release's core features are MUST-FIX, not ledger entries.
- **Watch for gate drift**: "resolve the integrated suite" slowly becoming "no new failures in this lane" is how a red
  baseline grows to hundreds of failures. Name the gate in DECISIONS and re-check it at every batch.
- **Run a broad canonical suite periodically** (each release candidate / integration milestone, not per patch):
  affected-subset testing alone hides accumulating debt from contract changes without consumer updates, receipts
  checked against moved bytes, default switches, and incomplete test environments. Preflight the environment
  (required env vars, DB kind, interpreter) so env gaps are not counted as product failures.
- **Words**: "gate passed (N accepted failures in the reviewed ledger)" is never "green". Report the real counts.
- **Real-model smoke gates**: a smoke only proves the steps it covers; its gaps hide real bugs (a broader e2e run
  found failures right after the smoke passed). Extend coverage stepwise toward the full path, with call/time limits
  derived from measured runs. Offer per-path runs (e.g. `--paths X`) so one path is retried cheaply, but only one
  all-paths PASS on the frozen SHA counts as the gate. Validate the harness's request payloads offline against the
  product's real request models before spending model calls (why: two live runs failed on harness payloads, not on
  the product). Run a minimal real-model smoke after every merge that touches a generation path.

### 4.2 Deploy pipeline (only with authority; template `templates/DEPLOY-HANDOFF.md`)
1. **Rebind the deploy toolkit to the exact HEAD** (a pin over the file set; executor does it offline): offline
   self-check passes, file count/pin updated. Approvals and pins bind one committed HEAD; any new commit → rebind.
2. Coordinator runs the read-only/preparatory steps: inspect-live (know which refusals are expected, e.g. an
   anonymous capability readback), approve-source (sealed to HEAD), dry-run (source-only validated).
3. The live deploy step: run it through the one guarded entry the user allowed. If the auto-mode classifier blocks it
   (it can, even with an allow rule), hand the user **one** ready-to-paste command; batch so the user runs as few
   commands as possible (e.g. rebind once after all merges, then deploy once).
4. **Verify receipts**: deployed HEAD, build byte-equality, migration head, health by real PID, login smoke, zero
   provider calls if none were expected. Then dispatch the acceptance lanes.
5. A guarded tool that **refuses** mid-deploy (e.g. "old deployment changed") is not retried blindly: diagnose
   (false positive vs real tamper), fix narrowly, and add a resume subcommand instead of re-running completed phases.

## 5. Decide within the rules; ask only for genuinely new authority

- Decide design/policy/lifecycle questions yourself: write the plan, get the appropriate review (cross-review for key
  designs), pick the option that is most conservative toward already-approved rules and best for the project, record
  the reasoning and its evidence (tests, measurements, review verdicts, sources; measured vs inferred). Do not
  interrupt the user with design questions. Approve directly anything that advances the goal and follows an earlier
  recorded decision (cite it); drop work with no evidenced benefit.
- Ask the user only for: push/merge to main/deploy beyond what was granted, real providers or spending beyond limits,
  widened permissions, user data handling, stopping the run, or a real change to what the product must do.
- When the Claude Code permission classifier blocks an action: never retry, rephrase or work around it. Give the exact
  ready-to-paste `!` commands (ordered, with time limits, as few as possible) or ask once for an allow rule on one
  fixed, guarded entry script whose new actions are added as subcommands; continue when the user reports done.
  Meanwhile keep the other lanes moving.
- Narrowing a safety guard or updating its checked value is a user-level security decision: on a guard false positive,
  stop and give the user the options and commands; do not edit first and explain later.
- Before blocking on "the user must enter a key/account", check the recorded environment and memory: test accounts and
  provider bindings are often already configured.
- User instructions about how to work become their own DECISIONS entry with the user's words quoted, and they win
  over this skill.

## 6. Safety rules (non-negotiable)

- Never `git add -A` / `git add .`; protect dirty trees (never stash/reset/checkout over someone's uncommitted work;
  use your own worktree); never force-push; never push, merge to main or deploy to production without explicit user
  authorization; never `--dangerously-bypass*`, `danger-full-access`, yolo modes or `--dangerously-skip-permissions`.
- Never read, print or forward secrets, tokens, auth/session files or .env files (pass paths, not contents; testers may
  read a test-account file only to fill a login form). Real manuscripts/user data are never uploaded; use synthetic data.
  Screenshots go only to reviewers whose image path stays local (some CLIs upload images to an external host).
- Diagnostics added for live failures are **content-free**: fixed sub-reason codes and same-family identifiers
  (row id, attempt number, token counts, finish reason), never provider prompts/responses, user text or secrets.
- No SQL resets/backfills to "fix" state or counters; use the product's real, audited paths.
- Never relabel failures, skips, hangs or sandbox denials as PASS; never weaken or delete assertions, add skip/xfail or
  loosen a guard to get green; RED first; tests use production-shaped inputs.
- One writer per worktree when schema/test collection is affected; never reuse an out dir; one task per named session.
- Test resources must be reclaimed after every test — see §6.1. Disk cleanup beyond that only on explicit user request.
- Executors never call paid reviewers or other agents themselves (the policy header instructs this; verify the
  actual harness permission boundaries rather than treating a prompt as operating-system enforcement).
- **Live runs get their own tree**: a long live run (e2e, experiment, smoke) serves from a dedicated detached worktree
  at its pinned SHA; never commit into or edit a tree that serves a live run (why: an autoreload on a commit reset
  in-flight requests and was mislabelled as a product failure). Gates that require a clean tree are blocked by
  anything written into it, so review/audit agents and harnesses write docs, logs and run output **outside** product
  worktrees (or into an ignored folder the clean check excludes).
- **Coordinator session**: do not switch your own session into a worktree while subagents run (some harnesses then
  confine every subagent's shell to it); use lane worktrees and write coordinator files to G.
- **Host capacity**: at most 2–3 heavy jobs at once (parallel test runs, executor lanes, builds, deploys), one
  browser tester at a time on the single supervised browser; check free memory/load before each wave; never deploy
  while a broad suite runs (why: stacked browsers caused an OOM whose reaper killed every lane; a deploy under load
  56 timed out and took the instance down).

### 6.1 Test resource reclaim (MANDATORY — a lane or batch is not done until this is done)
Everything a test creates must be removed when that test ends, pass or fail. Leftovers fill the disk, hold ports,
keep stale processes serving old code and make the next run lie.
- **What counts:** temp dirs and pytest `--basetemp` roots, test/SQLite DBs and DB copies, owned PostgreSQL clusters
  and their data dirs, started processes (backend/worker/frontend/browser/driver) and their ports, browser tabs/pages
  and browser profiles opened for the test, test projects/accounts created in an instance, scratch worktrees/branches,
  snapshot/verify worktrees, downloaded fixtures, large logs/artifacts that are not evidence.
- **Executor duty (put it in every card):** create everything under one own root (e.g. `<out>/tmp` or a `mktemp -d`
  root); use a `trap` so stop+delete happens on success, failure and timeout; kill by recorded PID/process group, never
  by name pattern; delete only paths it created. It ends its reply with a `RESOURCE-HANDOFF` table
  (`templates/RESOURCE-HANDOFF.md`): every resource created, its state (removed / kept-as-evidence / kept-running-on-
  purpose / could-not-remove + why), exact path/PID/port. A sandboxed executor that cannot remove something lists it
  as `needs-coordinator` with the exact command.
- **Coordinator duty:** no handoff table → reply not accepted (send it back). After each lane, check the table against
  reality (`ls` the paths, `lsof -i :<port>`, `ps -p <pid>`, `git worktree list`) and remove what was left, from the exact
  list only (read every rm/kill target first; never wildcard outside the lane root; never touch shared/user dirs,
  long-lived instances the goal still needs, or anything not created by the lane). Evidence that must be kept is moved
  into `<out>/evidence/`, small, and named in the report. At batch close and at goal close, do a final sweep of the
  goal's own roots and record the result in DECISIONS (what was removed, what was kept and why).
- Long-lived shared instances (the acceptance instance, the stage instance) are not test leftovers; they are listed in
  GOAL-STATE `environment` and torn down only at goal close or on user request.

## 7. Records and reporting

- **DECISIONS.md** (`templates/DECISIONS.md`): numbered D-NNN, dated, in the user's language, plain and readable,
  result-first titles; facts / severity / root cause (CONFIRMED vs INFERRED) / ruling / dispatch / acceptance;
  follow-ups as `D-NNN 补充` bullets on the newest entry. Append only.
- **GOAL-STATE.json**: lanes, batches, sessions, environment, authority, followups, backlog, pending_user, `next`.
  Update it at every state change so another window can resume.
- **AGENT-LESSONS.md**: symptom → root cause → from now on; fold in new lessons from reviews/retests; cite it in cards.
- **User updates**: in the user's language (agent briefs may stay English); result first; a short table per
  acceptance stage (stage · result · evidence/numbers · next) — `templates/ACCEPTANCE-REPORT.md`; then what is
  running, then **what needs the user** stated plainly with exact commands (or "nothing"). Numbers with units, honest
  about hangs, NOT RUN items and inferences; "gate passed" is never "green". No self-narration.
- Mark claims as confirmed or inferred; say plainly when something could not be accessed or verified.

### 7.1 Live acceptance finds what offline tests miss
Offline suites prove the code paths you thought of; the deployed instance with real configuration finds the rest
(empty legacy bindings, policy versions from older history, provider echo quirks). When a live check fails with a
generic code (`state_conflict`, `ValueError`, "unclassified"):
- do not guess a fix; first add **content-free typed diagnostics at the boundary** — a fixed set of sub-reason codes
  (e.g. `provider_unavailable`, `model_echo_mismatch`) logged in one safe line — so the next run names the exact
  predicate that failed;
- fix narrowly with evidence-backed tolerance only; never loosen claim/accounting/authorization to make it pass;
- one re-run per deploy; record the call counts each acceptance spent.

### 7.2 Fix the class, not the instance
- **After 2–3 failures of the same class** (the same kind of model-output drift, the same integrity hole found again
  by review), stop patching instances: audit the whole class and fix it with one general mechanism (one shared
  helper/step, distinct reason codes). Four rounds of instance patches on one ledger meant the design was wrong;
  a simpler design based on the real source of truth replaced it.
- **Read the raw evidence first**: keep the runtime of failing live runs (e.g. a keep-runtime flag) and have the
  designer read the actual outputs before designing; the cause is often one layer earlier than the symptom (a
  cleanup step deleted exactly the keys the repair needed).
- **Audit prompts for self-contradiction**: repair or stage prompts that state a limit and also forbid truncation,
  or ask to "drop" and "never delete" the same items, make models fail repairs; prompts stricter than the schema
  make repairs over-produce. Fix the wording before adding machinery.
- **Provenance over values**: before enforcing a number as a hard limit, record where it came from (user-set,
  declared by the provider/route, or a default/estimate); enforce only user-set or declared limits, treat defaults as
  estimates (why: a default silently became a hard cap that refused valid requests).
- **Error transparency**: never let a router or catch-all collapse unknown errors into a specific, misleading code
  (a masked `ValueError` became a "plan changed" conflict; a connection reset became "unknown send"; a diagnostic
  read in an except path hid the real provider error). A misleading user-facing message is a product bug: map each
  cause to an accurate, author-fixable message.
- **Sealed/versioned contracts are immutable**: when shared models drift from a sealed artifact (a pinned schema,
  a manifest hash, a registered pack), decouple the consumer via a frozen copy plus a drift test; never regenerate
  the sealed artifact (it breaks in-flight work pinned to it). Changes go into a new version.

## 8. Script reference

| Script | Purpose |
|--------|---------|
| `init-goal.sh <G> [title]` | create G from templates (never overwrites) |
| `probe-agents.sh [bin…]` | step-1 presence/version/capacity check; no secrets, no model calls |
| `make-lane-worktree.sh <repo> <root> <slug> <base> [dep…]` | lane worktree + branch, deps symlinked |
| `run-codex.sh` / `run-codex-web.sh` | Codex task / browser tester, named-session resume, policy header |
| `run-dsh.sh` | dsh headless task, model via args, retries on SERVER/TRANSPORT/PI_AI_ERROR server_error |
| `run-zcode-review.sh` | read-only second review, REVIEW-STATUS COMPLETE/INCOMPLETE by end marker |
| `run-zcode-exec.sh` | zcode in edit mode as a small-edit executor (no git/tests; coordinator runs tests; another model reviews) |
| `run-zcode-test-exec.sh` | macOS-only ZCode test runner using `sandbox-exec`; inspect its script header before use |
| `run-claude.sh` | headless claude -p, session reuse, MODEL-USAGE.txt to verify the real model |
| `launch-lane.sh <out> <wrapper> [args…]` | (bash) start a lane wrapper detached; records `WRAPPER_PID`, `LAUNCHED_UTC`, `launcher.log` |
| `wait-lane.sh <out> [--stall S] [--max S]` / `--pid P --log F` | (bash) ONE waiter per lane, run with run_in_background; always exits 0; first line LANE DONE/DIED/STALL/TIMEOUT (§3.3) |
| `wait-lanes.sh <G> <list> [stall] [poll]` | legacy list waiter: DONE/.seen, STALL, DEAD, ALL-SEEN |
| `quota-pace.py [--used P --resets-at T]` | used % vs the straight-line target → START / ON-TRACK / HOLD / FINISH-ONLY; warns when a weekly quota resets with quota unused; `capture` mode stores statusline rate limits (no credentials) |
| `claude-quota.py --ref-start … --ref-end … --cur-start …` | weighted Claude usage of the current window vs a reference window that hit 100 % (fallback when no official % is available) |
| `chrome-supervisor.sh <port> <profile-dir>` | keeps ONE shared headless Chrome alive (lock, restart only after 3 failures, kills the old one first, gives up after 3 restarts/10 min) |

Shell runners use zsh except `launch-lane.sh`/`wait-lane.sh` (bash); quota helpers use Python. Codex, Claude and dsh
take model arguments; ZCode takes a recording label and uses its local provider configuration. Environment settings
are documented in each script header. See PLAYBOOK.md for the procedure, output contract and worked examples.
