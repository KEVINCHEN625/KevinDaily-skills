# Kevin’s Daily Skills

[English](README.md) · [简体中文](README.zh-CN.md)

Practical agent skills for the work I do every day: coordinating agents, reviewing changes, and turning project experience into reusable workflows.

Each skill lives in its own directory under `skills/` and can be installed independently. The collection starts with a coordinator for software projects and will grow as more workflows are ready to share.

## Skills

| Skill | What it does | Start here |
| --- | --- | --- |
| **`coordinator-review-drive`** | Drives one main goal to a checkable end state through local coding harnesses: assigns work by capability and quota, reviews results with proof, detects when progress is stuck, and records lessons for future tasks. | [Guide](skills/coordinator-review-drive/README.md) · [Example](docs/examples/coordinator-review-drive.md) |

## Install a skill

Using the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive
```

To inspect the available skills first:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --list
```

The installer lets you choose a target agent. See [installation and requirements](docs/installation.md) for global installation, manual setup, and platform details.

## Meet the first skill

**Coordinator Review Drive — 审核推进调度中枢** gives one agent a structured way to lead a project while other agents implement, investigate, test, and review.

It combines:

- **Environment discovery:** check common local CLI binaries, versions, and configuration presence before assigning work.
- **Task routing:** choose a harness and model for each role using confirmed availability, task requirements, quota, and previous results.
- **One main goal, limited work in progress:** every task is on the main track or a side track; at most two side items and six in total run at once, and the main track is never idle while side work runs.
- **Parallel execution:** keep independent tasks in separate worktrees, with a linted task card and output directory for each lane; each lane runs in its own process group with one waiter.
- **Stuck detector and unstuck protocol:** a run ledger notices two failed page runs, a blocker that keeps returning, or a goal that has not advanced for 12 hours, and forces a six-step protocol before the next page run: collect all blockers at once, forecast the rest of the path, test the shared premise, replay, cut side work, escalate with options.
- **Replay before page runs:** a cheap whole-path replay finds every blocker first; a preflight proves which code is serving, reads the instance logs, and refuses a page run without a passing replay.
- **Reports you can trust:** task cards and replies follow a linted contract (every item answered, commands with quoted output, RED before a fix); reviews carry a proof for each finding, cover every row of a path matrix in one pass, and count findings missed earlier.
- **Safe actions:** helpers to commit and prove the commit happened, merge only when every check passes and no test is running, stop exactly one lane, and delete computed paths only inside a guarded root.
- **Persistent project memory:** one `HANDOFF.md` resume file plus decisions, run ledger, routing choices, and model lessons, so work survives context compaction and new sessions.

Try a request such as:

```text
Use coordinator-review-drive to coordinate this project.
Goal: implement the agreed feature and verify it against its acceptance criteria.
First check the available harnesses, establish the model assignments and budget,
then split independent work into lanes. Review changes before integration and
record what each model did well or struggled with.
```

The skill provides instructions and runnable adapters. It needs a coordinator that can read files and execute local shell commands, plus the worker CLIs and accounts you choose to use. Installing the skill does not install those CLIs or provide their subscriptions.

### Harness coverage

| Harness | Included adapter |
| --- | --- |
| Codex CLI | Task execution with named-session reuse; optional browser-testing runner |
| Claude Code | Headless tasks with optional named-session reuse |
| ZCode | Review, small-edit execution, and a macOS-specific test runner |
| DeepSeek Harness (`dsh`) | Headless tasks with provider/model configuration and bounded upstream-error retries |
| Other harnesses | Discovery can check additional binaries; execution needs a compatible adapter |

Finding a binary does not establish that its account, selected model, or every CLI option works. The workflow confirms those details before live dispatch. Model lessons are observations from project work, not universal model rankings or model training.

Version 2.0.0 adapts ideas, with attribution, from [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan and [Matt Pocock's skills](https://github.com/mattpocock/skills), both MIT licensed. See the skill's [sources](skills/coordinator-review-drive/references/SOURCES.md) and [third-party notices](skills/coordinator-review-drive/THIRD_PARTY_NOTICES.md).

## Repository organization

| Path | Purpose |
| --- | --- |
| `skills/<skill-name>/SKILL.md` | Entry point and instructions for the agent |
| `skills/<skill-name>/scripts/` | Scripts shipped with that skill |
| `skills/<skill-name>/templates/` | Project records, task cards, and review templates |
| `skills/<skill-name>/references/` | Detailed procedures the agent reads when a stated trigger fires |
| `skills/coordinator-review-drive/PLAYBOOK.md` | Short note for agents that are not Claude Code |
| `docs/installation.md` | Installation, dependencies, and adapter coverage |
| `docs/examples/` | Walkthroughs showing how to use a skill |

Project logs, session IDs, quota snapshots, and generated goal records belong outside this repository. The coordinator uses a separate goal directory for that working state.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a skill, improve an adapter, or share a reproducible issue. Contributions should explain the task they help with and include evidence for the behavior they change.
