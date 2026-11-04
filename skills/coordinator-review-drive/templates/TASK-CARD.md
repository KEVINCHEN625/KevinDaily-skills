# Task-card templates

Save each card as <G>/lanes/<area>/TASK-<SLUG>[-N].md (never overwrite an old card: add -2, -3 …), dispatch it with
the matching wrapper into a NEW out dir, and add `<OUT> <label>` to the lane list. Cards are short and point
to files; the decision text lives in DECISIONS.md and the defect evidence in a proposal/report file.

Resolve all path placeholders before dispatch. `<G>` is the goal directory outside product checkouts; `<worktree>`
is the allocated checkout; `<OUT>` is this task's new, absolute output path under `<G>`, outside every product checkout
(for example, `<G>/lanes/<area>/out-<slug>-<attempt>`). Pass exactly `<OUT>` as the wrapper's out-dir.
Prepend this common block to every card below so it also works when dispatched on its own:

```
Paths (resolved and absolute): goal=<G>; worktree=<worktree>; output=<OUT>.
Write reports, plans, logs and scratch only under <OUT>; temporary files go under <OUT>/tmp.
If the host does not permit writing <OUT>, put the complete deliverable in your final message for capture as
<OUT>/LAST-MESSAGE.md, and report blocked evidence/test steps. Do not move outputs into the worktree or expand permissions.
Never overwrite wrapper logs/markers. Each retry or review round gets a fresh <OUT>.
Short reply limits below apply only when the deliverable was saved to a file; otherwise return it in full.
```

Writing cards: use a quoted heredoc so backticks and `$` stay literal, then fill placeholders with sed, and pass the
FILE path to the wrapper (never the text):
```
cat > "$G/lanes/<area>/TASK-<SLUG>.md" <<'EOF'
Coordinator D-__DNUM__ … `code spans` stay intact …
EOF
sed -i '' "s/__DNUM__/1234/g" "$G/lanes/<area>/TASK-<SLUG>.md"     # GNU sed: sed -i "s/…/…/g"
```

---

## A. Implementer / fix card (short form — the default)

```
Coordinator D-<NNN> (end of <G>/DECISIONS.md; lessons <a>–<b> in <G>/AGENT-LESSONS.md; preamble <G>/PREAMBLE-IMPLEMENTER.md).
Make product changes ONLY in <worktree> (branch <branch> @<base-sha>; deps symlinked; no installs; no git writes; no restarts).
Problem: <one-paragraph fact summary> — evidence: <proposal/report path>.
Required: <the decided fix, as constraints, e.g. "same owner/CAS/receipt path as manual edit; do not loosen the fence">.
Decisions already made (do not reopen; cheap executors stall on open choices): <option chosen per open question>.
Related lanes: <other lanes/commits touching this area, so you do not redo or undo them>.
Runtime cap: <N> min. Write task reports, logs and evidence ONLY under <OUT> (never inside the worktree).
Forbidden: <files/areas other lanes are editing>; weakening assertions; skip/xfail; new endpoints/migrations unless NEED-DECISION.
RED first with <real shape: real session/state/fixture, real transport chain, production constructor>.
Run: <test families of every touched module> + <governance/contract gates> + typecheck/lint; compare failures with baseline
<sha/log> by node, phase and signature. Never run <forbidden test path>; pass `--ignore=<forbidden test path>` on every
broad/family selection.
<Stop threshold (§G) if the size is uncertain.>
If the fix needs a design/permission change: write <OUT>/NEED-DECISION.md and stop.
Finish with <OUT>/REPORT.md and <OUT>/lane.diff as specified in the implementer preamble.
Cleanup (mandatory): create every temp dir/basetemp/DB/cluster/process/port/browser page/worktree under <OUT>/tmp or a
recorded root; trap-delete it on success, failure and timeout; kill only recorded PIDs; delete only what you created.
Reply ≤5 lines; first line READY-FOR-REVIEW with diff stat, or NEED-DECISION / NEED-RESTART / BLOCKED; then the
RESOURCE-HANDOFF table (<SKILL>/templates/RESOURCE-HANDOFF.md). No table = not accepted.
```

**Every card below (B–I, including web testers) carries the same Cleanup line and RESOURCE-HANDOFF table.**

## B. Plan + RED card (main implementer prepares, fast executor implements)

```
Coordinator D-<NNN>. Product code in <worktree> is read-only; edit only these RED test files: <test paths>.
Write <OUT>/PLAN.md — root cause (file:line, CONFIRMED/INFERRED), the change list down to file:function, risks, and the
RED test paths. Show those real tests failing now for the right reason; save the raw output under <OUT>.
Do not change product code. Reply ≤5 lines, first line PLAN-READY.
```
Then a fast-executor card: "Implement <PLAN path> until its RED tests are GREEN; do not edit the RED assertions; flag any
point where you had to interpret the plan." Full verification before merge is still required (fast executors tend to run
fewer tests).

