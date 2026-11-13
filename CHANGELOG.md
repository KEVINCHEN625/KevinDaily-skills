# Changelog

## 2026-11-13 — `coordinator-review-drive` 2.0.0

A redesign around one question: is the main goal getting closer to done? The entry point is now a short loop
(`SKILL.md`, about 15 KB) with details in `references/`, loaded when a stated trigger fires.

### Added
- **Main goal and WIP limit.** `HANDOFF.md` names the main goal, a checkable predicate and a progress number; every
  task card says `TRACK: main` or `TRACK: side`. At most 2 side items and 6 in total; `launch-lane.sh` refuses a side
  lane while the goal is over the limit or stuck (`WIP_OVERRIDE` records a reason).
- **Stuck detector and unstuck protocol.** `log-run.sh` keeps a run ledger (`RUNS.tsv`); `goal-check.sh` reports
  `STUCK` after two failed page runs, one blocker in three runs, or 12 hours without progress, and `ESCALATE` after
  two unstuck rounds without progress. The six-step protocol (`references/UNSTUCK.md`, `templates/UNSTUCK-RECORD.md`)
  must be logged before the next page run.
- **Replay before page runs.** `preflight-run.sh` checks the served tree, disk and load, instance-log signatures and,
  for a page run, a passing whole-path replay on the same commit. New helpers: `check-serving.sh` (which code each
  port really serves) and `scan-logs.sh` (error-signature histogram with redaction, ack file and byte-offset window).
- **Linted card and reply contract.** `check-card.sh` (run by `launch-lane.sh`) and `check-report.sh` (printed by
  `wait-lane.sh` as `REPORT-CHECK`) require a goal, done-evidence, scope, numbered items, an answer per item, commands
  with quoted output, a RED before a fix, and a proof for every review finding.
- **Exhaustive, proof-carrying reviews.** Path matrix in the card, every issue in one pass, a `COVERAGE:` block,
  `MISSED-EARLIER` findings counted per reviewer, an adversary lane from round 2.
- **One resume file.** `templates/HANDOFF.md`; `goal-check.sh` reports a missing, incomplete or stale handoff and
  rule files over their size budget.
- **Safe actions.** `lane-commit.sh` / `lane-commit-msg.sh` (exact paths, trailers last, proof that HEAD moved),
  `merge-lane.sh` (pre-merge, every check must pass, no merge during a run, wait until the new code is live),
  `kill-lane.sh` (stops exactly one lane; refuses a reused PID), `safe-rm.sh` (guarded, dry-run-first delete).
- Offline tests for the new checks and actions (`tests/test_checks.py`).

### Changed
- `launch-lane.sh` starts each lane in its own session and process group (Perl `POSIX::setsid`), lints the card and
  records `WRAPPER_START` and `CARD_PATH`. Existing refusals and exit code 2 are unchanged. **Migration:** cards need
  the §0 header of `templates/TASK-CARD.md`; set `LEGACY_CARD=1` to send an old card unchanged.
- The policy header, preambles and card templates now share one reply format: the first line is `STATUS: <keyword>`
  instead of a bare keyword, and the line caps on replies are gone.
- Review templates (`REVIEW-SECOND.md`, `REVIEW-KEY-DESIGN.md`, `WEB-TESTER-TASK.md`) are linted cards launched
  through `launch-lane.sh`; key-design verdicts move to a `VERDICT:` line.
- `PLAYBOOK.md` is now a short note for non-Claude agents; the procedure lives only in `SKILL.md` and `references/`.
- `GOAL-STATE.json` keeps slow facts only; lanes, WIP and next actions live in `HANDOFF.md`.
- `init-goal.sh` also creates `HANDOFF.md` and `unstuck/`; installation now also needs `lsof`.

### Fixed
- `wait-lane.sh` reports a missing out dir, a trailing option or a non-numeric value at once, and always exits 0.
- Offline wrapper tests resolve the temporary directory, so they also pass on macOS (`/var` → `/private/var`).

### Credits
Ideas adapted, with attribution, from [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan and
[Matt Pocock's skills](https://github.com/mattpocock/skills), both MIT licensed. Details:
`skills/coordinator-review-drive/references/SOURCES.md`; notices: `skills/coordinator-review-drive/THIRD_PARTY_NOTICES.md`.

## 2026-11-04 — Initial public collection

- Publish `coordinator-review-drive` as the first independently installable skill under `skills/`.
- Add English and Chinese repository introductions, installation guidance, a worked example and contribution guidance.
- Preserve the supplied coordination workflow, CLI adapters, review templates and author-observed lessons.
- Remove macOS archive metadata and historical backup copies from the distributable source.
- Resolve the skill location from its actual installation, remove project-specific names, and clarify implemented adapters.
- Align goal-resume instructions with the current `HANDLED` marker and correct template references.
- Use one absolute output directory per task, pass actual report paths to reviewers, and preserve full reports in final output when the harness cannot write external files.
- Add offline structure, syntax, local-link and wrapper validation, with a GitHub Actions workflow.
- Preserve valid JSON when a goal title contains quotes, backslashes or newlines.
- Prevent reused launcher output and incomplete session locks from overwriting another run.
- Correct GNU/BSD timestamp detection in lane waiters and propagate malformed/error Claude results.
- Restrict permission-override inputs, prepend the shared policy to ZCode review prompts, and check platform-specific requirements.
- Preserve existing wrapper arguments; `CRD_CODEX_EXTRA` now accepts only `-c service_tier=<tier>` and Claude permission mode accepts only `default`, `acceptEdits`, `plan` or `dontAsk`.

## Supplied skill history

- **2026-10-17:** independent review, gate comparison, quota fallback, deployment handoff and stage acceptance reports.
- **2026-10-27:** quota pacing, executor trials, process ownership and bounded browser supervision.
- **2026-11-04:** detached lane launching, one waiter per lane, explicit result markers and report handling.

These historical dates come from the uploaded skill's notes; they are not GitHub release tags.
