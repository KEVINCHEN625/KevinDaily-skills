# Coordinator Review Drive — Agensi edition

A coordinating agent assigns software tasks, runs independent work in parallel, reviews evidence and preserves
project decisions and model lessons. Included worker integrations: Codex CLI, Claude Code, ZCode and dsh.

## Use through Agensi

Connect a capable agent to Agensi and load this listing. Its `SKILL.md` explains how to fetch supporting files
on demand. This edition does not require a permanent skill-folder installation: each included script is fetched
unchanged, run from a temporary file and removed after it finishes. References stay in the agent's context;
project-specific code, decisions, reports and state remain the user's work products.

Start with a request such as:

> Use Coordinator Review Drive to coordinate this project. Verify the available harnesses and models, split
> independent tasks, arrange independent reviews, and record observed model performance.
> Goal: … Acceptance criteria: … Authorized actions and budget: …

The full workflow is in `SKILL.md`, with command arguments and recovery in `PLAYBOOK.md`.

## Requirements

- A coordinating host with local shell/file access and access to the product repository.
- Zsh, Bash, Python 3, Perl, Git and ordinary Unix utilities.
- At least one supported CLI installed and authenticated using the user's own account.
- Host-managed background execution and completion notifications for unattended returns. Where unavailable,
  the documented foreground/fallback workflow applies.
- Optional browser work needs the specified browser tooling. The optional ZCode sandboxed test runner requires
  macOS `sandbox-exec`. Native Windows launchers are not included.

There is no included model subscription or credit balance. Model access, CLI flag compatibility and permissions
must be verified in the buyer's environment. ZCode's model label is metadata, not a model-selection switch.

## What this edition preserves

Bounded task cards, independent worktrees, independent review, explicit completion markers, one waiter per task,
named-session reuse where supported, and project records for decisions, state, allocation and observed lessons.
The waiter checks locally every 30 seconds by default. It reports completion, process death, inactivity and its
own lifetime limit; notification delivery depends on the coordinating host.

Shared wrapper helpers and default policy data are embedded into each runner. The initializer creates fresh
project records; it does not install the skill or copy reusable prompts. The GitHub edition's detached launcher
and shared `lib.zsh` are not included because this edition uses individual temporary scripts.

## Source and validation

Based on Kevin's public [KevinDaily-skills](https://github.com/KEVINCHEN625/KevinDaily-skills) project, initially
published at commit `247335a23e387821d5101a8278ad0e84c8fbcdf0`. The Agensi listing supplies an adapted MCP edition;
the original GitHub workflow remains separately available. It is not exclusive source code.

Offline checks use simulated CLIs. They do not establish current live-provider compatibility, prove native
macOS sandbox enforcement, or guarantee correctness, savings or results on a user's project.
