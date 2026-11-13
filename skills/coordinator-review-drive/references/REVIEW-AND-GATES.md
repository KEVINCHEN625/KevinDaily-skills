# Review, gates, batches, deploy

Read when: planning a key design, reviewing a hand-back, comparing test results, batching, or deploying.

## 1. Plan before code
- Scope + acceptance written in G (or the goal doc). Key plans: draft → cross-review → (web research of best practice
  when the area is product-shaping, via the cheap researcher) → revise → implement only after the review passes.
- **Key-design loop**: designer writes `DESIGN.md` → you review → independent cross-review → designer writes
  `DESIGN-v2.md` (never overwrite; v1/v2/v3 side by side) → re-review of the same reviewer against the previous findings
  → … until PASS. Between rounds steer scope (e.g. "declare X unsupported if that does not block the release") rather
  than letting the loop grow. When only narrow residual MUSTs remain, you may close them yourself in a written
  revision/amendment and ask the reviewer to confirm just those (saves a full designer round). Implementation starts
  only after PASS (`templates/REVIEW-KEY-DESIGN.md`). Every ruling is recorded with its reason and its evidence.
- **Simple, decoupled fixes**: target the feature behaviour with the smallest change owned by one module. When the
  right approach is unclear, run 2–3 parallel cheap research lanes and compare before deciding; before accepting a
  complex fix, ask for a simplification review, and push back on review MUSTs that add machinery without user value
  (why: patch-on-patch fixes grew counters and ledgers that a 3-part redesign later cut by ~30 %).
- **Pre-registered experiments/plans** change only through a written amendment made before any result exists (no
  rule is lowered after seeing data); drafts stay inactive until reviewed.
- **Stop thresholds** in every card whose size is uncertain: "if this needs more than ~N lines of product change or a
  lifecycle redesign, STOP after the RED and a written design" (`templates/TASK-CARD.md` §G). A stop is a success: it
  goes to a key-design review that chooses between implementing now and **shipping the feature disabled** (typed
  refusal before any write/send, availability flag in the read projection, UI disabled before consent, reason copy),
  with the full design moved to the backlog.
- Write the ruling first (DECISIONS entry), then the task card. Cards point to files; they never paste secrets.

## 2. Review pipeline (every fix, no exceptions)

1. **Second review** (`templates/REVIEW-SECOND.md`) on the uncommitted diff; it may run in parallel with a real-page
   retest when the fix is already deployed to a test instance — pause that acceptance if a P0/P1 appears. If the
   second reviewer authored the diff, a different model reviews it (`ROUTING.md` §2).
   **Proof-carrying findings** (pstack interrogate): each finding carries a PROOF (command + quoted output, or a quoted
   excerpt at REVIEW-SHA); "X is missing" carries the search command and its empty result. You rerun the proof of
   every P0/P1 before acting. A finding whose proof does not reproduce is dropped and recorded with the rerun output
   (why: a reviewer once reported two tests as missing; both were in the commit and passed). Your own review or
   green tests never replace the independent verdict; with no reviewer available the gate stays BLOCKED.
2. **Your core review** (`templates/CORE-REVIEW-CHECKLIST.md`): read the key product diffs yourself, verify each flagged
   finding against the code, recompute/rerun at least one key number, check failures against the baseline by node (§3).
3. **Key designs**: you review first, then the cross-review loop until PASS (§1, `templates/REVIEW-KEY-DESIGN.md`),
   then finalize the ruling.
4. Findings → back as a full round-N card (P0–P2 must be fixed or consciously deferred with a decision; P3s are batched
   into a pre-commit cleanup, usually for a cheap executor). Narrow follow-ups with an explicit RED may be accepted
   by you without another review round — say so in the record.
5. **Commit** on the lane branch: list everything with `git status --porcelain` (including `??`), add explicit paths,
   message names the decision; record the sha.
6. **Batch**: `templates/BATCH-VERIFY-DEPLOY-CHECKLIST.md` — temp batch branch, `--no-ff` merges in a written order,
   full verification by one executor (node-level comparison vs saved baseline, §3), your native checks,
   approve/prepare/deploy only with authority (§5), `--ff-only` the integration branch, parallel real-page retests,
   resource teardown.
7. **Runs**: replay first, page acceptance last — `RUNS.md`. Merge into an instance tree only between runs.

### 2.1 One pass finds everything (why one fix once needed three rounds, and the rule that replaces it)
Each round passed the executor's own tests, then the reviewer reported one new real-path gap. Two causes: the
executor chose its own tests, and the reviewer stopped at the first problem. From now on:
- **Path matrix before round 1.** The card's DONE-EVIDENCE lists every real path the change must hold on: entry
  points × object states × the follow-up actions a user takes next (edit → review → accept → redo → refresh). You
  write it; the executor adds a RED per row; a row it cannot cover is a `skip: <reason>` you must accept or reject.
- **Exhaustive review contract.** The review card says: "List EVERY provable issue in one pass. Do not stop at the
  first. Walk each matrix row and each touched entry point; end with a `COVERAGE:` block — one line per row:
  `checked — ok`, `checked — F<n>`, or `not checked — <reason>`." `check-report.sh` fails a review reply without the
  COVERAGE block when the card asks for one. A row marked `not checked` is not reviewed: send it to another reviewer.
