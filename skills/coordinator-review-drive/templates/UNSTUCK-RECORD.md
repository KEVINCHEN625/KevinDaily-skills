# UNSTUCK record — <goal-id> — <UTC>

<!-- Fill every section, save as G/unstuck/<goal-id>-<UTC>.md, then:
     bash $SKILL/scripts/log-run.sh $G <goal-id> unstuck <this file>
     Procedure: references/UNSTUCK.md. Evidence is a path or a command with its output, never a summary. -->

Trigger: <fill: the STUCK-CHECK line that fired>

## 1. Blockers (all of them, from every source at once)
| # | signature | source (page run / replay / log file:count / review) | cause: CONFIRMED / INFERRED / UNKNOWN | evidence |
|---|---|---|---|---|
| 1 | <fill> | | | |

Logs read: <fill: the scan-logs.sh command and its LOG-SCAN line for every instance log>

## 2. Forecast (the rest of the path, step by step)
| step of the user path | reached before? | exercised by replay? | expected blocker / risk | cheap probe |
|---|---|---|---|---|
| <fill> | | | | |

## 3. Premise
The sentence every failed fix assumed: <fill>
The observation that would differ if it were false, and its result: <fill: command + output>

## 4. Replay
Whole-path replay command: <fill, or "none yet — harness lane <id> dispatched as the next main item">
Result: <fill: reached/target, every blocker it listed> · logged in RUNS.tsv: <yes/no>

## 5. WIP cut
Parked now: <fill: side items parked, with resume condition> · Still running on main: <fill>

## 6. Escalation
<fill: "not needed: <why>" | what was sent to the user: facts, 2–3 options with cost, the recommended one>
