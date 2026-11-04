# Batch merge → verify → (deploy) → parallel retest checklist

A batch collects lane branches that each passed: RED→GREEN, second review, coordinator core review, commit.
Record each step in DECISIONS (one entry per batch, follow-ups as bullets).

## 1. Merge (coordinator; executors usually cannot write shared git metadata)
- [ ] New temporary branch from the current integration head: `<prefix>/batch-d<NNN>` @<base-sha>. Never merge into
      main/production; never force-push; no push at all unless the user authorized it.
- [ ] `git merge --no-ff` each lane branch in a written order (lowest conflict risk first). Resolve conflicts truthfully,
      keeping both sides' semantics; record every resolution (file, what was kept, why). Abort and re-plan if unsure.
- [ ] Do not fast-forward the integration branch yet.

## 2. Verify (main implementer in the batch tree; one writer)
- [ ] Full suites relevant to all merged lanes + governance/contract gates + typecheck/build + regenerated artifacts
      (API clients, manifests) checked, not hand-edited.
- [ ] Result as a node-level diff against the saved baseline log (not a rerun of pristine HEAD): key = node × phase ×
      signature; new = 0 (incl. new reason on a known node); inherited listed by node; setup/collection errors listed
      separately as NOT EXECUTED; metric budgets (size/complexity/latency) not grown; HANG / NOT RUN / SANDBOX-DENIED
      reported as such. Per-file counts or samples are not accepted as regression proof.
- [ ] Forbidden tests excluded explicitly (`--ignore=<path>`) in every broad command, including reused runner scripts.
- [ ] At RC / milestone batches: a broad canonical run (env preflight, sharded if long), not only affected subsets.
      Accepted failures only via per-node ledger entries confirmed by an independent review — never by cluster name.
      Report "gate passed with N ledger entries", never "green".
- [ ] Integration-only test fixes are reviewed by you and committed separately (test-only, no product change).
- [ ] Before heavy suites: load gate (1-min load ≤ <N>), expected duration, freeze identity, why incremental is not enough.

## 3. Sandbox-impossible checks (coordinator, natively)
- [ ] Native/listener/real-DB tests via bounded scripts (hard timeout, own process group, own temp root, cleanup trap).
      Read every rm/kill target first. A HANG is not a PASS; attribute it against the baseline before deciding.

## 4. Approve / prepare / deploy (ONLY with explicit user authority; production never without it)
Detailed steps and the user handoff message: `templates/DEPLOY-HANDOFF.md`.
- [ ] All lanes merged first; toolkit rebound once to the final HEAD (offline self-check PASS, pin/file count updated).
- [ ] Approval record binds the exact committed HEAD and decision id.
- [ ] Prepare/deploy through the guarded entry script the user allowed (e.g. one fixed `deploy-batch.sh`); keep its guards.
- [ ] Coordinator runs inspect-live (expected refusals known in advance), approve-source, dry-run.
- [ ] If the permission classifier blocks a step: do not retry or bypass. Give the user the exact ordered `!` commands
      (as few as possible, absolute paths, with time limits, e.g. evidence-expiry windows) and continue when they report
      done.
- [ ] A guarded step that refuses mid-deploy: diagnose before any retry; fix narrowly; resume via a subcommand.
- [ ] Verify receipts: HEAD, build byte-equality, migration head, health by real PID, login smoke, provider calls.
- [ ] Health checks by the real listening PID: new PID ≠ old, old PID exited, health 200, expected version/pin served.
- [ ] Back up any start/restart script you change (`.bak-before-d<NNN>`).
- [ ] Fast-forward the integration branch (`--ff-only`) to the deployed/verified head; record it.

## 5. Parallel real-page retests
- [ ] One tester session per surface, each on its own project/session/page; never two on the same account+data.
- [ ] Shared headless browser alive (supervisor running); testers told never to close/kill/restart it.
- [ ] Odd-history acceptance object → also a fresh-object lane for the normal path.
- [ ] Results reported per stage (`templates/ACCEPTANCE-REPORT.md`).
- [ ] Each retest states what it verifies (decision ids) and continues from the current state (no blind reruns that spend
      quota twice).

## 6. Resource handoff / teardown (batch is not closed until done)
- [ ] Collect every RESOURCE-HANDOFF table from the batch's lanes + your own temp roots/processes/ports.
- [ ] Produce an exact deletion list, review it, delete only provably temporary items; keep cited failing evidence.
- [ ] Record freed space and anything kept (with reason) in DECISIONS; update GOAL-STATE.batches[].resources_teardown.
