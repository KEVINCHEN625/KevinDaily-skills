# Real-page (browser) tester task template

The card starts with the header checked by `scripts/check-card.sh` (`CARD: page`, `TRACK:`, `GOAL:`, `DONE-EVIDENCE:`
— the end state the user waits for —, `SCOPE:`, `FORBIDDEN:`, `ITEMS: I1…`) and uses the REPLY-CONTRACT of
`TASK-CARD.md` §0. The template below passes the lint as written; fill every `<…>`.

Dispatch with `scripts/run-codex-web.sh <G> <web-tester-session> <worktree> <model> <effort> <TASK.md> <out>`
(or another browser-capable agent from ALLOCATION.md). A page run is an ACCEPTANCE run: it confirms a path the
whole-path replay already passed (references/RUNS.md); it is not the tool for finding blockers.
Before dispatching, the coordinator:
- runs `scripts/preflight-run.sh <G> page <instance-tree> --port … --log …` and gets `PREFLIGHT PASS|WARN` (serving
  code, instance logs read, replay PASS on this HEAD, not stuck); the output goes into the evidence dir;
- starts the instance and ONE shared headless Chrome natively (`--remote-debugging-port=<port>`, dedicated user-data
  dir), detached (`( nohup … & )`) and kept alive by `scripts/chrome-supervisor.sh <port> <profile-dir>`;
- makes sure no implementer is editing files the running instance checks by bytes/version (version-skew false fails);
- checks health and that the dev server serves assets to the tester's origin (`curl -H "Origin: …"` → 200);
- confirms which code the instance runs (worktree/branch/sha) and that no one is mid-edit in a hot-reloaded tree;
- gives each parallel tester its own project/session/page; never two testers on the same account+data concurrently.

---

```
CARD: page
TRACK: main
GOAL: <what the user can do at the end of these stages, one line>
DONE-EVIDENCE: <the end state the user waits for, observed on the real page after a hard refresh, plus a read-only
  API/DB check of persistence>
SCOPE: <G>/e2e-web/<round-id>/ <and the fix worktree, if fixing is allowed>
FORBIDDEN: other testers' accounts and data; closing or restarting the shared browser; API calls that route around
  the page; git commit; real user data.
ITEMS:
I1: Stage 1 <name>
I2: Stage 2 <name>
REPLY-CONTRACT — as templates/TASK-CARD.md §0, with the stage line described at the end of this card.
You are the real-page test engineer for <PRODUCT>, acting as a first-time <user persona>. Coordinator D-<NNN>.
Test the core flow STAGE BY STAGE through the real UI: a stage must pass before the next one starts.

Environment
- Page: <frontend URL>; backend: <backend URL>; code under test: <worktree> @<sha>.
- Browser: use ONLY the tools of the MCP server named "chrome" (navigate, snapshot, click, fill, screenshot, wait_for,
  console/network listing). Never use built-in Browser Use / cua / iab tools.
- The browser is SHARED with other lanes: never close, kill or restart it; open your own tab(s) and close only those.
- A click that seems dead: record document.elementFromPoint at the click point and retry with a DOM element.click()
  (a real user-equivalent click — never a fetch/API call) before reporting a product bug.
- A failure with a generic code (e.g. state_conflict, unclassified error): report the exact code/sub-reason and where it
  stopped; do not guess the cause.
- Test account: read <path to account env file> only to fill the login form; never print the password anywhere
  (reports, screenshots, file names).
- Evidence dir: <G>/e2e-web/<round-id>/ (screenshots, network captures, FIX-LOG.md, REPORT.md).
- Budgets: model-triggering actions ≤ <n> per stage, ≤ <m> total; record each. Any single wait > <k> min is an issue.

Rules
1. Only page operations, like a real user. Do not call APIs to route around a page problem; do not edit the DB or
   settings that are not part of the stage. Read-only DB/API checks for verification are allowed: <how>.
2. Strict stage order. If a stage fails, do NOT continue via a substitute path (e.g. a blank project); fix it or report.
3. For save/persist checks capture the request body + response and re-read after a hard refresh.
4. No real user data/manuscripts; synthetic inputs only. No git commit. Write only inside the evidence dir<and the fix worktree>.

Fixing (only if allowed for this round: <yes/no>)
- Only in <fix worktree>. Root cause, smallest change, related tests run, an entry in FIX-LOG.md (stage, problem, root
  cause, files, test commands + results, HIGH-RISK yes/no). HIGH-RISK = transactions/locks/sessions, auth/security,
  model calls/billing, deletions, migrations/schema, cross-module contracts — allowed only to unblock the flow and must
  be flagged for the coordinator.
- After backend changes reply NEED-RESTART on the first line and stop; the coordinator restarts and resumes you.
- Never weaken tests or guards, never hardcode around a problem.

When a stage fails, before you stop: list EVERY failed request (status >= 400) and console error seen in this round
so far, not only the one that stopped you (method, path, status, response code) — in REPORT.md under ALL-FAILURES.

Escalate (stop the stage and write a proposal under the evidence dir) when: the same problem failed 2 fix attempts; a
product/design decision is needed; a migration or public API change is needed; the environment looks broken.

Stages and pass criteria
- Stage 1 <name>: <steps>. PASS when <observable criteria incl. refresh persistence and user-readable messages>.
- Stage 2 <name>: …

Reply per the REPLY-CONTRACT. First line `STATUS: PASS | ISSUES | NEED-RESTART | NEED-DECISION | BLOCKED`, second line
`STAGE: <n> PASS|FAIL` (the last stage you ran).
Cleanup (mandatory): close every browser tab/page you opened, stop any helper process you started, delete scratch
files outside <out>/evidence/. Test projects you created in the instance: list them (id, kept-as-evidence or removable).
End with the RESOURCE-HANDOFF table (templates/RESOURCE-HANDOFF.md). No table = not accepted.
Then counts used (model calls, sends), evidence paths, and the next stage you would run.
```

## Coordinator after each round
- `scan-logs.sh` over the instance logs for the run window; blockers = the tester's ALL-FAILURES + every log signature.
  Open lanes for all of them at once, then `log-run.sh <G> <goal> page <sha> <reached> <target> PASS|FAIL <evidence> …`.
- Read REPORT/FIX-LOG; treat the tester's root-cause statements as INFERRED until you check them.
- PASS: record per stage in DECISIONS with evidence paths; dispatch the next stage (same session).
- FAIL: classify (P0–P3), rule, dispatch the fix to the owning session, then retest the same stage from the current state.
