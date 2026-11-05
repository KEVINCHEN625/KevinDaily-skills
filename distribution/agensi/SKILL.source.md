---
name: coordinator-review-drive
description: Coordinate multi-agent software work with local Codex, Claude Code, ZCode and dsh harnesses. Assign bounded tasks using verified capabilities and project evidence, run independent work in parallel, receive completion signals through host-managed waiters, independently review changes, and preserve project decisions and model lessons. Use for 主控、审核推进、多模型调度, long-running software goals, or resuming a coordinated project. This edition is delivered through Agensi MCP.
---

# Coordinator Review Drive — Agensi edition

Act as the project coordinator: clarify the goal, assign work, review evidence, resolve integration issues,
and keep independent work moving. Let bounded worker tasks handle implementation, investigation and tests.
The coordinating agent makes routing decisions; this skill is not a standalone scheduling service.

## 1. Load resources and run scripts through Agensi

Agensi delivers this skill through MCP. Read the current skill and its file index at the start of each session.
Fetch supporting text only when needed using the listing's current slug and the exact path in that index.
Do not reconstruct an installed skill directory, save reusable instruction/template files, or cache a prior
copy for later sessions. Project-specific decisions, tasks, results and code are the user's working artifacts.

For an included script, fetch its complete text, write it **unchanged** to a uniquely named temporary file,
run it with the interpreter specified in its shebang, and remove that temporary file after its process ends.
Keep a background script's temporary file available until the process has actually finished. Do not truncate,
rewrite, concatenate or patch a downloaded script. Each script in this edition contains its own shared helpers
and required default data; no installed package directory is needed.

Refer to scripts by their individual temporary paths, such as `RUNNER_TMP`, `WAITER_TMP` and `INIT_TMP`.
These are task-local variables chosen by the coordinator, not pre-existing locations. Never overwrite `HOME`
or the host's system environment variables. This edition deliberately has no `launch-lane.sh` or `lib.zsh`:
the host launches each self-contained wrapper and manages its lifetime.

Read `PLAYBOOK.md` for dispatch arguments, completion handling, recovery and integration.
Use the resources below as in-context references, then write only the task-specific artifacts needed for the job:

| Resource | When to read it |
| --- | --- |
| `templates/TASK-CARD.md` | Before assigning a new task |
| `templates/PREAMBLE-IMPLEMENTER.md` | To define an implementer's responsibilities |
| `templates/PREAMBLE-READONLY.md` | To define a read-only task |
| `templates/REVIEW-SECOND.md` | Independent review and re-review |
| `templates/REVIEW-KEY-DESIGN.md` | A consequential design decision |
| `templates/CORE-REVIEW-CHECKLIST.md` | Coordinator's direct code and evidence review |
| `templates/RESOURCE-HANDOFF.md` | Processes, worktrees, services and evidence that need an owner |
| `templates/ACCEPTANCE-REPORT.md` | Stage or goal acceptance |
| `templates/BATCH-VERIFY-DEPLOY-CHECKLIST.md` | Authorized integration and deployment |
| `templates/DEPLOY-HANDOFF.md` | An authorized release requiring a user handoff |
| `templates/WEB-TESTER-TASK.md` | A browser testing task |
| `templates/DECISIONS.md` | Recording decisions and evidence |
| `templates/GOAL-STATE.json` | Recording or restoring current project state |
| `templates/ALLOCATION.md` | Model allocation and observed outcomes |
| `templates/AGENT-LESSONS.md` | Historical practices to evaluate against this project |
| `templates/LANES.txt` | Optional task index structure |
| `templates/POLICY-HEADER.txt` | Default worker instructions, also embedded in each wrapper |

Treat any package path mentioned inside a reference as an Agensi resource to fetch, not a local installed path.
Workers receive a task-specific brief with the required constraints and context; they must not be told to open
a skill directory that is unavailable on their machine. Historical examples are observations, not current model
benchmarks or universal capability guarantees.

## 2. Establish the goal, environment and authority

Record the user's desired outcome and measurable acceptance criteria. Reuse authority and preferences already
given in the conversation. Ask only for genuinely missing decisions, scope or permissions that block useful work.
Do not infer a deployment, purchase, data upload or account-change grant from a coding task.

Confirm local shell/file access and required interpreters: Zsh, Bash, Python 3, Perl and Git. Read and run the
self-contained `scripts/probe-agents.sh` to inspect available binaries, versions and host resources. Discovery
does not prove login, quota or model availability. Verify those from the user's confirmed setup and documented
CLI behavior; run a bounded live probe only when authorized.

Implemented worker integrations are Codex CLI, Claude Code, ZCode and DeepSeek Harness (`dsh`). Other detected
binaries need a supported invocation or a separate adapter. Do not invent a model identifier or assume a label
selects the runtime model. For ZCode, `model-label` records metadata; its provider configuration chooses the model.

Choose an absolute goal directory `G` outside the product repository. Run the temporary initializer:

```bash
zsh "$INIT_TMP" "$G" "Project goal"
```

It creates new project records and working directories without overwriting existing records. Fill those records
with this project's facts: decisions, acceptance gate, available agents, budgets, authorities, baseline and next
steps. Do not copy the reusable skill or historical lessons wholesale into the project.

For a resumed goal, read its existing `GOAL-STATE.json`, recent `DECISIONS.md`, `ALLOCATION.md` and
`AGENT-LESSONS.md`. Inspect unfinished work and results lacking `HANDLED`. Continue from actual recorded state.

## 3. Plan and route work

Split work into independently verifiable tasks with owners, dependencies and acceptance criteria. Use separate
Git worktrees/branches for independent writers; never let concurrent agents edit the same checkout. Maintain a
single owner for shared browsers, accounts and services. Preserve the user's dirty work and record the baseline.

