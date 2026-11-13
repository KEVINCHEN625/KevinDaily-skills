# Unstuck protocol

Read when: `goal-check.sh` prints `STUCK-CHECK STUCK`, a third fix round starts on one gate, or an estimate to the
user slipped twice. Output: one filled `templates/UNSTUCK-RECORD.md`, logged with `log-run.sh … unstuck <record>`.

## Why a coordinator gets stuck (the pattern this protocol breaks)

The loop was: page run (~40 min) → ONE blocker → fix lane → review → merge → next page run → the next blocker.
One acceptance object sat at 9 of 11 steps for more than a day; a run on a fresh object stopped at step 3 on four
new blockers. One of them, a backend RuntimeError, was in the instance log thousands of times. Five causes, each with
its counter:

| Cause | Counter |
|---|---|
| The only whole-path loop was a strict page run that stops at the first failure | a whole-path replay that continues past blockers (`RUNS.md` §2) |
| Nobody read the instance logs between runs | `scan-logs.sh` in every preflight and after every run |
| Nothing measured progress, so "9/11 since yesterday" raised no alarm | `RUNS.tsv` + `goal-check.sh` STUCK-CHECK |
| Side programs (UI rounds, a refactoring program, research) ran while the main path was blocked | TRACK main/side, WIP limit, WIP cut on STUCK |
| Each review round found one new gap (one fix took three rounds) | path matrix, exhaustive review, adversary at round 2, premise at round 3 |

## The six steps (do all, in order; stop dispatching until step 5)

### 1. All blockers at once
- Run `scan-logs.sh` over EVERY instance log (backend, worker, proxy, frontend dev server) for the whole stuck
  period: `--since <UTC of the first failed run of this goal>` (not the default window, not `--mark`). Every signature
  with a count is a row, also the ones you think are harmless.
- Add: every blocker in the `RUNS.tsv` rows of this goal, every open review finding on the main path, every
  NEED-DECISION or BLOCKED reply not yet handled, every failed request in the last page run's network capture.
- One table. For each row mark the cause CONFIRMED (you saw the failing predicate), INFERRED or UNKNOWN. An UNKNOWN
  row gets typed, content-free diagnostics at the boundary first (`RUNS.md` §5), not a guessed fix.
- Completion: every log file is named with its `LOG-SCAN` line, and no source above is missing from the table.

### 2. Forecast the rest of the path
- Write the user path to the predicate as numbered steps (e.g. for an onboarding flow: sign-up, each setup step,
  each save and its reload, the first real action, reopening the result from the home screen).
- Per step: was it ever reached on a fresh object? does the replay exercise it? which blocker class is likely there
  (the classes already seen earlier on the path repeat: stale receipt, unrecognised heading, deadlock between rules,
  oversized response)? what is the cheapest probe (one request, one unit of the replay, a grep)?
- Run the probes for the steps never reached. A step with no probe is a forecast gap; say so in the record.
- Completion: every step has a row; no step past the current blocker is "unknown, will see in the next page run".

### 3. Attack the premise
- Write the one sentence that every failed fix or failed run assumed ("the page run fails because of the step logic";
  "the proxy fix is live"; "the executor's test covers the page path").
- Find the observation that would come out differently if the sentence were false, and make it now (a `check-serving`
  line, the log histogram by endpoint, the same request replayed against a DB copy). Look at how the failures are
  distributed, not only at the latest one.
- If the evidence contradicts the premise, the cause is elsewhere: say where. If it confirms it, ask the next why.

### 4. Whole-path replay before the next page run
- Run the replay on the current batch build (`RUNS.md` §2). No harness → dispatch it as the next main lane and note
  that in the record; the next page run then needs `--no-replay "<reason>"` and a DECISIONS entry.
- Fix ALL blockers it lists (parallel lanes, one per blocker or per shared cause). Rerun until `PASS reached=target`.
  Log every replay run with `log-run.sh`.
- Only then run the page acceptance. It should confirm, not discover.

### 5. Cut WIP
- In HANDOFF.md set every side item that is not about to finish to `parked` with its resume condition.
- Assign every free executor a row of the blocker table. Class programs stay parked unless a row belongs to them.
- Completion: `goal-check.sh` prints `WIP OK` or only the main lanes as active.

### 6. Escalate
- `ESCALATE` in the STUCK line (two unstuck rounds without progress), a cause outside your authority, or a predicate
  that looks wrong for the release: tell the user. Facts with evidence, 2–3 options (for example: narrow the
  predicate, ship a step disabled, spend a stronger model, change the approach) with cost and time, and your
  recommendation. Then keep working the option that needs no new authority. Never lower the predicate yourself.
- Otherwise write "not needed" and why.

## After the record
`log-run.sh $G <goal> unstuck <record>` clears the page-run block. The 12-hour clock restarts. If the next two page
runs fail again, the protocol fires again and the STUCK line says `ESCALATE`.

Sources: pstack `principle-attack-the-premise`, `playbooks/autonomous-run.md` ("a plateau is not a stop … pivot …
surface a genuine dead end rather than spinning, and never relax the predicate"), `playbooks/bug-fix.md`; Matt
Pocock `diagnosing-bugs` (feedback loop first; 3–5 ranked falsifiable hypotheses). See `SOURCES.md`.
