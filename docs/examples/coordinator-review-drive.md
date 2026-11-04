# Example: coordinate a feature through review and verification

[Repository overview](../../README.md) · [Installation](../installation.md) · [Skill guide](../../skills/coordinator-review-drive/README.md)

This walkthrough shows how to use `coordinator-review-drive` on a small software change. It is an illustrative workflow, not a claim that these harnesses or models have been run against your project.

## Example goal

Imagine a performance-testing dashboard that needs to compare two completed test runs. The requested feature highlights changes in latency and error rate and explains when a comparison is invalid.

Acceptance criteria could be:

- A user can select two completed runs and see the values and differences for each agreed metric.
- A missing metric is shown as unavailable; it is never silently treated as zero.
- Runs from incompatible test scenarios are clearly identified before the result is presented as a regression.
- Relevant tests and a manual UI check cover the comparison behavior.

These criteria give the coordinator a bounded outcome and give reviewers something concrete to verify.

## 1. Give the coordinator the goal

After installing the skill, start with:

```text
请使用 coordinator-review-drive 担任项目主控。

目标：为性能测试看板增加两次测试结果的比较功能。
验收要求：展示约定指标和差值；缺失值不能当成 0；不兼容场景要明确提示；
验证关键计算、异常输入和界面交互。

先发现本机可用的 harness，再结合我已经提供的账号、模型和额度限制安排分工。
我希望你负责计划、审核、推进和记录；执行者负责独立任务。
先给出任务拆分和验收方案，再启动已授权的工作。
```

Supply the product repository path and any relevant existing decisions. If an action needs authority that has not been granted, the coordinator should ask about that missing action instead of assuming permission.

## 2. Create the goal records

From the root of this cloned skills repository:

```bash
CRD_SKILL_ROOT="$PWD/skills/coordinator-review-drive"
CRD_GOAL_DIR="$HOME/.local/share/kevin-daily-skills/goals/performance-comparison"

zsh "$CRD_SKILL_ROOT/scripts/init-goal.sh" \
  "$CRD_GOAL_DIR" "Compare two performance test runs"
zsh "$CRD_SKILL_ROOT/scripts/probe-agents.sh"
```

If you installed the skill elsewhere, set `CRD_SKILL_ROOT` to that installation instead. The goal directory holds working state outside the product checkout.

The coordinator fills these records as the project develops:

| Record | What belongs there |
| --- | --- |
| `DECISIONS.md` | Scope, acceptance criteria, routing decisions, and their reasons |
| `ALLOCATION.md` | Available harnesses and models, role assignments, quotas, and fallback order |
| `GOAL-STATE.json` | Current phase, active tasks, next actions, and unresolved decisions |
| `AGENT-LESSONS.md` | Observed strengths, failure patterns, and practical instructions for later tasks |

The seed lesson file provides starting guidance. Review its assumptions for the new project and record new observations with enough context to make them useful.

## 3. Allocate work by task

An example allocation might be:

| Task | Suggested role | Evidence to return |
| --- | --- | --- |
| Comparison rules and invalid-input behavior | Main implementer or design specialist | Bounded design and failing examples for the agreed behavior |
| Comparison UI | Implementer in a separate worktree | Changes within the agreed UI scope and screenshots or interaction evidence |
| Tests for the agreed rules | Executor following a precise task card | Test output, changed files, and unresolved failures |
| Independent code review | A different agent from the author | Findings tied to code and acceptance criteria |
| Integration and final acceptance | Coordinator | Resolved review findings and a verified result |

The coordinator maps these roles to the tools and models actually available. A model’s price or reputation alone does not determine the assignment. Tasks that share mutable state are serialized; independent tasks can run concurrently.

## 4. Dispatch and collect results

Each task gets a task card, an isolated worktree where needed, and a new output directory. The included wrappers record the requested settings, output, exit code, and completion time.

For a Codex lane, the command shape is:

```text
run-codex.sh <goal-dir> <session-name> <worktree> <read-only|workspace-write> <model> <effort> <task-file> <out-dir>
```

The coordinator launches the wrapper with `launch-lane.sh` and runs one `wait-lane.sh` per lane through its harness’s background-task mechanism. A waiter reports completion, a dead process, a stall, or a timeout; the coordinator reads the actual result before marking it handled. The full launch and handoff procedure is in [the playbook](../../skills/coordinator-review-drive/PLAYBOOK.md).

Use exact model identifiers confirmed for the account. A completed process is evidence that a run ended, not evidence that the requested feature is correct.

## 5. Review, integrate, and record what happened

The reviewer checks the changes against the acceptance criteria. The coordinator resolves findings, integrates accepted work, and verifies the result. Any deployment follows the authority and target established for the project.

A useful model lesson looks like this:

> In this task, the executor handled the comparison table correctly once missing values and scenario compatibility were specified in the task card. The first review found an unhandled empty result. Future tasks of this type should include an empty-result example before dispatch.

This observation explains the task, the condition for success, and the residual issue. It is more actionable than labeling a model “good at frontend” without context. The coordinator can use it when assigning the next similar task.

The final handoff should identify what changed, the evidence collected, open limitations, and the next action if the goal is not finished.

## 6. Resume later

Keep the same goal directory and ask:

```text
请继续 coordinator-review-drive 的 performance-comparison 目标。
先读取该 goal 目录里的状态、最近决策和模型经验，检查各任务的输出，
从尚未完成的下一步继续。
```

Provide the actual goal directory path. The state files help the coordinator recover the work; they do not guarantee that external CLI sessions, provider authentication, or quotas remain available. Recheck those when they have changed.