Choose a worker using verified access, task difficulty, available quota and observed project outcomes. Reserve
strong reviewers for consequential design and high-risk changes. A model that implemented a change should not be
its only reviewer. Test a new executor on a small bounded task before entrusting it with a broad change.

Each task card must specify:

- Goal, context, worktree, exact allowed scope and prohibited changes.
- Absolute task output directory `OUT`, distinct for every task and retry.
- Acceptance criteria, required evidence and relevant baseline failures.
- Exact requested model/effort where the CLI supports them, and the assigned role.
- Permitted tools, runtime/budget limits and any existing user authority.
- Required final report, unresolved risks, changed files, test results and resource handoff.

Keep task artifacts outside the product checkout. If the worker's sandbox cannot write to `OUT`, require its full
report in the final answer; the wrapper captures it in `LAST-MESSAGE.md`. Report blocked evidence/test steps.
Do not widen permissions or relocate scratch into the product tree merely to bypass a restriction.

## 4. Dispatch a worker and arm its waiter

Fetch the selected runner and `scripts/wait-lane.sh` separately into unique temporary files. Invoke the runner
through the host's background task facility, using the arguments in `PLAYBOOK.md`. Do not run a
long wrapper in a tool that will kill its process at a short foreground timeout.

For example, after defining actual paths and supported model identifiers, start this Codex wrapper command as
a host-managed background task:

```bash
zsh "$RUNNER_TMP" "$G" "impl-area" "$WORKTREE" workspace-write "$MODEL" "$EFFORT" "$CARD" "$OUT"
```

Then start exactly one waiter for that task in the host's background completion-notification mechanism:

```bash
bash "$WAITER_TMP" "$OUT" --stall 2400 --max 21600
```

In Claude Code the documented pattern is a Bash task with `run_in_background: true`. On other hosts, first
confirm the equivalent facility exists. A detached `nohup`/`&` waiter does not itself notify an agent.
The wrapper writes `PID`; the waiter reads it when there is no `WRAPPER_PID` from the GitHub edition's launcher.

While workers run, continue coordinator work: prepare independent tasks, inspect completed changes and resolve
integration questions. Do not wake a model repeatedly just to ask whether an unchanged task has finished.
The local waiter checks at a default interval of 30 seconds; `--poll` changes it. Host notification delay is
additional. Raise the stall threshold for long quiet tests or workers that report only at the end.

If the host has no background completion notifications, use a supported foreground wait between other work or
a user-authorized fallback check. Be explicit about that limitation. Native subagents may already deliver their
own completion notification and do not need an extra waiter.

## 5. Process results and recover

Wrappers write the reply, then `EXIT_CODE`, then `FINISHED_UTC` last. Read the waiter's first line; its own exit
code is always zero and is not proof of worker success.

| Result | Coordinator action |
| --- | --- |
| `LANE DONE exit=0 output=ok` | Read the complete report and inspect its evidence and changed files |
| Nonzero exit, missing/empty output or an error signature | Diagnose the cause; resume a supported named session or retry with a new output directory |
| `LANE DIED` | Inspect the recorded process and logs; clean only owned orphan processes; recover deliberately |
| `LANE STALL` | Inspect logs, process and recent worktree changes before deciding whether it is stalled |
| `LANE TIMEOUT still-running` | The waiter reached its lifetime; re-arm it without restarting a healthy worker |

Provider quota/authentication failures apply to that provider's affected tasks. Record them, choose an authorized
fallback or explain the exact remaining user action. Do not rotate accounts or bypass access controls. Never
reuse an output directory containing old completion markers. Preserve incomplete session locks until their owner
has been verified stopped; then move the stale lock aside before a retry.

Only after reading, triaging and recording a result, create `OUT/HANDLED`. Duplicate notifications are harmless
when that marker is checked. A new task gets a new waiter; do not kill existing waiters to make room for it.
After a host interruption, reconcile the recorded PID and files before re-arming. An optional periodic sweep
can catch completed but unhandled results; it is a recovery measure, not the normal notification path.

Remove each temporary script after its process has finished. Keep only the user's task artifacts and records.

## 6. Review, integrate and report

Use an independent reviewer for each material change. Give it the actual worktree and the implementer's real
report path, plus its own new `OUT`. Read-only reviewers return complete findings in the final answer. Require
explicit file/line evidence, severity, reproduction conditions, and a completion marker where supported.
Carry unresolved findings into the next round; close them against changed code and evidence.

Directly inspect consequential code yourself: permissions, privacy, transactions, ownership, data migrations,
concurrency, billing and cross-module contracts. A passing exit code, a confident report or a screenshot alone
does not establish correctness. UI work also needs observable user-flow evidence where the environment permits.

Compare failures against the recorded baseline by test identity and failure signature, not just counts. Run
targeted checks that resolve the remaining risk, then the agreed integration gate. Do not silently weaken that
gate or redefine acceptance to make a failing build pass. Avoid unrelated broad testing with no concrete purpose.

Integrate reviewed work under the user's existing authority. Record the exact tested commit and provenance of
each merged task. Deploy only within the granted scope and use the approved release entry point. When a host
approval mechanism blocks a step, explain the specific blocked action; do not bypass or disguise it.

Give stage-level results: what works, what was tested, exact unresolved blockers, and the next action. Record
requested versus verified runtime models, task outcomes, failure modes and corrective practices in the goal's
allocation and lessons records. These are per-goal observations, not globally trained routing or benchmark data.
At goal closure, hand off retained resources and stop only processes the project owns.
