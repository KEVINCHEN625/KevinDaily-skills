# Coordinator Review Drive

**审核推进调度中枢 — coordinate, review, and keep a software project moving.**

One coordinator drives **one main goal to a checkable end state**. It discovers available local harnesses, assigns
bounded tasks, reviews evidence, notices when it is stuck, and keeps project state in files that survive context
compaction. Workers implement, investigate, test and pre-review in independent lanes.

The skill combines instructions, templates and CLI wrappers. Model routing is the coordinator's evidence-based
decision, using the project's records; it is not an automatic benchmark service or a trained routing model.

## Install

Install just this skill from Kevin's collection:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive
```

For manual installation, copy this **entire directory** to the skills location supported by your agent. Keep
`SKILL.md`, `references/`, `scripts/`, `templates/` and `PLAYBOOK.md` together. A file-capable agent can also read the skill
directly from a local checkout.

The coordinator needs local shell/file access. Install and authenticate the worker CLIs separately; their model
access and quotas remain those of your own accounts. The script dependencies are Zsh, Bash, Python 3, Perl, Git and
`lsof`, plus tools required by the selected adapter. The optional ZCode test runner requires macOS `sandbox-exec`.

## Start a goal

Ask your coordinating agent:

```text
使用 coordinator-review-drive 作为这个项目的审核推进调度中枢。
先检查本机可用的 harness，并根据已经确认的模型、额度和权限完成分工。
把独立任务拆成并行工作区，安排独立审核，记录每个模型的实际表现。
目标和验收标准：<填写本次项目目标与验收标准>。
```

To prepare the goal records manually, set the first path to this installed directory:

```bash
CRD_SKILL_ROOT="/absolute/path/to/coordinator-review-drive"
CRD_GOAL_DIR="$HOME/.local/share/kevin-daily-skills/goals/my-first-goal"

