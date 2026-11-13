# Acceptance report to the user (write it in the user's language; result first)

One message per acceptance round. Lead with the one-line result, then one table row per stage, then what is running,
then what needs the user. Keep paths/ids as they are; numbers with units; mark INFERRED claims.

```
<Instance> @<sha>, acceptance <round id>: <n> of <m> stages pass; <one-line blocker or "no blockers">.

| Stage | Result | Evidence / numbers | Next |
|-------|--------|--------------------|------|
| A <name> | PASS | <e.g. refresh persists; 5/5 confirmed> | — |
| B <name> | FAIL (P1) | <exact reason code / sub-reason; where it stopped; 0 sends> | <owner session> fixing, D-<NNN> |
| C <name> | BLOCKED | <blocked by B; not run> | re-run after B |
| D <name> | NOT RUN | <why> | <when> |

Progress on the main goal: <reached>/<target> (best so far <n>, since <UTC>). Known open blockers: <all of them, one
  line each>. Replay on this build: PASS | FAIL <n>/<m> | no harness yet.
Estimate: <date — only when the replay passes on this build> | "no date yet: <what is still unknown>".
Model calls this round: <before>→<after> (<breakdown>).
Gate status: <e.g. "gate passed with 0 new failures; 37 reviewed ledger entries"> (never "green" unless it is).
Running now: <lanes, one line each>.
Needs you: <exact command(s) / decision with options>, or "nothing".
```

Rules
- PASS only for what was actually observed through the real path (refresh + read-only check for persistence).
- FAIL rows name the exact typed reason; if the system only gave a generic one, say so and say which diagnostic is
  being added.
- BLOCKED / NOT RUN are their own states; never fold them into PASS.
- If a stage FAILs on an object with unusual history, say whether a fresh-object lane proved the normal path.
