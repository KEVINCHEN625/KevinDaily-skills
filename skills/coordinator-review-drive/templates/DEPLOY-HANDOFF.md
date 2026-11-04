# Deploy pipeline + user handoff (local/test instance; only with the user's deploy authority)

Use when a guarded deploy toolkit (approve → dry-run → run-deploy → verify) deploys a candidate HEAD to a test or
acceptance instance. Record each step in one DECISIONS entry. Production is never deployed without explicit authority.

## 1. Before the toolkit
- [ ] Every lane for this candidate is merged; the candidate branch HEAD is final (`<sha>`). Merge first, rebind once:
      every later commit forces another rebind and another user command.
- [ ] Re-pins of protected expressions/files (if the project has them) are reviewed and committed.

## 2. Rebind the toolkit to HEAD (executor, offline, no live actions)
- [ ] Pin recomputed over the deployed file set (`<pin>`, `<n>` files); runtime/receipt dir named for this decision.
- [ ] Offline self-check PASS (`<passed>/<total>`); report lists every changed toolkit file.
- [ ] Coordinator reviews the rebind diff (no guard loosened, no new script paths — new actions are subcommands).

## 3. Coordinator pre-deploy steps (allowed commands, exact absolute paths, no `cd … &&` prefix)
| Step | Expected result | Got |
|------|-----------------|-----|
| self-check | PASS | |
| inspect-live | all PASS except the **expected** refusals (e.g. anonymous capability readback REFUSED by design) | |
| approve-source | sealed to `<sha>` (approved, not deployed) | |
| dry-run | source-only validated | |

## 4. Live deploy
- Run it through the single allowed guarded entry. If the auto-mode classifier blocks it: do not retry, rephrase or
  work around it. Send the user the handoff message below and keep other lanes moving.

### Handoff message (user's language; one command if at all possible)
```
<Candidate> <sha> is ready to deploy to <instance>. Pre-checks: self-check PASS, inspect-live OK (only the expected
refusal), approve-source sealed, dry-run validated. The auto-mode classifier blocked the deploy step, so please run:

  ! <exact absolute command> run-deploy

Time limit: run it within <N> min (the approval/evidence expires at <time>). Tell me "done" when it finishes;
I will verify the receipts and start acceptance. Until then the instance keeps running <old sha>.
```

## 5. Verify receipts (coordinator, after "done")
- [ ] Deployed HEAD = `<sha>`; build artifacts byte-equal to the approved source.
- [ ] Migration head = `<expected>` (or verified no-op); artifact/self tests in the receipt pass.
- [ ] Health by the real listening PID (new PID ≠ old, old exited, health 200); login smoke PASS.
- [ ] Provider/model calls during deploy = expected (usually 0).
- [ ] Integration branch fast-forwarded (`--ff-only`) to `<sha>`; GOAL-STATE environment updated.
- [ ] Dispatch acceptance lanes (one per surface) with what each verifies (decision ids).

## 6. If a guarded step refuses mid-deploy
- Do not re-run blindly. Record which phases completed. Diagnose (tool false positive vs real change) with evidence,
  e.g. comparing raw files against schema-normalized ones; fix narrowly with a RED test; add a resume subcommand
  ("continue after <refusal>") rather than re-running finished phases; then hand the user that one command.