zsh "$CRD_SKILL_ROOT/scripts/init-goal.sh" "$CRD_GOAL_DIR" "My first coordinated goal"
zsh "$CRD_SKILL_ROOT/scripts/probe-agents.sh"
```

Then fill `HANDOFF.md` in the goal directory (main goal, its checkable predicate, progress, environment, next
actions) and run the wake-up check:

```bash
bash "$CRD_SKILL_ROOT/scripts/goal-check.sh" "$CRD_GOAL_DIR"
```

The initializer preserves existing records. The probe checks binary versions, configuration presence and host
capacity; it does not submit a model task. Keep the goal directory outside both the product and skills repositories.
Resolve missing model/account/budget information before live dispatch, reusing authorization already given.

## What is included

| Resource | Purpose |
| --- | --- |
| [SKILL.md](SKILL.md) | The loop: wake-up routine, main goal and WIP limit, unit loop, runs, stuck protocol, trusted reviews, hard rules |
| [references/](references/) | Details loaded on a trigger: unstuck protocol, runs and replay, dispatch, review and gates, routing, safety, state, scripts, sources |
| [PLAYBOOK.md](PLAYBOOK.md) | Short note for agents that are not Claude Code (waking up, adapters for other CLIs) |
| [scripts/](scripts/) | CLI runners, checks that print a verdict line, guarded actions, lane launching/waiting and quota helpers |
| [templates/](templates/) | HANDOFF and unstuck records, task cards, review prompts, decisions, project state and acceptance reports |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | MIT notices for the adapted ideas (pstack, Matt Pocock's skills) |
| [agents/openai.yaml](agents/openai.yaml) | Optional display metadata for compatible clients |

### What keeps the coordinator honest

| Mechanism | Script or template | What it prevents |
| --- | --- | --- |
| Wake-up check | `goal-check.sh` | a stale or incomplete `HANDOFF.md`, too much side work (WIP limit: 2 side, 6 total, main never idle), rule files growing without bound |
| Stuck detector + unstuck protocol | `goal-check.sh`, `log-run.sh` (`RUNS.tsv`), `templates/UNSTUCK-RECORD.md` | spinning on one blocker: two failed page runs, one blocker in three runs, or no progress for 12 hours forces a six-step protocol (all blockers at once, path forecast, premise test, replay, WIP cut, escalation) |
| Replay before page run | `preflight-run.sh`, `scan-logs.sh`, `check-serving.sh` | page runs that find one blocker each, tests against code that is not actually serving, unread instance logs |
| Linted card and reply contract | `check-card.sh` (in `launch-lane.sh`), `check-report.sh` (in `wait-lane.sh`) | unscoped cards, skipped items, claims without command output, findings without proof |
| Proof-carrying, exhaustive review | `templates/REVIEW-SECOND.md`, `REVIEW-KEY-DESIGN.md` | one new finding per round: a path matrix, every issue in one pass, a `COVERAGE:` block, `MISSED-EARLIER` counted per reviewer |
| Safe actions | `lane-commit.sh`, `merge-lane.sh`, `kill-lane.sh`, `safe-rm.sh` | commits that never happened, merges on a failed check or under a running test, killing sibling lanes, deleting a computed or empty path |

### CLI adapters

| Harness | Included scripts | Scope |
| --- | --- | --- |
| Codex CLI | `run-codex.sh`, `run-codex-web.sh` | Model/effort arguments, named-session reuse, optional browser work |
| Claude Code | `run-claude.sh` | Headless tasks, optional session reuse, actual usage metadata when provided |
| ZCode | `run-zcode-review.sh`, `run-zcode-exec.sh`, `run-zcode-test-exec.sh` | Read-only review, small edits, optional macOS test execution |
| DeepSeek Harness (`dsh`) | `run-dsh.sh` | Provider/model arguments, profile selection and bounded upstream-error retries |

For ZCode, `model-label` is descriptive metadata, **not a model-selection switch**. The locally configured provider
determines the runtime model. Verify actual model usage before using the label as evidence. The app-server client
mentioned in historical notes is not bundled.

Discovery can inspect additional binaries, but a newly discovered harness needs its own supported invocation or
adapter. Check CLI versions and behavior before live use. Browser integration defaults include macOS paths;
override those for a compatible installation. Native Windows launchers are not included.

### Project memory and model lessons

| Generated record | What to record |
| --- | --- |
| `HANDOFF.md` | The present: main goal, predicate, progress, WIP, user directives in force, open blockers, next actions (the only resume file) |
| `RUNS.tsv` | One row per replay, page or gate run and per unstuck record (written by `log-run.sh`) |
| `DECISIONS.md` | Decisions, evidence and authorization changes (append-only history) |
| `GOAL-STATE.json` | Slow facts: environment, authority, sessions, baseline and gate wording |
| `ALLOCATION.md` | Confirmed harnesses/models, role assignments, quotas, fallbacks and executor track record |
| `AGENT-LESSONS.md` | Observed strengths, failure patterns and corrective practices |

Use a model's actual outcomes to adjust future assignments. Keep observations specific to the model version,
harness, task and date. Historical examples and quota heuristics are not provider guarantees, and records are
maintained per goal rather than automatically synchronized across projects.

## Run and collect lanes

For an authorized task, write a task card from `templates/TASK-CARD.md` (its header — `CARD`, `TRACK`, `GOAL`,
`DONE-EVIDENCE`, `SCOPE`, `FORBIDDEN`, `ITEMS`, `REPLY-CONTRACT` — is linted) and pick a fresh output directory.
Launch the selected wrapper with `launch-lane.sh`; it refuses a failing card or a used directory and starts the lane
in its own process group. Then arm one `wait-lane.sh` in the coordinator's background-notification mechanism. Read
[references/DISPATCH.md](references/DISPATCH.md) for the exact arguments and output contract.

`FINISHED_UTC` marks a completed wrapper run. The waiter's first line is the verdict and its second line the
`REPORT-CHECK` of the reply. Review `EXIT_CODE`, the actual report and worktree changes; write `HANDLED` only after
processing the result. A zero exit code or a `REPORT-CHECK PASS` alone does not establish that a change is correct.

If a named session has a stale or incomplete lock, first verify that its owner has stopped, then move the lock
aside before retrying. Wrappers preserve existing locks to avoid interrupting a concurrent run.

## Local configuration and offline checks

- Set `CRD_CODEX_BIN`, `CRD_CLAUDE_BIN`, `CRD_ZCODE_BIN` or `CRD_DSH_BIN` to an absolute executable path for an
  alternate installation or an offline stub.
- Each script header documents its arguments and supported environment settings.
- `quota-pace.py` uses supplied quota information; `claude-quota.py` estimates usage from local usage records
  and a calibration window. Neither is an authoritative provider billing API.
- The policy header instructs workers; actual permission enforcement depends on the harness and operating
  environment. Use the documented permission modes and verify the installed CLI's behavior.

Ideas in version 2.0.0 are adapted, with attribution, from [pstack](https://github.com/cursor/plugins/tree/main/pstack)
by Lauren Tan and [Matt Pocock's skills](https://github.com/mattpocock/skills), both MIT; see
[references/SOURCES.md](references/SOURCES.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

See the collection's [installation guide](https://github.com/KEVINCHEN625/KevinDaily-skills/blob/main/docs/installation.md)
and [worked example](https://github.com/KEVINCHEN625/KevinDaily-skills/blob/main/docs/examples/coordinator-review-drive.md).
