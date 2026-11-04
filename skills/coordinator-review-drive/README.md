# Coordinator Review Drive

**审核推进调度中枢 — coordinate, review, and keep a software project moving.**

One coordinator discovers available local harnesses, assigns bounded tasks, reviews evidence, and keeps project
decisions and model lessons in files. Workers implement, investigate, test and pre-review in independent lanes.

The skill combines instructions, templates and CLI wrappers. Model routing is the coordinator's evidence-based
decision, using the project's records; it is not an automatic benchmark service or a trained routing model.

## Install

Install just this skill from Kevin's collection:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive
```

For manual installation, copy this **entire directory** to the skills location supported by your agent. Keep
`SKILL.md`, `PLAYBOOK.md`, `scripts/` and `templates/` together. A file-capable agent can also read the skill
directly from a local checkout.

The coordinator needs local shell/file access. Install and authenticate the worker CLIs separately; their model
access and quotas remain those of your own accounts. The script dependencies are Zsh, Bash, Python 3, Perl and Git,
plus tools required by the selected adapter. The optional ZCode test runner requires macOS `sandbox-exec`.

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

The initializer preserves existing records. The probe checks binary versions, configuration presence and host
capacity; it does not submit a model task. Keep the goal directory outside both the product and skills repositories.
Resolve missing model/account/budget information before live dispatch, reusing authorization already given.

## What is included

| Resource | Purpose |
| --- | --- |
| [SKILL.md](SKILL.md) | Agent entry point: discovery, routing, execution, review and reporting |
| [PLAYBOOK.md](PLAYBOOK.md) | Detailed procedure, completion markers, recovery and adapter extension |
| [scripts/](scripts/) | CLI runners, worktree creation, lane launching/waiting and quota helpers |
| [templates/](templates/) | Task cards, review prompts, decisions, project state and acceptance reports |
| [agents/openai.yaml](agents/openai.yaml) | Optional display metadata for compatible clients |

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
| `DECISIONS.md` | Decisions, evidence and authorization changes |
| `GOAL-STATE.json` | Current work, environment, lane state and next steps |
| `ALLOCATION.md` | Confirmed harnesses/models, role assignments, quotas, fallbacks and executor track record |
| `AGENT-LESSONS.md` | Observed strengths, failure patterns and corrective practices |

Use a model's actual outcomes to adjust future assignments. Keep observations specific to the model version,
harness, task and date. Historical examples and quota heuristics are not provider guarantees, and records are
maintained per goal rather than automatically synchronized across projects.

## Run and collect lanes

For an authorized task, create a task card and a fresh output directory. Launch its selected wrapper with
`launch-lane.sh`, then arm one `wait-lane.sh` in the coordinator's supported background-notification mechanism.
Read [PLAYBOOK §4–5](PLAYBOOK.md#4-dispatch) for the exact arguments and output contract.

`FINISHED_UTC` marks a completed wrapper run. Review `EXIT_CODE`, the actual report and worktree changes; write
`HANDLED` only after processing the result. A zero exit code alone does not establish that a change is correct.

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

See the collection's [installation guide](https://github.com/KEVINCHEN625/KevinDaily-skills/blob/main/docs/installation.md)
and [worked example](https://github.com/KEVINCHEN625/KevinDaily-skills/blob/main/docs/examples/coordinator-review-drive.md).
