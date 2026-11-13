# Authority, safety, resource reclaim (full text)

Read when: an action touches authority, secrets, deletion, shared instances, or test resources. The seven hard
rules in SKILL.md §6 are the summary; this file is the complete list.

## 1. Decide within the rules; ask only for genuinely new authority

- Decide design/policy/lifecycle questions yourself: write the plan, get the appropriate review (cross-review for key
  designs), pick the option that is most conservative toward already-approved rules and best for the project, record
  the reasoning and its evidence (tests, measurements, review verdicts, sources; measured vs inferred). Do not
  interrupt the user with design questions. Approve directly anything that advances the goal and follows an earlier
  recorded decision (cite it); drop work with no evidenced benefit.
- Ask the user only for: push/merge to main/deploy beyond what was granted, real providers or spending beyond limits,
  widened permissions, user data handling, stopping the run, or a real change to what the product must do.
- When the Claude Code permission classifier blocks an action: never retry, rephrase or work around it. Give the exact
  ready-to-paste `!` commands (ordered, with time limits, as few as possible) or ask once for an allow rule on one
  fixed, guarded entry script whose new actions are added as subcommands; continue when the user reports done.
  Meanwhile keep the other lanes moving.
- Narrowing a safety guard or updating its checked value is a user-level security decision: on a guard false positive,
  stop and give the user the options and commands; do not edit first and explain later.
- Before blocking on "the user must enter a key/account", check the recorded environment and memory: test accounts and
  provider bindings are often already configured.
- User instructions about how to work become their own DECISIONS entry with the user's words quoted, and they win
  over this skill.

## 2. Safety rules (non-negotiable)

- Never `git add -A` / `git add .`; protect dirty trees (never stash/reset/checkout over someone's uncommitted work;
  use your own worktree); never force-push; never push, merge to main or deploy to production without explicit user
  authorization; never `--dangerously-bypass*`, `danger-full-access`, yolo modes or `--dangerously-skip-permissions`.
- Never read, print or forward secrets, tokens, auth/session files or .env files (pass paths, not contents; testers may
  read a test-account file only to fill a login form). Real user data and private documents are never uploaded; use synthetic data.
  Contributor/training-tier model sessions never see private fixtures, evidence dirs or imported user text.
  Screenshots go only to reviewers whose image path stays local (some CLIs upload images to an external host).
- Diagnostics added for live failures are **content-free**: fixed sub-reason codes and same-family identifiers
  (row id, attempt number, token counts, finish reason), never provider prompts/responses, user text or secrets.
- No SQL resets/backfills to "fix" state or counters; use the product's real, audited paths.
- **No computed-path deletes.** Never hand a deleting command (`rm -rf`, a cleanup script, `git worktree remove`,
  `git clean`) a path built from a variable or a command substitution. Delete through
  `safe-rm.sh <root> <path…>` (dry run by default; refuses an empty path, the root itself, anything outside the
  root, symlinks, and dirs holding lane work files), or write `${var:?}` and print the resolved target first
  (why: an empty `$P` once turned `$U/$P` into the lane root and `rm -rf` deleted a whole folder of lane work).
- Stop one lane only with `kill-lane.sh <out>`; never `kill -<pgid>` by hand.
- Never relabel failures, skips, hangs or sandbox denials as PASS; never weaken or delete assertions, add skip/xfail or
  loosen a guard to get green; RED first; tests use production-shaped inputs.
- One writer per worktree when schema/test collection is affected; never reuse an out dir; one task per named session.
- Test resources must be reclaimed after every test — see §3 below. Disk cleanup beyond that only on explicit user request.
- Executors never call paid reviewers or other agents themselves (policy header enforces it).
- **Live runs get their own tree**: a long live run (e2e, experiment, smoke) serves from a dedicated detached worktree
  at its pinned SHA; never commit into or edit a tree that serves a live run (why: an autoreload on a commit reset
  in-flight requests and was mislabelled as a product failure).
- **Prove what is serving** before every test run (`preflight-run.sh`, see `RUNS.md`) and after every merge into an
  instance tree and every restart:
  `check-serving.sh <instance-tree> <ports…>` → each port's PID, cwd and start time vs the tree's last HEAD update.
  `OUTSIDE-TREE` = restart it from the tree; `STARTED-BEFORE-HEAD` = restart unless the merge did not touch its code.
  A page test on stale code wastes the run (why: a dev proxy served another tree's code for days, so a merged
  proxy fix was never live). Test evidence quotes the summary line plus every failing id; `| tail -1` and
  your own `echo` prove nothing. Gates that require a clean tree are blocked by
  anything written into it, so review/audit agents and harnesses write docs, logs and run output **outside** product
  worktrees (or into an ignored folder the clean check excludes).
- **Coordinator session**: do not switch your own session into a worktree while subagents run (some harnesses then
  confine every subagent's shell to it); use lane worktrees and write coordinator files to G.
- **Host capacity**: at most 2–3 heavy jobs at once (parallel test runs, executor lanes, builds, deploys), one
  browser tester at a time on the single supervised browser; check free memory/load before each wave; never deploy
  while a broad suite runs (why: stacked browsers caused an OOM whose reaper killed every lane; a deploy under load
  56 timed out and took the instance down).

## 3. Test resource reclaim (MANDATORY — a lane or batch is not done until this is done)
Everything a test creates must be removed when that test ends, pass or fail. Leftovers fill the disk, hold ports,
keep stale processes serving old code and make the next run lie.
- **What counts:** temp dirs and pytest `--basetemp` roots, test/SQLite DBs and DB copies, owned PostgreSQL clusters
  and their data dirs, started processes (backend/worker/frontend/browser/driver) and their ports, browser tabs/pages
  and browser profiles opened for the test, test projects/accounts created in an instance, scratch worktrees/branches,
  snapshot/verify worktrees, downloaded fixtures, large logs/artifacts that are not evidence.
- **Executor duty (put it in every card):** create everything under one own root (e.g. `<out>/tmp` or a `mktemp -d`
  root); use a `trap` so stop+delete happens on success, failure and timeout; kill by recorded PID/process group, never
  by name pattern; delete only paths it created. It ends its reply with a `RESOURCE-HANDOFF` table
  (`templates/RESOURCE-HANDOFF.md`): every resource created, its state (removed / kept-as-evidence / kept-running-on-
  purpose / could-not-remove + why), exact path/PID/port. A sandboxed executor that cannot remove something lists it
  as `needs-coordinator` with the exact command.
- **Coordinator duty:** no handoff table → reply not accepted (send it back). After each lane, check the table against
  reality (`ls` the paths, `lsof -i :<port>`, `ps -p <pid>`, `git worktree list`) and remove what was left, from the exact
  list only (read every rm/kill target first; never wildcard outside the lane root; never touch shared/user dirs,
  long-lived instances the goal still needs, or anything not created by the lane). Evidence that must be kept is moved
  into `<out>/evidence/`, small, and named in the report. At batch close and at goal close, do a final sweep of the
  goal's own roots and record the result in DECISIONS (what was removed, what was kept and why).
- Long-lived shared instances (the acceptance instance, the stage instance) are not test leftovers; they are listed in
  GOAL-STATE `environment` and torn down only at goal close or on user request.

## Updating scripts that may be running
Never overwrite a script in place while a process may be executing it (bash reads the file as it runs; a waiter once died with a syntax error at a random line). Copy to `<name>.new` in the same directory, then `mv` it over the old name (atomic; running processes keep the old inode). `rsync` already does this; `cp` does not.
