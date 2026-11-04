# Second-review prompt (mandatory for EVERY fix diff; read-only reviewer, e.g. zcode GLM in plan mode)

Resolve all paths to absolute paths. Keep `<G>` outside product checkouts and choose a fresh `<OUT>` under `<G>` for
this review round, for example `<G>/STAGE-REVIEWS/SECOND-D<NNN>-<slug>/out-<round>`.
Save the prompt as `<G>/STAGE-REVIEWS/SECOND-D<NNN>-<slug>/PROMPT-<round>.md` and run:
`scripts/run-zcode-review.sh <G> <worktree> <prompt-file> <OUT> <model-label>`
The wrapper captures the review at `<OUT>/LAST-MESSAGE.md`; the reviewer does not write files.
Set `<IMPLEMENTER_REPORT>` to the prior task's actual `<OUT>/REPORT.md`, or its `<OUT>/LAST-MESSAGE.md` when report
writing was unavailable. This prior task output directory is distinct from the review's own `<OUT>`.
The verdict is advisory: the coordinator verifies every flagged point and decides. Not sufficient alone for key designs.
Never send a reviewer its own change: if this model authored the diff (e.g. trialled as executor), use a different model
(e.g. a strong subagent with the same prompt). Do not attach screenshots to reviewers whose image path leaves the machine.

---

## Template (write it in the user's language if the reviewer handles it well)

```
You are a read-only second reviewer (you cannot and must not modify any file).
Review the fix for D-<NNN> (ruling text: <G>/DECISIONS.md, section D-<NNN>; read it first).
Worktree: <worktree> (branch <branch>, uncommitted relative to <base-sha>; use `git diff <base-sha>` and `git status`
including untracked files). Implementer report: <IMPLEMENTER_REPORT> (resolved absolute path).
What the fix claims: <2–4 lines>.

Verify specifically:
1) <invariant 1 from the ruling — e.g. "the guard is not loosened; old clients behave as before">
2) <invariant 2 — e.g. "every write goes through owner/CAS/receipt; replay converges; no double charge">
3) <data-safety / privacy point — e.g. "private text never reaches public fields, logs or prompts">
4) Regressions: callers and existing test families of every touched module; tests that encode a false premise or
   inject data the production path never provides; dead seams (monkeypatched names no longer used); the same bug class
   at other entry points (name them).
5) Request-scoped / read-only fields: are they outside any seal/hash? Do write responses omit them, and if so does the
   UI carry the last read's value forward instead of treating "absent" as "allowed"?
6) Anything the report claims but the diff does not do (and vice versa).

Important: remain in the CLI's read-only permission mode and do not write any file. Complete the review in this
turn; do not stop after proposing a plan or wait for approval of that plan. Print the COMPLETE review as your final message.
List findings as P0–P3, each with file:line, the problem (concrete input/timing → consequence), CONFIRMED or INFERRED,
and a suggested fix. Say which files you did NOT read. If the output is long, split it into numbered parts and keep
going until the end. The last line must be exactly: REVIEW-END
```

## Re-review (after the implementer fixed the findings)

```
Read-only re-review of D-<NNN> round <k>. Previous findings: <previous review's LAST-MESSAGE.md path>.
The implementer's response: <IMPLEMENTER_REPORT>. Re-check each previous finding (FIXED / NOT FIXED / PARTIAL with file:line), then look for regressions the
fixes introduced. Same output rules; last line REVIEW-END.
```

## Severity guide
- P0: data loss/corruption, security/privacy breach, a guard loosened, wrong user data written.
- P1: user dead end, wrong result the user would trust, a fix that does not work on the real path, broken existing test family.
- P2: real but bounded defect, fail-open edge, misleading text, missing coverage of a claimed behaviour.
- P3: hygiene: dead code, naming, comments, small consistency issues.
