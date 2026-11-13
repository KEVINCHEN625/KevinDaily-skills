# Review-and-Drive Coordinator — for agents that are not Claude Code

The procedure lives in ONE place: [`SKILL.md`](SKILL.md) (the loop) and [`references/`](references/) (details, each
with a "read when" trigger). Earlier versions kept a second full copy of the procedure here; it was removed in
version 2.0.0 because the two copies drifted apart.

If you were told to "read and follow PLAYBOOK.md": read `SKILL.md` now and follow it. Differences for your harness:

- **Waking up.** Claude Code is woken by a background task that exits. Without that, run
  `bash scripts/wait-lane.sh <out> --max 540` in the foreground between other work, or run the unhandled-lane sweep
  from cron (`references/DISPATCH.md` §2).
- **Subagents.** "Agent tool" lanes do not exist for you; dispatch every lane through a wrapper in `scripts/`.
- **Sandboxes** (Codex, dsh) may block starting other CLIs, writing shared git metadata, or native tests. Do not look
  for a workaround: write the exact commands for the user, or a bounded script for the coordinator.
- **Other CLIs**: wrap them like `run-dsh.sh` — sandbox and approvals on with a never-prompt approval mode (refusals
  are reported, never auto-approved), policy header prepended, retries only on upstream model/transport errors, the
  out-dir contract (`references/DISPATCH.md` §5), exact model ids, and a check of the model that actually ran.
- Shell runners use zsh/bash, quota helpers and some checks use Python and Perl. Codex, Claude and dsh take model
  arguments; ZCode's model label only records a request and its local provider configuration selects the model.
- Never run the scripts with permission-bypass flags.

To install the pointer in Codex, put this line in the repository's or the user's `AGENTS.md`:
`When asked to act as coordinator (主控/审核推进), read and follow <absolute-skill-directory>/SKILL.md; scripts are in its
scripts/ dir; never run them with bypass flags.`
