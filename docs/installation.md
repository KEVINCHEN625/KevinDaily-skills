# Installation and requirements

[Repository overview](../README.md) · [中文介绍](../README.zh-CN.md) · [Coordinator guide](../skills/coordinator-review-drive/README.md)

## Before you install

`coordinator-review-drive` is a set of agent instructions, project templates, and local command wrappers. To execute a coordinated workflow, the coordinating agent needs access to a shell and the relevant project files. Workers run through the CLIs you already have installed and authenticated.

| Requirement | Used for |
| --- | --- |
| Node.js and npm | Installation through `npx skills`; not required for a manual copy of the skill |
| Zsh, Bash, Python 3, Perl, and Git | Bundled scripts, records, wrapper execution, and worktrees |
| Selected worker CLIs | Codex, Claude Code, ZCode, or `dsh`, according to the adapters you intend to use |
| Working provider/account configuration | Live model calls through those CLIs |
| Optional browser tools | Chrome or Chromium, `chrome-devtools-mcp`, `curl`, and `lsof` for browser-testing workflows |

Some integrations are macOS-specific. ZCode’s optional `run-zcode-test-exec.sh` uses `sandbox-exec`; its default provider path points into the ZCode macOS app bundle. The Chrome supervisor defaults to the macOS Chrome binary and accepts a different executable path. Other adapters still require their documented shells and CLI behavior. Native Windows launchers are not included.

Installing a skill does not install a harness, authenticate an account, or grant model access. Live model calls use the account and allowance configured in the selected harness.

## Install one skill with the Skills CLI

Run this from the project where you want to use the skill:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive
```

Choose the target agent when prompted. The installer reports where it placed the skill. Keep that path available for commands that need the skill’s scripts.

For a user-wide installation, add `-g`:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive -g
```

To target Claude Code explicitly:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive -a claude-code
```

To list available skills without installing:

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --list
```

See the [Skills CLI documentation](https://github.com/vercel-labs/skills) for its current runtime requirements and supported agent installation paths. Installation support is separate from the runtime compatibility of a skill’s scripts.

## Inspect the source or install manually

Clone the repository and locate the complete skill directory:

```bash
git clone https://github.com/KEVINCHEN625/KevinDaily-skills.git
cd KevinDaily-skills
CRD_SKILL_ROOT="$PWD/skills/coordinator-review-drive"
```

You can point a file-capable coordinator directly at `SKILL.md` or `PLAYBOOK.md` in this directory. For native skill discovery, copy the **whole** `coordinator-review-drive` directory into the skill location documented by your agent. For example, Claude Code supports `~/.claude/skills/coordinator-review-drive/`.

Keep `scripts/`, `templates/`, and `PLAYBOOK.md` with `SKILL.md`; copying only the entry-point file leaves required resources behind. Invoke Zsh scripts with `zsh` and the launcher/waiter scripts with `bash`, as shown below.

## Initialize a first goal

The following commands assume you are at the root of the cloned repository. If you used the installer, set `CRD_SKILL_ROOT` to the installed directory it reported instead.

```bash
CRD_SKILL_ROOT="$PWD/skills/coordinator-review-drive"
CRD_GOAL_DIR="$HOME/.local/share/kevin-daily-skills/goals/demo"

zsh "$CRD_SKILL_ROOT/scripts/init-goal.sh" "$CRD_GOAL_DIR" "Demo project"
zsh "$CRD_SKILL_ROOT/scripts/probe-agents.sh"
```

Choose a goal directory outside the product repository and outside this skills repository. The initializer creates records and working directories, preserving records that already exist. It does not call a model. The environment probe checks executable versions, configuration presence, and host capacity; it does not submit a model task or verify that a provider account works.

Next, give the coordinator your goal and acceptance criteria. Establish the usable harnesses, exact models, cost or quota limits, and authority for project actions, reusing decisions you have already supplied. The coordinator records the allocation before it launches live work.

See the [first-goal walkthrough](examples/coordinator-review-drive.md) and the [skill guide](../skills/coordinator-review-drive/README.md) for the complete operating flow.

## Included adapters

| Adapter | Script | Configuration notes |
| --- | --- | --- |
| Codex task | `run-codex.sh` | Pass model, reasoning effort, sandbox mode, worktree, and task file; named sessions can be resumed. |
| Codex browser test | `run-codex-web.sh` | Requires a running test browser and Chrome DevTools MCP configuration. |
| Claude Code task | `run-claude.sh` | Pass model and optional allowed tools; named-session reuse is optional. |
| ZCode review | `run-zcode-review.sh` | Uses review/plan mode and a report completion marker. The model label is recorded; provider configuration selects the model. |
| ZCode small edits | `run-zcode-exec.sh` | Uses edit mode by default; `guarded` is an optional mode with different execution permissions. |
| ZCode test execution | `run-zcode-test-exec.sh` | Requires macOS `sandbox-exec`; see the script header for its allowed write locations. |
| DeepSeek Harness task | `run-dsh.sh` | Pass provider, model, effort, and mode; the selected `dsh` profile must already work. |

`probe-agents.sh` also checks several common tools without providing a runner for each of them. You can add binary names to the probe invocation, but a new execution harness needs an adapter that follows the output contract in `PLAYBOOK.md`.

## Model selection and local configuration

- Use the exact model identifiers accepted by your installed harness and account. Example model names in the playbook are not a guarantee of current availability.
- `DISPATCH.json` records requested model settings. Verify the actual model using the CLI’s own output where available; Claude’s wrapper also extracts `MODEL-USAGE.txt` when returned by the CLI.
- Use `CRD_CODEX_BIN`, `CRD_CLAUDE_BIN`, `CRD_ZCODE_BIN`, or `CRD_DSH_BIN` to select a non-default executable. Use an absolute path when supplying a stub for offline checks.
- `CRD_ZCODE_PROVIDER_CONFIG` can point to an existing ZCode provider configuration. `CRD_DSH_PROFILE` selects an existing `dsh` profile. These settings do not create credentials or model entitlements.
- Quota utilities consume supplied status snapshots or local usage records; their estimates and pacing recommendations are not a provider billing guarantee.

Keep machine-specific configuration and generated project records local. Review task prompts and evidence before publishing them as examples.

## Optional browser work

Browser testing needs a dedicated test profile and a configured DevTools endpoint. `chrome-supervisor.sh` accepts the port, profile directory, and an optional browser executable. `run-codex-web.sh` accepts `CRD_BROWSER_URL`, `CRD_EVIDENCE_ROOT`, `CRD_CHROME_MCP_COMMAND`, and `CRD_CHROME_MCP_ARGS_JSON`.

Start with the [script headers](../skills/coordinator-review-drive/scripts/) and the browser sections of the [playbook](../skills/coordinator-review-drive/PLAYBOOK.md). Browser setup is optional for projects that do not need page testing.

## Updates

For an installation managed by the Skills CLI:

```bash
npx skills update coordinator-review-drive
```

For a manual copy, update the source checkout and copy the skill directory again. Keep your goal directories separate so an update does not replace project state. Review the [changelog](../CHANGELOG.md) for behavior or setup changes.
