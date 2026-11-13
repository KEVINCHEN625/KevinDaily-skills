# Coordinator core review checklist (before every commit; an external approval alone is never enough)

Record the verdict in DECISIONS ("D-NNN 补充 / follow-up: core review PASS — …" or a new entry for a REJECT).

1. Hand-back: first line (READY-FOR-REVIEW / NEED-DECISION / …), STOP items, residuals, open questions, the
   RESOURCE-HANDOFF table. A missing report or table = not ready.
2. Scope: `git -C <wt> status --porcelain` (including untracked `??`) and `git diff --stat <base>`; every file belongs
   to this ruling; no edits in forbidden areas or other lanes' files; no generated files edited by hand.
3. Key product diffs read by you (not just summarized): locks/transactions/CAS, ownership/permission/privacy gates,
   user-facing text, money/quota/counters, migrations/schema, public API/SSE shapes.
4. Tests: RED existed and failed for the right reason (saved output); changed existing assertions are justified with a
   decision reference and are not weaker; no new skip/xfail; inputs are production-shaped (lesson: injected test-only data).
   Request-scoped/read-only fields added to a sealed projection: kept outside the seal; test helpers that re-seal a GET
   snapshot strip them; write responses that omit them do not re-enable UI actions (UI carries the last read forward).
5. Recompute or rerun at least one key number yourself (a test count, a byte budget, a hash, a failing→passing test).
6. Second-review findings: each P0/P1/P2 verified against the code and either fixed, consciously deferred with a
   decision, or rejected with a reason. The reviewer was not the author of this diff.
7. Baseline: failures compared with the saved baseline log by node × phase × signature (not per-file counts, not a
   sample); inherited failures listed by node; "same node, new reason" counted as new; setup/collection errors reported
   as NOT EXECUTED; no "same-ID" masking of a growing metric; HANG / NOT RUN stated as such.
8. Sandbox-impossible checks (native listeners, real DB clusters, shared git metadata): run them yourself, bounded, or
   record why they are deferred.
9. Resources: review the temporary-environments list; delete only provably temporary items from an exact list; record it.
10. Commit: explicit paths only (never `git add -A`/`.`), message names the decision, commit on the lane branch, record
    the sha in DECISIONS and update the lane's WIP line in HANDOFF.md.
