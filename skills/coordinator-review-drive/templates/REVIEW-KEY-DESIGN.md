# Key-design cross-review prompt (rationed reviewer, e.g. Codex astra; used ONLY for key designs)

Use for: security/permission constructors, transaction/ownership/concurrency designs, recovery protocols, data-model or
public-contract changes, plan-level designs, "choose between variants" rulings. NOT for conformance re-checks, fix
re-verification or spot checks (those go to the second reviewer + coordinator core review).
The coordinator reviews first, then runs the cross-review loop until PASS (one review per design version; the designer
writes DESIGN-v2.md, DESIGN-v3.md … as new files, never overwriting), then finalizes the design in DECISIONS.
If the usual cross-reviewer is unavailable (auth/quota), a strong subagent may review instead; record the substitution.

Resolve all paths to absolute paths. Keep `<G>` outside product checkouts and choose a fresh `<OUT>` under `<G>` for
each review round, for example `<G>/STAGE-REVIEWS/KEY-D<NNN>-<slug>/out-<round>`. The design and implementer evidence
paths point to the originating task's outputs, not this review's output directory.
Run read-only in the dedicated session (e.g. `<key-plans>`):
`scripts/run-codex.sh <G> <key-plans-session> <worktree> read-only <model> <effort> <prompt-file> <OUT>`
The wrapper captures the complete final review at `<OUT>/LAST-MESSAGE.md`; the reviewer does not write files.

---

## Design cross-review

```
Coordinator D-<NNN> key-design cross-review (read-only; put the complete review in your final message).
Design under review: <path to DESIGN/PROPOSAL file> (and the ruling draft in <G>/DECISIONS.md D-<NNN>).
Repository: <worktree> @<sha> — verify claims against the code, not against the document.
Coordinator's concerns: (1) <…> (2) <…> (3) is there a simpler design with the same guarantees?
Check: invariants and who enforces them (file:line); transaction boundaries and crash/replay at each boundary;
concurrency (competing actors, double submit, stale tokens); privacy/egress; backwards compatibility of stored data and
signatures; failure modes are typed and recoverable (no dead ends); test plan (RED list incl. negative and tamper cases).
First line: APPROVE / APPROVE-WITH-CHANGES / CHANGES_REQUIRED / REJECT / CHOOSE-VARIANT <A|B>.
Then numbered required changes (each with file:line evidence), then optional suggestions. ≤ <N> lines.
```

## Variant choice

```
Coordinator D-<NNN>: choose between variant A (<one line>) and B (<one line>) described in <path>, or propose a
correction. Also verify these factual assumptions in the code: <list>. First line CHOOSE-VARIANT A|B or REJECT-BOTH,
then reasons with file:line evidence and the invariants/RED tests the chosen variant must satisfy.
```

## Re-review (round k ≥ 2 of the loop)

```
Coordinator D-<NNN> key-design re-review, round <k> (read-only; complete review in your final message).
New version: <path>/DESIGN-v<k>.md. Previous versions and your reviews: <paths> (keep them side by side; do not edit).
Coordinator steer for this round: <e.g. "renames may be declared unsupported if that does not block the release">.
First re-check EVERY previous finding: CLOSED / OPEN / PARTIAL, with file:line or section evidence.
Then look for new problems the revision introduced. First line: PASS / PASS-WITH-NITS / FAIL.
Then numbered P1/P2 (each with evidence and the smallest change that would close it), then nits. ≤ <N> lines.
```

## Stop-threshold decision (a lane stopped with RED + DESIGN instead of implementing)

```
Coordinator D-<NNN> key-design decision (read-only). The implementer stopped at the card's threshold (> ~<N> lines or a
lifecycle redesign). RED: <path>. Design: <path>. Release constraints: <dates, what is already deployed>.
Choose: (a) implement the design now, or (b) ship the feature explicitly DISABLED for this release.
Verify in the code: has this feature ever worked in ANY mode/provider? What would (b) remove for real users?
For (b) specify: the shared availability helper; the typed refusal code at every entry point BEFORE any write/send
(allowlisted in the public error mapping); the availability flag in read projections (same helper); the UI disabled
before consent with reason copy; the RED kept as a strict expected-failure; and a smaller safe follow-up design
(size estimate) for the backlog. First line CHOOSE (a) | CHOOSE (b), then reasons with file:line evidence.
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
