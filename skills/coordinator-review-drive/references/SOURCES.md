# Sources and attribution

Two public skill collections were read as data (nothing installed or executed) and ideas, plus a few short rule
wordings, were adapted with attribution. Both are MIT licensed; their copyright and permission notices are in
[`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

- **pstack** by Lauren Tan (poteto), MIT — <https://github.com/cursor/plugins/tree/main/pstack> (a Claude Code port
  exists: <https://github.com/michael-denyer/pstack-claude>, MIT).
- **Matt Pocock's skills**, MIT — <https://github.com/mattpocock/skills>.

No file of either repository is copied into this skill.

Paths below are relative to each repository.

| Idea in this skill | Where it is here | Source |
|---|---|---|
| One main goal with a checkable predicate; a plateau means pivot, not stop; never relax the predicate; surface a real dead end | SKILL §1, §4; `UNSTUCK.md` | pstack `skills/poteto-mode/playbooks/autonomous-run.md` |
| Run ledger: one row per iteration with an evidence pointer and the predicate state | `log-run.sh`, `RUNS.tsv` | pstack `skills/show-me-your-work/SKILL.md` |
| Attack the premise after two failed fixes | SKILL §4 step 3; `UNSTUCK.md` §3 | pstack `skills/principle-attack-the-premise/SKILL.md` |
| A fast, red-capable, agent-runnable feedback loop comes before any hypothesis; replay a captured trace; several ranked falsifiable hypotheses | whole-path replay, `RUNS.md` §2; `UNSTUCK.md` §2 | Matt Pocock `skills/engineering/diagnosing-bugs/SKILL.md` |
| Give agents the logs ("information access"); prefer an automated check over a written rule; remove no-op rules | `scan-logs.sh`, `preflight-run.sh`; `STATE.md` §4 | Matt Pocock `skills/engineering/retro/SKILL.md` |
| Check the real thing, not a proxy; check process liveness directly; script the check and keep its output as a rerunnable artifact | `check-serving.sh`, `preflight-run.sh`, SKILL §5 | pstack `skills/principle-prove-it-works/SKILL.md` (the wordings "truncated output proves nothing" and "a same-SHA restart lets old code report the new commit" are in the Claude Code port's copy of that file) |
| Kickoff names goal, done-evidence, write scope, forbidden actions; start with one unit; retry by cause; account for every worker | SKILL §2; `DISPATCH.md` | pstack `skills/poteto-mode/playbooks/orchestrate.md` |
| A verifier that is not the author, on another model family; a verdict covers one head SHA | SKILL §5, §6 rule 5 | pstack `playbooks/orchestrate.md` |
| A finding survives only when a run proves it; adversaries whose job is to break the change | proof-carrying findings; round-2 adversary lane, `REVIEW-AND-GATES.md` §2.1 | pstack `skills/interrogate/SKILL.md` |
| Review along separate axes against the spec: missing, not asked for, implemented but wrong; pin the fixed point | exhaustive review + COVERAGE per path-matrix row | Matt Pocock `skills/engineering/code-review/SKILL.md` |
| Completion criteria that are checkable and exhaustive ("every … accounted for") force thorough work | COVERAGE block; completion lines in `UNSTUCK.md` | Matt Pocock `skills/productivity/writing-for-agents/SKILL.md` |
| Behavioural briefs with complete acceptance criteria and explicit scope boundaries | card header, path matrix | Matt Pocock `skills/engineering/triage/AGENT-BRIEF.md` |
| Fresh agent per round with consolidated scope; interrupt-chained resumes drop directives | round-N full cards | pstack `skills/poteto-mode/SKILL.md` (Subagents) |
| Handoff document: reference other artifacts instead of copying, name the skills to load, redact secrets | `templates/HANDOFF.md`, `STATE.md` §2 | Matt Pocock `skills/productivity/handoff/SKILL.md` |
| Stop at a safe boundary, write the resume note off-context; on pickup the trail is authoritative, verify inherited claims on the real artifact | `STATE.md` §2, SKILL §0 | pstack `playbooks/pause-safely.md`, `playbooks/session-pickup.md` |
| Long-lived memory as dated history; mark superseded; periodic lint for contradictions; tactical and strategic tracks | `STATE.md` §1, §4 | Matt Pocock `skills/in-progress/chief-of-staff/SKILL.md` |
| Fix a repeated mistake at the highest level that works; pair each rule with its enforcer; drop a rule once its mistake cannot happen | SKILL §8; `enforced by:`; the launcher refusals | pstack `skills/correct/SKILL.md`, `skills/principle-encode-lessons-in-structure/SKILL.md` |
| Steps first, reference behind pointers with a stated trigger; sprawl thins attention | the shape of SKILL.md and §9 | Matt Pocock `skills/productivity/writing-for-agents/SKILL.md`; pstack `skills/principle-guard-the-context-window/SKILL.md` |
| Remove before adding | PLAYBOOK.md duplicate removed; rules moved, not multiplied | pstack `skills/principle-subtract-before-you-add/SKILL.md` |
| Decision trail audited by another model at hand-back | phase-close trail audit | pstack `skills/show-me-your-work/SKILL.md` |
| Trust before parallelism; one paved road per pattern; verification through a reproducible CLI; watch a few runs before scaling | WIP limit; one resume file, one routing file; replay CLI; one unit first | a talk by Lauren Tan (from a secondary summary; not verified against a primary source) |

## Deliberately not adopted
| Idea | Source | Why not |
|---|---|---|
| The pstack plugin, its routing hook and model-role rule | pstack `skills/setup-pstack/SKILL.md`, `skills/poteto-mode/SKILL.md` (Subagents) | executors here run behind CLI wrappers; a second router would compete with this skill |
| "Call no scripts, run no polling loops" for the coordinator | pstack `playbooks/orchestrate.md` | headless executors cannot message the coordinator; file markers and one waiter per lane are the only signal |
| PR owners that push and merge; forge event subscriptions; babysit/shipping playbooks | pstack `playbooks/` | merges are local and need the coordinator; push needs user authority |
| Three parallel reviewers plus a synthesizer for every reflection; arena bake-offs | pstack `skills/reflect`, `skills/arena` | too costly for a quota-limited setup; one cheap prune proposal plus coordinator review does the job |
| Issue-tracker workflow: specs, tickets, triage labels, wayfinder maps | Matt Pocock `to-spec`, `to-tickets`, `triage`, `wayfinder` | no tracker in this setup; DECISIONS plus cards already play that role, a second system would add state to keep in sync |
| A wiki of interlinked pages as coordinator memory | Matt Pocock `chief-of-staff` | a second memory system adds state to keep in sync; only its two rules were taken (dated history, supersede and lint) |
| Interviewing the user (grilling, questionnaires) before work | Matt Pocock `grilling`, `grill-me`, `to-questionnaire` | the coordinator decides within recorded rules and asks only for new authority |
| HITL loop scripts; asking the user to reproduce | Matt Pocock `diagnosing-bugs` (last resort) | the coordinator must not block on the user |
| "Don't reference file paths in briefs: they go stale" | Matt Pocock `triage/AGENT-BRIEF.md` | cards here are executed within minutes on a pinned SHA; exact paths prevent wrong-tree edits |
| TDD vertical slices, code-smell baseline | Matt Pocock `tdd`, `code-review` | product-code practice, belongs in the repo's own standards, not in a coordinator skill |
| Automatic stuck escalation to a stronger model | — | model choice is the user's routing rule; the protocol escalates to the user with options instead |
