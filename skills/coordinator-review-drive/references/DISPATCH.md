# Dispatch: cards, launch, waiters, hand-backs

Read when: writing a card, launching a lane, a waiter fires, or a lane misbehaves.

## 1. Dispatch
- Lane isolation: one worktree + branch per lane (`scripts/make-lane-worktree.sh <repo> <root> <slug> <base> [deps…]`).
- Card from `templates/TASK-CARD.md` (+ `PREAMBLE-IMPLEMENTER.md` / `PREAMBLE-READONLY.md`), saved under
  `G/lanes/<area>/TASK-<SLUG>.md` (new file per round: `-2`, `-3`, …). Cite AGENT-LESSONS numbers relevant to it.
- Start the wrapper **detached with `launch-lane.sh`** into a **new** out dir (it returns at once and records
  `WRAPPER_PID`; then arm the lane's waiter, §2):
  `bash $SKILL/scripts/launch-lane.sh <out> zsh $SKILL/scripts/<wrapper>.sh <wrapper args…ending in the same <out>>`
  - `run-codex.sh <G> <session> <cwd> <read-only|workspace-write> <model> <effort> <card> <out>`
  - `run-codex-web.sh <G> <session> <cwd> <model> <effort> <card> <out>` (browser testers)
  - `run-dsh.sh <G> <workdir> <card> <out> <provider> <model> <effort> [mode]` (cheap executor; upstream-error retries)
  - `run-zcode-review.sh <G> <worktree> <prompt> <out> [model-label]` (second review, plan/read-only)
  - `run-zcode-exec.sh <G> <worktree> <card> <out> [model-label]` (reviewer model as small-edit executor, edit mode;
    it usually cannot run python/node, so **you run the tests**)
  - `run-claude.sh <G> <session|-> <cwd> <model> <prompt> <out> [allowed-tools]` (headless claude)
  - Claude subagents: Agent tool (model=opus/sonnet; isolation worktree or an explicit lane worktree), same card text.
- **Card contract (linted; ideas adapted from pstack, see `SOURCES.md`)**: every card starts with `CARD:`,
  `TRACK:` (main|side), `GOAL:` (the user's goal, not the steps), `DONE-EVIDENCE:` (the behaviour the user would observe and the exact
  test/page scenario that shows it — written by you, so the executor cannot pick tests that only prove what it built),
  `SCOPE:`/`FORBIDDEN:`, numbered `ITEMS: I1…`, and the `REPLY-CONTRACT` block (`templates/TASK-CARD.md` §0).
  `launch-lane.sh` runs `check-card.sh` and refuses a failing card; `G/FORBIDDEN-TESTS.txt` lists tests every
  impl/fix/test card must name. If you cannot write DONE-EVIDENCE, the unit is not scoped yet.
- **One unit first**: a new card shape, a new executor or a batch of near-identical units starts with ONE lane; fan
  out only after its reply passed REPORT-CHECK and review (a flawed card then costs one lane, not five).
- Review prompts are cards too: launch them through `launch-lane.sh` like every other lane.
- **Own process group per lane**: `launch-lane.sh` starts each wrapper in its own session (PGID = WRAPPER_PID). Stop a
  lane only with `kill-lane.sh <out>`; never `kill -<pgid>` by hand (why: one group kill once took down 3 lanes).
- `launch-lane.sh` and the wrappers refuse a used out dir (stale markers made a waiter report an old result as new), refuse a busy session, prepend `G/POLICY-HEADER.txt`, record
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
- Every card also carries `TRACK: main|side` (SKILL.md §1); add the lane to the `WIP:` lines of `G/HANDOFF.md` when you
  launch it and remove it when it is handled.

## 2. Getting lane reports reliably (waiters)
**Who signals whom (read this first):**
- Headless executors (codex / dsh / zcode / `claude -p`) **cannot message you**. They only write files into their
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
   `bash $SKILL/scripts/launch-lane.sh $OUT zsh $SKILL/scripts/run-codex.sh $G impl-x $WT workspace-write <model> high $CARD $OUT`
2. Arm its waiter (Bash, `run_in_background: true`):
   `bash $SKILL/scripts/wait-lane.sh $OUT --stall 2400 --max 21600`
   (raise `--stall` for executors that write nothing until the end, e.g. dsh, or long quiet test runs).
3. Meanwhile do coordinator work. **Never sleep-poll in the foreground.**
4. On the notification read the waiter's **FIRST line** (it always exits 0, so the exit status tells you nothing):

| First line | Do |
|---|---|
| `LANE DONE exit=0 output=ok` | process the result (step 5) |
| `LANE DONE … output=EMPTY\|MISSING`, non-zero exit, or an error signature printed below it (`at capacity`, `model_not_found`, provider `500`, `429`) | a crash or provider error on the SAME work: relaunch into a NEW out dir (`$OUT-r2`); the same named session may be resumed, and it gets the **same full card** again. Anything after a reply or a review is a new round and gets a full round-N card. A bare "continue" is never sent. For `model_not_found` fix the model id first |
| `LANE DIED` | wrapper gone without `FINISHED_UTC`: read the log tail, kill any orphaned child CLI, relaunch into a new out dir |
| `LANE STALL idle=…` | inspect log tail, `ps -p $(cat $OUT/WRAPPER_PID)` and recent worktree changes; still working → re-arm with a longer `--stall`; hung → `kill-lane.sh <out>`, then relaunch into a new out dir with a full round-N card |
| `LANE TIMEOUT still-running` | the lane is still running: just arm a new waiter on the same out dir |

5. Process the result: `EXIT_CODE`, the reply (for reviews check the end marker, e.g. `REVIEW-END`), the files it
   points to, its RESOURCE-HANDOFF table (`SAFETY.md` §3); triage by its first line (§3). **Only after that** mark it handled:
   `touch $OUT/HANDLED`.

**Rules:**
- The out-dir markers (`FINISHED_UTC`, `EXIT_CODE`, the output file) are the source of truth; waiters keep no state.
  Re-arming a waiter on a finished lane simply reports DONE again — harmless.
- New lane = new waiter. **Never kill a running waiter to add lanes**; stop a waiter only when its lane is abandoned.
- Optional fallback sweep every ~20 min (ScheduleWakeup / cron) for lanes that finished but were never handled:
  `find $G/lanes -name FINISHED_UTC | while read f; do d=${f%/FINISHED_UTC}; [ -e "$d/HANDLED" ] || echo "UNHANDLED $d"; done`
- Long-running loops (e.g. a demo runner loop): `bash $SKILL/scripts/wait-lane.sh --pid <PID> --log <file> --stall 3600`
  → `PID EXITED` / `PID STALL` / `PID TIMEOUT`.
- Pitfalls (real incidents): liveness only via the recorded PID or an anchored pattern
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

## 3. Triage the hand-back by its first line
- `READY-FOR-REVIEW` → review pipeline (`REVIEW-AND-GATES.md` §2).
- `NEED-DECISION` → read the proposal; decide within the rules (`SAFETY.md` §1) and record; re-dispatch to the same session. A
  lane that hit its stop threshold replies NEED-DECISION with RED + DESIGN paths: route it to the key-design review
  (`REVIEW-AND-GATES.md` §1), not back to the executor.
- `NEED-RESTART` → restart the instance yourself (by real PID; old PID must exit; health 200), then resume the tester.
- `BLOCKED` / sandbox refusal → do the sandbox-impossible step yourself, bounded; or give the user exact `!` commands.
- `PLAN-READY` → review the plan (key design → cross-review), then dispatch implementation.
- No report / no temporary-environments table → not ready; send it back.
- **`REPORT-CHECK FAIL`** (printed by the waiter under the verdict) → not accepted, whatever the first line says.
  Send a full round-N card (original card + later rulings + this reply + what is missing). Never "continue".
- **Retry by cause** (pstack Orchestrate): context/memory limit → smaller scope; dropped connection / provider 5xx →
  same card, new out dir; tool or model error → different executor; **after two retries drop the unit and replan**
  around it (record why). A late reply from a stopped lane is checked against the current branch state first.
- **Read the artifact, not the summary**: `git -C <wt> status --short` + `git diff --stat`, open the key hunks, rerun
  one EVIDENCE command yourself. A claim about the tree that `git status` contradicts means the lane is still running
  or lying.

## 4. Process hygiene for launches and long-lived helpers
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

## 5. Out-dir contract (all wrappers)

| File | Meaning |
|------|---------|
| `WRAPPER_PID`, `WRAPPER_START`, `LAUNCHED_UTC`, `CARD_PATH`, `launcher.log` (+ `LEGACY_CARD`, `WIP_OVERRIDE`) | written by `launch-lane.sh` when it starts the wrapper |
| `STARTED_UTC`, `PID`, `DISPATCH.json` | written at start (tool, session, requested model/effort, cwd, mode) |
| `PROMPT.sent.md` | exactly what was sent (policy header + card) |
| tool logs | `codex.log` / `stderr.attemptN.log` + `RETRIES.log` / `REVIEW.md` + `REVIEW-STATUS` / `result.json` + `MODEL-USAGE.txt` |
| `LAST-MESSAGE.md` | the executor's final reply (first line = status keyword) |
| `EXIT_CODE` then `FINISHED_UTC` | written last, in that order, also on TERM/INT |
| `HANDLED` | written by YOU after the result is processed (never earlier) |
| `.seen` / `.stall-reported` / `.dead-reported` | written only by the legacy `wait-lanes.sh` |

Never reuse an out dir. If a name must be reused, move the old markers into `<out>/prev-<UTC>/` first (keep them).

---
