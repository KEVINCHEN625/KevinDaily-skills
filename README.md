# Kevin’s Daily Skills

[English](README.md) · [简体中文](README.zh-CN.md)

Practical agent skills for the work I do every day: coordinating agents, reviewing changes, and turning project experience into reusable workflows.

Each skill lives in its own directory under `skills/` and can be installed independently. The collection starts with a coordinator for software projects and will grow as more workflows are ready to share.

## Skills

| Skill | What it does | Start here |
| --- | --- | --- |
| **`coordinator-review-drive`** | Coordinates local coding harnesses, assigns work by capability and available quota, reviews results, and records model-specific lessons for future tasks. | [Guide](skills/coordinator-review-drive/README.md) · [Example](docs/examples/coordinator-review-drive.md) |

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
- **Parallel execution:** keep independent tasks in separate worktrees, with a task card and output directory for each lane.
- **Independent review:** review implementation evidence, track unresolved findings, and reserve stronger reviewers for consequential design decisions.
- **Persistent project memory:** keep decisions, state, routing choices, and model lessons in files so work can resume across sessions.

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

## Repository organization

| Path | Purpose |
| --- | --- |
| `skills/<skill-name>/SKILL.md` | Entry point and instructions for the agent |
| `skills/<skill-name>/scripts/` | Scripts shipped with that skill |
| `skills/<skill-name>/templates/` | Project records, task cards, and review templates |
| `skills/coordinator-review-drive/PLAYBOOK.md` | Detailed coordinator procedure for file-capable agents |
| `docs/installation.md` | Installation, dependencies, and adapter coverage |
| `docs/examples/` | Walkthroughs showing how to use a skill |

Project logs, session IDs, quota snapshots, and generated goal records belong outside this repository. The coordinator uses a separate goal directory for that working state.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a skill, improve an adapter, or share a reproducible issue. Contributions should explain the task they help with and include evidence for the behavior they change.
