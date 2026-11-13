# Second-review prompt (mandatory for EVERY fix diff; read-only reviewer, e.g. a second model in a plan/read-only mode)

Resolve all paths to absolute paths. Keep `<G>` outside product checkouts and choose a fresh `<OUT>` under `<G>` for
this review round, for example `<G>/STAGE-REVIEWS/SECOND-D<NNN>-<slug>/out-<round>`.
Commit the lane first with `scripts/lane-commit.sh` so the review judges one SHA. Save the prompt as
`<G>/STAGE-REVIEWS/SECOND-D<NNN>-<slug>/PROMPT-<round>.md` and launch it like every lane (card lint, own process group,
REPORT-CHECK), then arm one waiter:
`bash scripts/launch-lane.sh <OUT> zsh scripts/run-zcode-review.sh <G> <worktree> <prompt-file> <OUT> <model-label>`
The wrapper captures the review in `<OUT>`; the reviewer does not write files. The template below passes
`check-card.sh` as written; fill every `<…>`.
Set `<IMPLEMENTER_REPORT>` to the prior task's actual `<OUT>/REPORT.md`, or its `<OUT>/LAST-MESSAGE.md` when report
writing was unavailable. This prior task output directory is distinct from the review's own `<OUT>`.
The verdict is advisory: the coordinator reruns the PROOF of every P0/P1 and drops findings that do not reproduce
(recorded with the rerun output). Not sufficient alone for key designs.
Count MISSED-EARLIER findings per reviewer in ALLOCATION.md; from round 2 add an adversary lane
(`references/REVIEW-AND-GATES.md` §2.1).
Never send a reviewer its own change: if this model authored the diff (e.g. trialled as executor), use a different model
(e.g. a strong subagent with the same prompt). Do not attach screenshots to reviewers whose image path leaves the machine.

---

## Template (write it in the user's language if the reviewer handles it well; keep the keywords in English)

```
CARD: review
TRACK: main
GOAL: <the user's goal this fix serves, one line>
REVIEW-TARGET: <worktree> @ <commit sha under review>
PATH MATRIX: <copy rows M1…Mn from the fix card's DONE-EVIDENCE>
ITEMS:
I1: <invariant 1 from the ruling — e.g. "the guard is not loosened; old clients behave as before">
I2: <invariant 2 — e.g. "every write goes through owner/CAS/receipt; replay converges; no double charge">
I3: <data-safety / privacy point — e.g. "private text never reaches public fields, logs or prompts">
I4: Regressions: callers and existing test families of every touched module; tests that encode a false premise or
    inject data the production path never provides; dead seams (monkeypatched names no longer used); the same bug
    class at other entry points (name them).
I5: Request-scoped / read-only fields: are they outside any seal/hash? Do write responses omit them, and if so does the
    UI carry the last read's value forward instead of treating "absent" as "allowed"?
I6: Anything the report claims but the diff does not do (and vice versa).
(Write `TRACK: side` instead when the lane under review is a side lane.)
You are a read-only second reviewer (you cannot and must not modify any file).
Review the fix for D-<NNN> (ruling text: <G>/DECISIONS.md, section D-<NNN>; read it first).
Worktree: <worktree> (branch <branch>, commit <sha> relative to <base-sha>; use `git diff <base-sha> <sha>` and
`git status` including untracked files). Implementer report: <IMPLEMENTER_REPORT> (resolved absolute path).
What the fix claims: <2–4 lines>.

Important: remain in the CLI's read-only permission mode and do not write any file. Complete the review in this
turn; do not stop after proposing a plan or wait for approval of that plan. Print the COMPLETE review as your final message.
REPLY-CONTRACT (review form of templates/TASK-CARD.md §0) — your final message:
Start with `STATUS: APPROVE | REQUEST_CHANGES` and `GOAL: <the goal in your own words>`, then one line per item id:
`I1: done` or `I1: skip: <reason>`.
List findings as `F<n> P<0-3> <file:line> — <problem: concrete input/timing → consequence>`, each followed by
`PROOF: $ <command> → <quoted output>` or a quoted excerpt at the reviewed SHA, then a suggested fix. A claim that
something is missing (a test, a call site, a guard) needs the search command and its empty result. Anything you could
not prove by a run or a quote: leave it out, or list it under `UNPROVEN:` (not counted).
List EVERY provable issue in ONE pass. Do not stop at the first problem: after each finding go on to the next matrix
row and the next entry point. This review is judged by what a later round still finds on unchanged code.
After the findings write `COVERAGE:` and one line per matrix row and per touched entry point:
`M<n>: checked — ok` | `M<n>: checked — F<k>` | `M<n>: not checked — <reason>`. Say which files you did NOT read. If the
output is long, split it into numbered parts and keep going until the end. The last line must be exactly: REVIEW-END
```

## Re-review (after the implementer fixed the findings)

Use the same template with a new `REVIEW-TARGET` SHA and these items:

```
I1: Re-check each previous finding (<previous review's reply path>): FIXED / NOT FIXED / PARTIAL with file:line.
I2: Look for regressions the fixes introduced. A new finding on code that did not change since the previous reviewed
    SHA is tagged MISSED-EARLIER.
The implementer's response: <IMPLEMENTER_REPORT>. Same output rules (all issues in one pass, COVERAGE block);
last line REVIEW-END.
```

## Severity guide
- P0: data loss/corruption, security/privacy breach, a guard loosened, wrong user data written.
- P1: user dead end, wrong result the user would trust, a fix that does not work on the real path, broken existing test family.
- P2: real but bounded defect, fail-open edge, misleading text, missing coverage of a claimed behaviour.
- P3: hygiene: dead code, naming, comments, small consistency issues.