- **A late finding is a miss, and misses are counted.** In a re-review, a finding on code that did not change since the
  previous round is tagged `MISSED-EARLIER`. Record misses per reviewer in the track record (`G/ALLOCATION.md`); two
  misses on one lane → swap the reviewer or add an adversary lane.
- **Adversary lane from round 2** (pstack interrogate): a different model gets the matrix and one job — break the
  change with failing tests on the real path, all rows at once, no fixes. The fixer then gets the whole failing set.
- **Round 3 is not a fix round.** Before any third fix on one gate: write the shared premise in one sentence and test
  it (`DEFECT-CLASSES.md`), and run `goal-check.sh` — a third round on the main path is a stuck trigger (`UNSTUCK.md`).

## 3. Gate integrity (do not let a gate quietly change meaning)
- **Compare by node, phase and signature**, never by per-file counts or samples: test node id × phase (collection /
  setup / call / teardown) × failure signature (exception type + normalized message/reason code). Equal per-file
  counts can hide a fixed failure plus a new one. "Same node, new reason" is a new failure.
- **Errors are not failures**: setup/collection errors mean the test body never ran. Report them separately as
  NOT EXECUTED, with the count of tests that never executed.
- **Naming a cluster is not a disposition.** Each accepted failure binds node, phase, signature, version and evidence,
  with impact, owner and deadline, and is confirmed deferrable by an independent review. No cluster or wildcard
  exemptions. Failures touching permissions, data integrity, transactions/concurrency, metering/budget, privacy or the
  release's core features are MUST-FIX, not ledger entries.
- **Watch for gate drift**: "resolve the integrated suite" slowly becoming "no new failures in this lane" is how a red
  baseline grows to hundreds of failures. Name the gate in DECISIONS and re-check it at every batch.
- **Run a broad canonical suite periodically** (each release candidate / integration milestone, not per patch):
  affected-subset testing alone hides accumulating debt from contract changes without consumer updates, receipts
  checked against moved bytes, default switches, and incomplete test environments. Preflight the environment
  (required env vars, DB kind, interpreter) so env gaps are not counted as product failures.
- **Words**: "gate passed (N accepted failures in the reviewed ledger)" is never "green". Report the real counts.
- **Real-model smoke gates**: a smoke only proves the steps it covers; its gaps hide real bugs (a broader e2e run
  found failures right after the smoke passed). Extend coverage stepwise toward the full path, with call/time limits
  derived from measured runs. Offer per-path runs (e.g. `--paths X`) so one path is retried cheaply, but only one
  all-paths PASS on the frozen SHA counts as the gate. Validate the harness's request payloads offline against the
  product's real request models before spending model calls (why: two live runs failed on harness payloads, not on
  the product). Run a minimal real-model smoke after every merge that touches a generation path.
- **A ledger-based gate** (if the user chooses one) blocks: new failures, a new reason on the same node, missing
  tests, unapproved skips; fixed entries leave the ledger; expired entries block. The ledger scheme is a key design.
- When a gate conflicts with an earlier ruling, do not pick silently: give the user 2–3 options with cost and time,
  recommend one, and keep the other lanes moving.

## 4. Test cost rules
- Small checkpoints run only the tests tied to the change (plus targeted counterexamples for concurrency/migration/
  ownership changes). No full suite per small patch.
- Freeze the candidate, then run the whole-stage matrix ONCE. After a matrix finding: first failure reason → targeted
  RED→GREEN → rerun only the lanes the new diff invalidates; list which results still bind unchanged bytes.
- Compare against saved baseline logs instead of re-running pristine HEAD (by node, phase and signature — §3).
- Before any long run write: scope, expected duration, freeze identity, why incremental is insufficient; use a load
  gate (1-minute load ≤ N); never start a duplicate matrix or contend for the same owned database.
- Incremental is the rule between milestones, not forever: a broad canonical run at each RC/milestone (§3) catches
  the debt that affected-subset runs cannot see.

## 5. Deploy pipeline (only with authority; template `templates/DEPLOY-HANDOFF.md`)
1. **Rebind the deploy toolkit to the exact HEAD** (a pin over the file set; executor does it offline): offline
   self-check passes, file count/pin updated. Approvals and pins bind one committed HEAD; any new commit → rebind.
2. Coordinator runs the read-only/preparatory steps: inspect-live (know which refusals are expected, e.g. an
   anonymous capability readback), approve-source (sealed to HEAD), dry-run (source-only validated).
3. The live deploy step: run it through the one guarded entry the user allowed. If the auto-mode classifier blocks it
   (it can, even with an allow rule), hand the user **one** ready-to-paste command; batch so the user runs as few
   commands as possible (e.g. rebind once after all merges, then deploy once).
4. **Verify receipts**: deployed HEAD, build byte-equality, migration head, health by real PID, login smoke, zero
   provider calls if none were expected. Then dispatch the acceptance lanes.
5. A guarded tool that **refuses** mid-deploy (e.g. "old deployment changed") is not retried blindly: diagnose
   (false positive vs real tamper), fix narrowly, and add a resume subcommand instead of re-running completed phases.