## C. Root-cause / attribution card (read-only)

```
Coordinator D-<NNN>. Read-only. Attribute each failure in <log/junit paths> to exactly one of: product defect /
test-or-fixture defect / environment-or-prerequisite / timing-flake. Use the first full traceback, cite file:line, give the
minimal fix and its risk, and a single-group rerun command (with a load gate if heavy). Write <OUT>/ATTRIBUTION.md.
Reply ≤5 lines, first line REPORT.
```

## D. Script-for-the-coordinator card (sandbox-impossible steps)

```
Coordinator D-<NNN>. Your sandbox cannot <run native listeners / own a PostgreSQL cluster / write shared git metadata>.
Write a bounded script <OUT>/run-<slug>.sh that the coordinator will run outside the sandbox: hard timeout, own process group,
only loopback ports, its own temp root, always stops and deletes what it created (trap), archives old results before a
forced rerun, writes <OUT>/SUMMARY.json. No deletes outside its own root. Reply ≤5 lines, first line READY-FOR-REVIEW.
```
The coordinator reads the whole script (especially every rm/kill target) before running it.

## E. Research card (cheap model, headless, web tools)

```
Research for D-<NNN>: <question>. Search the web (and only the web). Produce <OUT>/REPORT.md with: findings grouped by
theme, each with source links, a credibility note (first-hand / second-hand / self-reported), and a short "what we could
adopt" list. Do not invent sources. First line REPORT.
```
Dispatch with run-claude.sh … <cheap-model> … "Read,WebSearch,WebFetch" and verify MODEL-USAGE.txt.

## F. Fixed-command test-runner card (cheap executor)

```
Run exactly these commands in <worktree> and save raw output under <OUT>: <cmd 1> ; <cmd 2>. Do not edit product files.
Report pass/fail/skip counts and the failing test IDs verbatim; a hang or timeout is HANG, never PASS. First line REPORT.
```

## G. Stop-threshold clause (append to any card whose size or design is uncertain)

```
If this turns out to need more than ~<400> lines of product change, a lifecycle/state-machine redesign, a migration,
or a new public contract: STOP after the RED test and a written design at <OUT>/DESIGN.md
(root cause file:line, options, line estimate per option, invariants, RED list). Do not ship a half implementation.
Reply NEED-DECISION with the RED and DESIGN paths.
```
The coordinator then runs the stop-threshold decision (templates/REVIEW-KEY-DESIGN.md): implement now, or ship the
feature explicitly disabled with a typed refusal and UI gating before consent, with the design moved to the backlog.

## H. Edit-only executor card (e.g. the reviewer model trialled as executor; sandbox cannot run python/node/git)

```
Implementation task D-<NNN>. Make product changes only in <worktree> (branch <branch>). Do NOT run git, do NOT run tests (the
coordinator runs them), do NOT call any model provider, do NOT delete files.
Decision: <ruling in 3–6 lines>. Changes (≈<N> product lines): 1) <file:area — exact change> 2) … n) tests: <RED/GREEN
to add; keep the original RED as strict xfail if the feature is disabled>.
Generated files (API clients/schemas): say which generator command the coordinator should run; do not hand-edit if a
generator exists.
Write <OUT>/REPORT.md listing every changed file with a one-line reason. Reply ≤ 8 lines.
```
Afterwards: the coordinator runs the tests (expect test-side fixes), and a DIFFERENT model reviews the diff.

## I. Broad-suite triage card (node-level, for RC / milestone gates)

```
Coordinator D-<NNN>. Run the full canonical suite at <sha> in <env> (preflight first: interpreter, DB kind, required env
vars; shard if > <N> h; exclude <forbidden path> with --ignore). Save raw logs under <OUT> and produce
<OUT>/TRIAGE-<sha>.md + <OUT>/TRIAGE-<sha>.json, a JSON table:
one row per failing/erroring node: node id, phase (collection/setup/call/teardown), signature (exception type +
normalized message/reason code), status vs baseline <log> (NEW / SAME / NEW-REASON / FIXED), never-executed flag for
setup/collection errors. Then root-cause clusters with blame (commit/date) and a risk class per cluster (permissions,
data integrity, transactions/concurrency, metering/budget, privacy, core feature, other). No per-file counts as proof,
no sampling. Do not write any ledger entries; do not call anything "green". First line REPORT.
```
