# Key-design cross-review prompt (rationed strong reviewer of another model family; used ONLY for key designs)

Use for: security/permission constructors, transaction/ownership/concurrency designs, recovery protocols, data-model or
public-contract changes, plan-level designs, "choose between variants" rulings. NOT for conformance re-checks, fix
re-verification or spot checks (those go to the second reviewer + coordinator core review).
The coordinator reviews first, then runs the cross-review loop until PASS (one review per design version; the designer
writes DESIGN-v2.md, DESIGN-v3.md … as new files, never overwriting), then finalizes the design in DECISIONS.
If the usual cross-reviewer is unavailable (auth/quota), a strong subagent may review instead; record the substitution.

Resolve all paths to absolute paths. Keep `<G>` outside product checkouts and choose a fresh `<OUT>` under `<G>` for
each review round, for example `<G>/STAGE-REVIEWS/KEY-D<NNN>-<slug>/out-<round>`. The design and implementer evidence
paths point to the originating task's outputs, not this review's output directory.
Run read-only in the dedicated session (e.g. `<key-plans>`), launched like every lane, with one waiter:
`bash scripts/launch-lane.sh <OUT> zsh scripts/run-codex.sh <G> <key-plans-session> <worktree> read-only <model> <effort> <prompt-file> <OUT>`
The wrapper captures the complete final review at `<OUT>/LAST-MESSAGE.md`; the reviewer does not write files.
Each prompt below passes `check-card.sh` as written (write `TRACK: side` for a side lane); fill every `<…>`.
`STATUS` is the lint's keyword; the detailed verdict goes in `VERDICT`.

---

## Design cross-review

```
CARD: review
TRACK: main
GOAL: <the user's goal this design serves, one line>
REVIEW-TARGET: <path to the design file> (repository <worktree> @ <sha>)
ITEMS:
I1: Invariants and who enforces them (file:line).
I2: Transaction boundaries and crash/replay at each boundary; concurrency (competing actors, double submit, stale tokens).
I3: Privacy/egress; backwards compatibility of stored data and signatures.
I4: Failure modes are typed and recoverable (no dead ends); the test plan (RED list incl. negative and tamper cases).
I5: Coordinator's concerns: (1) <…> (2) <…> (3) is there a simpler design with the same guarantees?
Coordinator D-<NNN> key-design cross-review (read-only; put the complete review in your final message).
Design under review: <path to DESIGN/PROPOSAL file> (and the ruling draft in <G>/DECISIONS.md D-<NNN>).
Repository: <worktree> @<sha> — verify claims against the code, not against the document.
List ALL required changes in this one pass — do not hold findings back for a later round; a required change raised
later on unchanged text counts as MISSED-EARLIER. Optional suggestions go after the findings under `SUGGESTIONS:`.
REPLY-CONTRACT (review form; keep the keywords in English) — your final message, in this order:
STATUS: APPROVE | REQUEST_CHANGES
GOAL: <the goal in your own words, one line>
VERDICT: APPROVE / APPROVE-WITH-CHANGES / CHANGES_REQUIRED / REJECT / CHOOSE-VARIANT <A|B>
I1: done | skip: <reason>   (one line per item id)
Findings: `F<n> P<0-3> <file:line or design section> — <problem>`, each followed by `PROOF: $ <command> → <quoted
output>` or a quoted excerpt; ALL of them in this one pass. Last line: REVIEW-END
```

## Variant choice

```
CARD: review
TRACK: main
GOAL: <the user's goal this design serves, one line>
REVIEW-TARGET: <path to the design file> (repository <worktree> @ <sha>)
ITEMS:
I1: Choose between variant A (<one line>) and B (<one line>) described in <path>, or propose a correction.
I2: Verify these factual assumptions in the code: <list>.
I3: Name the invariants and RED tests the chosen variant must satisfy.
Coordinator D-<NNN> variant choice (read-only; complete answer in your final message), reasons with file:line evidence.
REPLY-CONTRACT (review form; keep the keywords in English) — your final message, in this order:
STATUS: APPROVE | REQUEST_CHANGES
GOAL: <the goal in your own words, one line>
VERDICT: CHOOSE-VARIANT A | CHOOSE-VARIANT B | REJECT-BOTH
I1: done | skip: <reason>   (one line per item id)
Findings: `F<n> P<0-3> <file:line or design section> — <problem>`, each followed by `PROOF: $ <command> → <quoted
output>` or a quoted excerpt; ALL of them in this one pass. Last line: REVIEW-END
```

