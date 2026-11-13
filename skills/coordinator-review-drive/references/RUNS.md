# Runs: preflight, whole-path replay, page acceptance, live diagnostics

Read when: before any test run, when building the replay harness, when a live check fails with a generic code.

## 1. Preflight (before EVERY run)
`bash $SKILL/scripts/preflight-run.sh $G <page|replay|gate> <instance-tree> --port <p>… --log <file>… [--ack <file>]`

| Line | Meaning | On FAIL / WARN |
|---|---|---|
| `TREE` | HEAD of the instance tree; uncommitted tracked changes | someone is mid-edit: wait or use another instance |
| `SERVING` | each port's process runs from this tree and started after its HEAD moved (`check-serving.sh`) | restart it from the tree; a merged fix that is not live does not exist |
| `HOST` | free disk ≥ 10 GB, load ≤ 20 | free space / wait; results under a full disk are void |
| `LOGS` | error signatures in every instance log (`scan-logs.sh`), minus `G/LOG-ACK.txt` | each un-acked signature is a blocker: fix it, or ack it with a decision id |
| `REPLAY` (page) | last replay of the main goal passed on this HEAD | run the replay first |
| `STUCK` (page) | no open stuck verdict | do `UNSTUCK.md` |

Save the output with the run's evidence. `--no-replay "<reason>"` is for the time before a harness exists and is
bounded: it works only while HANDOFF.md lists an active main lane that builds the replay harness
(`WIP: main | replay-… | … | running`), and for at most 2 page runs per goal (`log-run.sh` marks them `no-replay`
in `RUNS.tsv`). After that the preflight fails until a replay passes.
The LOGS check reads only the window since the last run logged in `RUNS.tsv` (else the last 24 h) and prints it; a
whole multi-day log is noise (one large log gave hundreds of signatures, a handful of them from the current day). Log timestamps are
read as local time; set `LOG_TZ=utc` for a log written in UTC.
Tell each instance to write its logs to a known file (tee the dev server, worker and proxy output); a log you cannot
name cannot be scanned.

## 2. Whole-path replay (the fast loop; build it once per entry)
Purpose: find ALL blockers of the user path in minutes, without a browser.
- **What it is**: one script per entry (e.g. `replay-onboarding.sh`) that creates a fresh object and sends the same
  requests the page sends, step by step to the predicate, against a replay instance. Build it from a captured
  network trace of a real page run (request method, path, body shape), not from reading the code.
- **Own instance**: its own tree at the batch SHA, its own DB copy, its own ports. Fix lanes verify on it at any
  time; the page instance is only touched between page runs. This removes the queue of fixes behind a running tester.
- **Two modes.** `discover`: on a failed step record the blocker (step, request, status, body code, log signature
  from that moment), then continue through a labelled bypass where one exists (retry, the documented recovery action,
  a seeded intermediate state) and report every bypass. `strict`: no bypass; this is the mode whose PASS allows a
  page run.
- **Output**: last line `REPLAY PASS|FAIL reached=<n> target=<m>`, plus one line per blocker. Model calls use the
  configured cheap test model with a call cap; a replay is not a quality judgment, only a path check.
- **Honesty**: a bypassed step is a blocker, never a pass. A replay PASS is not acceptance; only the page run is.
- **Card**: `templates/TASK-CARD.md` §J. The harness is product-adjacent test tooling: it lives in the repo's test
  tools or under `G/lanes/_common/`, gets reviewed like any fix, and is rerun unchanged after every merge that
  touches the path.
- Log every run: `log-run.sh $G <goal> replay <sha> <reached> <target> <PASS|FAIL> <evidence> "<blocker>"…`.

## 3. Page run (acceptance)
- Use `templates/WEB-TESTER-TASK.md`. Staged: one stage passes before the next; no fallback paths; the tester may fix
  in place only in a designated fix worktree (root cause + tests + fix log; HIGH-RISK flagged) and escalates after two
  failed attempts or when a design/migration/API decision is needed. Testers reply NEED-RESTART after backend changes.
- The coordinator prepares the instance and browser natively, confirms which code is running, and never restarts a
  hot-reloaded instance while someone is mid-edit in that tree. Do not run live tests against an instance whose files
  (verified by bytes or version at runtime) an implementer is editing: you get version-skew false failures.
- Acceptance judges real capability and persistence (refresh + read-only DB/API check), not "it responded".
- If the acceptance object carries edge history (an old job, legacy data), run a parallel lane on a **fresh** object
  for the normal new-user path while the edge case is fixed.
- **Design iteration keeps a "liked effects" list** (things the user explicitly liked); review/scoring rules may not
  remove items on it without asking the user.
- Report each acceptance round to the user with `templates/ACCEPTANCE-REPORT.md` (one row per stage).
- An acceptance run is strict: stage order, no substitute path, stop at the first failed stage. That is right for
  acceptance and wrong for discovery; discovery belongs to the replay (§2). Do not use page runs to find blockers.
- Independent surfaces are tested in parallel and never wait behind one blocker.

## 4. After every run
0. Page run on an instance: `touch $G/RUN-IN-PROGRESS` when you dispatch it, remove it when the reply is handled;
   call `merge-lane.sh` with `RUN_LOCK=$G/RUN-IN-PROGRESS LIVE_PORTS="…"` so a merge cannot land under a tester.
1. `scan-logs.sh --mark $G/logmark.tsv --update-mark <logs…>` (or `--since <UTC start of the run>`): the signatures
   of the run window. Do this BEFORE `log-run.sh`: the next preflight only looks at what came after the logged run.
2. Blocker list = the page/replay failures + every log signature + every failed request in the network capture.
   Write all of them into HANDOFF.md "Open blockers" and open main-track lanes for all of them at once.
3. `log-run.sh` with every blocker signature (short and stable, e.g. `save-draft 502 Content-Length`).
4. Report to the user with `templates/ACCEPTANCE-REPORT.md`: progress number, all blockers, what is unknown.

## 5. Live acceptance finds what offline tests miss
Offline suites prove the code paths you thought of; the deployed instance with real configuration finds the rest
(empty legacy bindings, policy versions from older history, provider echo quirks). When a live check fails with a
generic code (`state_conflict`, `ValueError`, "unclassified"):
- do not guess a fix; first add **content-free typed diagnostics at the boundary** — a fixed set of sub-reason codes
  (e.g. `provider_unavailable`, `model_echo_mismatch`) logged in one safe line — so the next run names the exact
  predicate that failed;
- fix narrowly with evidence-backed tolerance only; never loosen claim/accounting/authorization to make it pass;
- record the call counts each acceptance spent; re-run the replay (not the page) to check a diagnostic.

## 6. Cheap-model page testers (observations)
- A cheap, fast model behind a headless harness can be the main real-page tester. Give it a headless Chrome through
  the chrome-devtools MCP. Pass credentials through a redacting adapter (file references), never in plain text.
- Separate concurrent testers by hostname, not port (cookies are per host). Each project gets its own Chrome/port.
- Let it fix UI/display issues. Route data-semantics fixes (facts, identity, user values, write-back, persistence,
  privacy, safety guards) to the strong executor. Have every cheap-model fix reviewed by a different model.
- Plan for its context cap: small snapshots, scripted reads, split rounds, and continuation tasks seeded with the
  evidence gathered so far.
- If it cannot stage, commit or kill processes in its sandbox, the coordinator stages, commits and cleans up. Make it
  restart services only through the managed scripts.
