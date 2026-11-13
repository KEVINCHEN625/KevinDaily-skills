# State, records, and keeping the rule set small

Read when: resuming, the context is close to compaction, writing records, or `goal-check.sh` prints `RULES OVER`.

## 1. Which file holds what (one place per fact)

| File | Holds | Write rule |
|---|---|---|
| `G/HANDOFF.md` | the present: main goal, predicate, progress, env, WIP, user directives in force, open blockers, next actions | rewritten in place, ≤ 6 KB, at every state change |
| `G/RUNS.tsv` | one row per replay / page / gate run and per unstuck record | append only, through `log-run.sh` |
| `G/DECISIONS.md` | history: numbered rulings with facts, cause, evidence | append only; grep by id, never load whole; start a new file per phase when it passes ~300 KB |
| `G/ALLOCATION.md` | the CURRENT roster, routing, fallback order, executor and reviewer track record | rewritten in place when the user changes routing |
| `G/AGENT-LESSONS.md` | lessons with `enforced by:` | pruned at phase close (§4) |
| `G/GOAL-STATE.json` | slow facts only: environment, authority, sessions, baseline, gate wording | when those change |
| out dirs | the truth about each lane (`FINISHED_UTC`, `EXIT_CODE`, reply, `HANDLED`) | by wrappers |

Lane state and "next" live in HANDOFF.md, not in GOAL-STATE.json (why: a state file once went a month without an
update while four ad-hoc resume files were written).

## 2. Handoff: surviving compaction and restarts
- Write HANDOFF.md from `templates/HANDOFF.md`. Rewrite it: after every lane hand-back, every run, every user
  directive, before any wait longer than an hour, and as soon as the context is past roughly two thirds.
- It carries what a summary loses: the user's directives in force (quoted, with decision ids), ALL open blockers,
  which waiter is armed for which out dir, and which skills the next session should load.
- Do not copy what other files hold; point to them (path, decision id, commit).
- Before a planned pause or restart: finish or back out the current atomic step, start nothing new, rewrite
  HANDOFF.md, and say in the reply what is on disk and what the first action on resume is.
- On resume: HANDOFF.md → `goal-check.sh` → out dirs of the WIP lanes (re-arm one waiter per live lane) → continue.
  The trail is authoritative: do not redo finished work. Do verify a claim you are about to build on against the real
  artifact (the serving check, the commit, the ledger row).

## 3. Records and reporting
- **DECISIONS.md** (`templates/DECISIONS.md`): numbered D-NNN, dated, in the user's language, result-first titles;
  facts / severity / root cause (CONFIRMED vs INFERRED) / ruling / dispatch / acceptance; follow-ups as `D-NNN 补充`.
- **User updates**: the user's language (agent briefs may stay English); result first; a short table per acceptance
  stage (`templates/ACCEPTANCE-REPORT.md`); what is running; what needs the user, with exact commands, or "nothing".
  Honest about hangs, NOT RUN items and inferences. Account for every lane you started: done, replaced, dropped.
- **Phase-close trail audit**: a cheap model of a different family reads the phase's DECISIONS entries and follows
  their evidence pointers, flagging weak or missing evidence, skipped verification and risky calls. The phase report
  ends with an "Attention" section (the flags, or "none").

## 4. Pruning: rules, lessons and memory must not grow without bound
Every always-loaded line costs attention on every turn, and two rules that disagree cost a wrong action.
Budgets (`goal-check.sh` → `RULES`): SKILL.md 16 KB, AGENT-LESSONS.md 24 KB, ALLOCATION.md 8 KB, HANDOFF.md 6 KB,
memory index 60 entries with none marked SUPERSEDED or DONE.

- **Supersede in place.** A changed rule replaces the old line in its one current file. Never add "UPDATE:" beside
  the old text, and never add a dated sibling ("routing-11-03", "routing-11-04", …): keep one `routing-current`
  entry and overwrite it. The old wording is already in DECISIONS.
- **Write history as history.** A dated fact ("on 11-07 the reset card was used") belongs in DECISIONS, not in a
  rule file or the memory index. A rule file says what to do now.
- **Delete what is done.** One-day modes ("free until refresh", "DONE") are removed from the index the day they end.
- **Encode, then shrink.** When a lesson gets an enforcer (script, lint, launcher refusal, test), cut its text to one
  line naming the enforcer. When the mistake can no longer happen, delete the line.
- **Find no-ops.** A rule that changed no decision in the last phase, or that restates the harness's own behaviour,
  goes. A rule followed by nobody because it is buried goes up the ladder (a check) or out.
- **When**: at every phase close and whenever `RULES OVER` prints. Method: a cheap executor proposes the merged
  file (`CARD: other`, `TRACK: side`); you review the diff; contradictions it finds are decided and recorded once.
- Memory entries are the user's: propose the prune list (delete / merge / keep) and apply what the user's standing
  rules allow; never drop a user directive that is still in force — move it to HANDOFF.md "User directives in force".

Sources: Matt Pocock `handoff`, `chief-of-staff` (wiki: "write history, not the present", "lint" for superseded
claims), `retro` (checks over rules; no-ops), `writing-for-agents` (context load, sprawl); pstack `pause-safely`,
`session-pickup`, `correct` (rule table with its enforcer; "drop a rule once its mistake can't happen"),
`show-me-your-work`. See `SOURCES.md`.