## Re-review (round k ≥ 2 of the loop)

```
CARD: review
TRACK: main
GOAL: <the user's goal this design serves, one line>
REVIEW-TARGET: <path to the design file> (repository <worktree> @ <sha>)
ITEMS:
I1: Re-check EVERY previous finding: CLOSED / OPEN / PARTIAL, with file:line or section evidence.
I2: Look for new problems the revision introduced; tag a finding on text unchanged since the last version MISSED-EARLIER.
Coordinator D-<NNN> key-design re-review, round <k> (read-only; complete review in your final message).
New version: <path>/DESIGN-v<k>.md. Previous versions and your reviews: <paths> (keep them side by side; do not edit).
Coordinator steer for this round: <e.g. "renames may be declared unsupported if that does not block the release">.
Each P1/P2 names the smallest change that would close it; nits go last under `NITS:`. No length limit.
REPLY-CONTRACT (review form; keep the keywords in English) — your final message, in this order:
STATUS: APPROVE | REQUEST_CHANGES
GOAL: <the goal in your own words, one line>
VERDICT: PASS / PASS-WITH-NITS / FAIL
I1: done | skip: <reason>   (one line per item id)
Findings: `F<n> P<0-3> <file:line or design section> — <problem>`, each followed by `PROOF: $ <command> → <quoted
output>` or a quoted excerpt; ALL of them in this one pass. Last line: REVIEW-END
```

## Stop-threshold decision (a lane stopped with RED + DESIGN instead of implementing)

```
CARD: review
TRACK: main
GOAL: <the user's goal this design serves, one line>
REVIEW-TARGET: <path to the design file> (repository <worktree> @ <sha>)
ITEMS:
I1: Choose (a) implement the design now, or (b) ship the feature explicitly DISABLED for this release.
I2: Verify in the code: has this feature ever worked in ANY mode/provider? What would (b) remove for real users?
I3: For (b), specify every part listed below.
Coordinator D-<NNN> key-design decision (read-only). The implementer stopped at the card's threshold (> ~<N> lines or a
lifecycle redesign). RED: <path>. Design: <path>. Release constraints: <dates, what is already deployed>.
Choose: (a) implement the design now, or (b) ship the feature explicitly DISABLED for this release.
Verify in the code: has this feature ever worked in ANY mode/provider? What would (b) remove for real users?
For (b) specify: the shared availability helper; the typed refusal code at every entry point BEFORE any write/send
(allowlisted in the public error mapping); the availability flag in read projections (same helper); the UI disabled
before consent with reason copy; the RED kept as a strict expected-failure; and a smaller safe follow-up design
(size estimate) for the backlog. Give reasons with file:line evidence.
REPLY-CONTRACT (review form; keep the keywords in English) — your final message, in this order:
STATUS: APPROVE | REQUEST_CHANGES
GOAL: <the goal in your own words, one line>
VERDICT: CHOOSE (a) | CHOOSE (b)
I1: done | skip: <reason>   (one line per item id)
Findings: `F<n> P<0-3> <file:line or design section> — <problem>`, each followed by `PROOF: $ <command> → <quoted
output>` or a quoted excerpt; ALL of them in this one pass. Last line: REVIEW-END
```

## After the review
- Record each round as a DECISIONS entry: "D-<NNN> <reviewer> review of <design> v<k>: PASS | FAIL (<n> P1s)" with what
  closed since the previous version and what remains; the final one adopts the verdict with the constraints.
- Between rounds steer scope so the loop converges (cut optional features, pin open questions to defaults, split a
  follow-up design). If the same P1 survives two rounds, narrow the design or arbitrate yourself with evidence;
  escalate to a stronger designer if the designer cannot close it.
- Implementation of an approved key design still goes: RED first → second review → coordinator core review → commit.
- Example (one release): a failure-ledger gate design went v1 FAIL (5 P1) → v2 FAIL (3 P1) → v3 with a coordinator
  steer; the deploy and acceptance lanes kept running in parallel the whole time.
