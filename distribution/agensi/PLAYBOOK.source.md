# Coordination playbook — Agensi edition

## Contents

- [Temporary resource execution](#temporary-resource-execution)
- [Goal and task state](#goal-and-task-state)
- [Runner arguments](#runner-arguments)
- [Waiters and result handling](#waiters-and-result-handling)
- [Independent review](#independent-review)
- [Integration and acceptance](#integration-and-acceptance)
- [Environment notes](#environment-notes)

## Temporary resource execution

Use Agensi's current file index. Fetch each script needed for the current task, save its complete unchanged bytes
to a distinct temporary path, and invoke its interpreter. Do not assume package siblings are on disk. Do not
install scripts or references in a project or skills folder. Do not reconstruct a cached package between sessions.

For long-running work, retain the temporary file until its process finishes. Use the host's managed background
execution, record its task identifier, and keep the coordinating session able to receive completion notifications.
There are two independently managed tasks: the worker wrapper and its waiter. Each uses its own temporary file.
Do not delete a wrapper's file just because its launch call returned. Remove script files after their process ends.

Launch the wrapper directly. It records its own `PID`; the waiter reads that when no `WRAPPER_PID` exists.
This package intentionally omits the GitHub edition's detached launcher and shared shell library. Each of the
seven model runners embeds the common functions and default policy it needs. Ordinary operating-system tools,
installed worker CLIs and user task inputs remain external prerequisites.

Do not silently change MCP server configuration, install third-party tools or grant additional model permissions.
Use task authorization and the host's normal mechanisms. If a required capability is absent, complete useful
authorized work and explain the exact missing prerequisite.

## Goal and task state

Set `G` to an absolute user goal directory outside the product repository. Run the temporary `init-goal.sh`
with `G` and an optional title. It creates directories and fresh project records without replacing existing ones.
Populate those records with this project's confirmed facts; reference templates are read through MCP as needed.

| Record | Purpose |
| --- | --- |
| `DECISIONS.md` | Decisions, evidence and changes in authority or acceptance |
| `GOAL-STATE.json` | Environment, tasks, dependencies, baseline and next actions |
| `ALLOCATION.md` | Requested and verified models, quotas, assignments and actual outcomes |
| `AGENT-LESSONS.md` | New observations from this goal; model/harness/version/date/task context |
| `LANES.txt` | Optional task-output index, particularly for the legacy list waiter |

For each task, choose an independent worktree, a brief and a fresh absolute `OUT`. Record its owner and acceptance
criteria. The prompt's output path and wrapper's output argument must match. A retry gets a different `OUT`.
The task brief must contain the constraints it needs; do not point a worker to an unavailable skill directory.

If the user has a project-specific `G/POLICY-HEADER.txt`, the runners honor it. Otherwise each uses its embedded
default policy. Do not save the reusable policy reference just to satisfy an installed-directory assumption.

## Runner arguments

Fetch the selected resource and substitute its temporary path for `RUNNER_TMP`. Use real, verified model and
effort identifiers; the placeholders below are not model recommendations. Invoke wrappers through a host-managed
background task when they may outlive a foreground tool timeout.

| Resource | Arguments after `zsh "$RUNNER_TMP"` |
| --- | --- |
| `scripts/run-codex.sh` | `G session-name cwd read-only\|workspace-write model effort prompt-file out-dir` |
| `scripts/run-codex-web.sh` | `G session-name cwd model effort prompt-file out-dir` |
| `scripts/run-claude.sh` | `G session-name\|- cwd model prompt-file out-dir [allowed-tools]` |
| `scripts/run-dsh.sh` | `G workdir task-file out-dir provider model effort [read-only\|workspace-write]` |
| `scripts/run-zcode-review.sh` | `G read-cwd prompt-file out-dir [model-label]` |
| `scripts/run-zcode-exec.sh` | `G worktree card-file out-dir [model-label]` |
| `scripts/run-zcode-test-exec.sh` | `G worktree card-file out-dir evidence-dir [model-label]` |

Use Codex read-only for reviews. Claude's default tool list is read/research only; explicitly choose any broader
tool allowance within the task's existing authority. ZCode plan mode is the supplied review path; edit mode is
for bounded changes. Its optional guarded mode does not by itself enforce filesystem write confinement.

Read a runner's header for its environment overrides. `CRD_CODEX_EXTRA` supports only `-c service_tier=<tier>`.
Claude permission mode accepts `default`, `acceptEdits`, `plan` and `dontAsk`. Do not pass permission bypass flags.
Binary overrides use `CRD_CODEX_BIN`, `CRD_CLAUDE_BIN`, `CRD_ZCODE_BIN` and `CRD_DSH_BIN`.

Codex and Claude can resume recorded named sessions where their adapter supports it. Keep one active task per
named session. A busy or incomplete session lock is not permission to delete it: verify the owner stopped and
move a stale lock aside before retrying. A provider label is not evidence of the actual runtime model.

`run-dsh.sh` retries only its recognized upstream transport/server failures, with bounded attempts. A task
failure is not automatically retried as a provider failure. Inspect logs before rerouting or repeating work.

## Waiters and result handling

After the worker has started, fetch `scripts/wait-lane.sh` and run it through the host's background notification
facility. Do not detach the waiter with ordinary `nohup` or `&` and expect it to wake the coordinator.

```bash
bash "$WAITER_TMP" "$OUT" --stall 2400 --max 21600
```

`--poll` defaults to 30 seconds. `--stall` defaults to 2400 seconds without a file change in the output directory;
increase it for quiet but healthy jobs. `--max` defaults to 21600 seconds and limits the waiter's lifetime, not
the worker's task duration. `--output` selects a custom reply file. There is one active waiter per task.

| File or signal | Meaning |
| --- | --- |
| `STARTED_UTC`, `PID`, `DISPATCH.json` | Wrapper start and requested identity metadata |
| `LAST-MESSAGE.md` / `REVIEW.md` | Worker reply; partial until the finished marker exists |
| `EXIT_CODE`, then `FINISHED_UTC` | Wrapper's final status and completion marker |
| `HANDLED` | Coordinator has read, triaged and recorded the result |
| `LANE DONE` | Check worker exit code, full reply and actual evidence |
| `LANE DIED` | Recorded wrapper process disappeared without its final marker |
| `LANE STALL` | No recent output-file activity; inspect before deciding the task is hung |
| `LANE TIMEOUT still-running` | Re-arm a waiter for the existing healthy task |

The waiter's shell exit code is always zero. Its first line carries the status. Reports can include known error
signatures and only a tail of the reply, so read the complete actual report before making an acceptance decision.

When both a wrapper and its waiter deliver host notifications, deduplicate against the actual markers and
`HANDLED`. Never mark a result handled before processing it. Re-arming against a completed output directory
simply reports completion again. Do not stop an existing waiter to add a new task.

For a non-wrapper process, use `wait-lane.sh --pid PID --log FILE --stall SECONDS`; it reports process exit,
inactivity or lifetime expiry. Use recorded process IDs, not unanchored process-name searches that can match
the waiter itself. Stop only owned processes after checking what they are.

Without host background notifications, use a supported foreground wait between coordinator work or an explicitly
authorized fallback check. An optional periodic scan for finished but unhandled outputs can recover missed reports.
After a host restart or process kill, inspect each recorded PID and its markers before restarting or re-arming.

`scripts/wait-lanes.sh` is the legacy list-based alternative. It consumes a user-authored lane index and uses
`.seen` for reporting. That marker is not proof that the coordinator handled a result. Do not combine legacy and
per-task waiters for the same tasks.

## Independent review

Review a design before broad implementation when it affects interfaces, stored data, permission boundaries or
major user workflows. Give reviewers explicit questions, constraints and evidence. Resolve or record findings
before expanding scope. Keep deliberate exclusions visible to the user.

Give the implementation reviewer the actual worktree and report path, including `LAST-MESSAGE.md` when external
report writes were blocked. Use a new review output directory. Require concrete findings with file/line evidence,
severity and reproduction conditions. An absence of findings is not enough if the review is truncated.

Track each finding through a revision and re-review. Directly examine consequential code and verify the fix.
Do not rely on the implementing model as the sole reviewer. A different session alone is not a guarantee of
independent judgment; provide the reviewer the requirements and artifacts, not a suggested verdict.

## Integration and acceptance

Preserve the recorded baseline and the exact accepted gate. Compare failing tests by identity, phase and
signature rather than only totals. Distinguish failed tests from tests that never ran. Require a reviewed
reason for a skip or exception, and keep any accepted follow-up visible.

Collect evidence on the exact candidate commit. Run the checks needed to resolve actual remaining risks; stop
optional testing once the accepted gate and relevant risks are covered. Keep worktree ownership and integration
order clear. Do not include unrelated user changes when staging or committing.

For browser work, share only resources with a clear owner, avoid concurrent interference in one account/page,
and verify actual user interactions. Follow the host's authorized browser integration. Do not substitute browser
automation or account sessions outside the user's scope.

Merge, push and deploy only within existing authorization. A deployment handoff must name the tested commit,
remaining action, evidence and any exact blocked command. Do not retry a denied action through a different route.

Report stage outcomes, evidence, unresolved issues and next actions. Record actual model/harness/task outcomes in
the goal's lessons; observations are not universal rankings. Retain or clean up processes and services according
to the user-approved handoff, checking ownership before stopping anything.

## Environment notes

- Scripts are Unix-oriented. No native Windows launcher is included.
- `run-zcode-test-exec.sh` requires macOS `sandbox-exec`; native enforcement needs verification on macOS.
- ZCode's model label is descriptive. The configured provider determines the actual model.
- Optional browser tooling has its own dependencies and platform defaults; inspect its header before using it.
- Quota helpers use local/supplied data and estimates; they are not provider billing APIs.
- Model accounts, subscriptions, permissions and credits belong to the user and are not supplied by the skill.
- Offline stub tests verify wrapper behavior; they do not prove the current live provider works in every host.
