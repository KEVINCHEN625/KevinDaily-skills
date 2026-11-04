# AGENT LESSONS (coordinator-maintained; cite this file in every implementer/tester task card)

Format per lesson: symptom → root cause → from now on. Add project lessons at the end with the D-number that proved
them; write new entries in the user's language. Seeded from a long multi-agent closeout run (generalized).

These are author-observed lessons, not universal model benchmarks. Record the current harness, actual model,
task type, date and evidence when applying or updating a lesson. This file is maintained per goal; the skill does
not automatically synchronize a global model-performance database.

## A. Verification and acceptance
1. **Passed in a test host, never wired into the real startup path.** Factories/fakes injected the dependency the
   real entry never assembled. → Acceptance goes through the formal entry point. Every "tests pass" must answer:
   who calls this code at real startup, and where?
2. **Fixtures that set state by SQL hide flows that cannot actually be reached.** → Public-flow acceptance seeds use
   real state transitions. A SQL/state-poking fixture is "unit only" and needs a sibling real-path test.
3. **Test helpers injected data the production caller never provides** (an optional key in state), so the fix "worked"
   in tests and was dead in production. → Build RED inputs from the real caller/production constructor; reviewers
   check that every test input exists in production.
4. **UI recovery tests passed a ready-made state straight into the component; on the real page the button never
   appeared.** → Drive UI tests through the real read chain (reader → reducer → hook → component), mocking only transport.
5. **Only the new tests were run; an existing test family of the same module broke.** → Re-run every existing test
   family of each touched module, not just the new file.
6. **"No new failure IDs" masked a regression** (a size/complexity budget grew while the failing test ID stayed the
   same). → Compare the measured metric too, not just the ID set; a ratchet regression is a regression.
7. **A hang was almost counted as a pass; sandbox-denied tests were almost counted as run.** → HANG, NOT RUN and
   SANDBOX-DENIED are their own states; the coordinator reruns natively with a hard timeout and process-group cleanup.
8. **"It replies" is not acceptance for an AI agent feature.** → Judge real capability: cites existing data with its
   source, remembers earlier turns, targets the right field, adopted changes persist (refresh + read-only DB check),
   rejected ones do not, and the next turn sees the new value.

## B. Data safety and lifecycle
9. **A reuse/resume heuristic ("found one of the same kind, reuse it") overwrote an object that had history** (P0 data
   loss). → Reuse only an exact-id empty shell; the server must independently prove emptiness before any write.
10. **A defect class was fixed at one entry point; another entry point had the same bug.** → Enumerate all entry points
    (UI flows, imports, direct API) and give each a RED test.
11. **A state had no exit for the user** (could not stop, could not restart, could not create new). → Every lifecycle
    state needs a user-visible exit (continue / abandon / new); discovery excludes closed states.
12. **A program bug made a run non-retryable.** → Failures caused by our own defects must leave a retry or a clear
    recovery entry, never a dead end.
13. **Internal keys leaked into a public summary and a guard rejected the whole run.** → Recursively project internal
    data at every public boundary (API/SSE/summary); a guard rejection is a program bug, not the user's problem.
14. **A new field reached a strict public schema and returned 500.** → Any change to data that reaches a public
    schema needs a test that validates real data against the strict public schema.
15. **A per-layer generation cap truncated the user's own data.** → Budgets limit single model calls/batches only;
    user-provided baselines are preserved completely and checked for coverage on merge.
16. **Fail-open on unverifiable data** (a broken signature/envelope silently dropped user content). → Fail closed with a
    typed reason and keep the original; never let degraded verification erase or bypass user data.

## C. Diagnosis
17. **A plausible mechanism was "fixed" without evidence and the test froze a false premise.** → Capture evidence at the
    real layer first (request body/response, DB before/after, first full traceback), then fix.
18. **Blacklists kept leaking** (negation word lists missed variants again and again). → Invert to an allowlist of
    explicit positive requirements when a blacklist fails twice.
19. **Patching the same mechanism layer after layer** (four rounds of budget patches; one layer fixed per retest cycle).
    → After the second similar failure, stop and do a structural fix or an all-layers audit in one pass.
20. **Declared tools ≠ admitted tools; capability entry ≠ availability window.** → Derive declared/admitted sets and
    availability tables from one manifest, with a consistency test per profile.
21. **Config gaps were shown as "temporarily unavailable".** → Capability probes return specific reason codes with a
    user-readable explanation and where to fix it.
22. **Over-engineering blocked usability** (insisting on an exact proof the infrastructure could not give). → Ask which
    invariants the user truly needs; declare approximations explicitly, bound them, and backlog the rest.

## D. Test environment and tooling
23. **A restart script reported success while the old process still answered health checks.** → Restart by the
    listening port's real PID; wait until the old PID has exited (kill -0); success = new PID + healthy.
24. **Testers' sandboxes cannot restart the host.** → Tester replies NEED-RESTART first line; the coordinator restarts.
25. **Testers routed around a failing stage** (fell back to a blank project) and hid the main-flow failure. → Staged
    testing; no fallback paths; fix in place or escalate.
26. **Executors called paid reviewers themselves.** → Wrapper policy header: reviews are arranged by the coordinator.
27. **Read-only sandboxes cannot write deliverables.** → Ask for the full deliverable in the final message.
28. **Reused out dir: stale FINISHED_UTC/.seen/LAST-MESSAGE misled the waiter or made it wait forever.** → New out dir
    per dispatch; if a name must be reused, move old markers into a subdirectory (never delete them).
29. **A retry regex missed a new upstream error class and a lane died.** → Extend the wrapper retry pattern for upstream
    errors only; never retry task failures.
30. **Two tasks in one worktree; one's half-done schema change broke the other's test collection.** → One writer per
    worktree when schema or test collection can be affected; otherwise separate worktrees or run sequentially.
31. **Commit added only modified files; the new untracked RED test was left out.** → Before every commit, list all
    changes including untracked (`git status --porcelain`), review each, add explicit paths.
32. **Deleting by an executor's own judgement removed evidence dirs.** → The coordinator produces the exact deletion
    list, reviews it, and only then has it executed.
33. **Model aliases are not model ids** (an alias resolved to an older model). → Use full model ids and verify the
    model actually used from the tool's usage output.
34. **Headless reviewers truncate long output or answer with only a "will write after approval" preface.** → Ask for
    batched complete output with an explicit end marker, "output directly, do not wait for approval"; rerun if missing.
35. **Browser-testing tools:** use only the named MCP browser server (no built-in browser automation that exec mode
    denies); file inputs without configured roots: build a File via DataTransfer in-page; check dev-server origin
    allowlists with `curl -H "Origin: …"` before dispatching testers.
36. **Symlinked dependencies outside a sandbox root were unreadable.** → Materialize a copy inside the lane when a
    sandbox denies the link target.
37. **Same config file used twice by a tool** (npm user+global both /dev/null → double-loading error). → Use distinct
    empty files.

## E. Coordination
38. **Independent stages waited a day behind one long-tail blocker.** → Never serialize independent work behind a
    blocker; open a parallel lane on another project/session/page.
39. **A fast executor produced wrong root causes on lifecycle/state bugs.** → Route lifecycle/state/multi-field UI and
    data-safety work to the main implementer; fast executors take clear, specified edits.
40. **A stronger model's output was still wrong.** → No executor is exempt from second review + coordinator core review.
41. **A deploy step was blocked by the permission classifier.** → Do not retry or bypass; give the user the exact `!`
    commands (ordered, with time limits) or ask for an allow rule on one fixed, guarded entry script.
42. **Test-only fixes found during batch verification moved the HEAD that the deploy approval/pin was bound to**, so
    guarded tools refused to run. → Approvals and pins bind to an exact committed HEAD: deploy that HEAD, commit
    test-only fixes separately afterwards, and re-pin the tools whenever HEAD changes.

## F. Gates and test integrity
43. **"Zero regressions" was claimed because per-file failure counts matched a clean HEAD.** Equal counts hid fixed and
    new failures in the same file. → Compare by test node × phase × failure signature; a new reason on a known node
    is a new failure; per-file counts and samples are never regression proof.
44. **A list of named clusters was treated as the disposition of ~1,400 failures.** → Naming a cluster explains;
    it does not dispose. Accepted failures need per-node ledger entries (reason, version, evidence, impact, owner,
    deadline) confirmed by an independent review; no cluster or wildcard exemptions.
45. **The gate drifted** from "resolve the integrated suite" to "no new failures in this lane", while weeks of
    affected-subset testing let contract changes, moved receipts, a default-mode switch and an incomplete test
    environment pile up unseen. → Write the gate's exact wording into DECISIONS and re-read it per batch; run a broad
    canonical suite (with env preflight) at every RC / milestone.
46. **Setup errors were counted together with failures.** Their test bodies never ran. → Report errors separately as
    NOT EXECUTED, with how many tests never executed.
47. **"Gate passed" was about to be reported as "green".** → Say "gate passed with N reviewed ledger entries"; report
    the real counts.

## G. Review independence and design loops
48. **The second-reviewer model was trialled as executor; reviewing its own diff would prove nothing.** → Author ≠
    reviewer: a different model reviews (here an independent strong subagent found a P2 the author missed).
49. **A key design failed cross-review twice** (5 P1s, then 3). → Loop: DESIGN → review → DESIGN-v2 → re-review of
    every previous finding → … until PASS; keep versions side by side; steer scope between rounds; implement after PASS.
50. **An implementer would have shipped a half lifecycle change under release pressure.** → Cards carry a stop threshold
    (> ~N lines or a lifecycle redesign → stop after RED + design). The key-design review then chooses implement-now or
    ship-disabled (typed refusal before any write/send, availability flag, UI disabled before consent). First check
    whether the feature ever worked; disabling something that never worked removes nothing.

## H. Providers, quotas and executors
51. **A fast-executor subscription ran out (429 until a reset date); three attempts produced no edits.** → Stop that
    provider until the reset, reroute in the same worktree per the user's fallback order, record it.
52. **A CLI's refresh token was revoked (401); every lane on it stopped.** → Tell the user the exact fix
    (`<cli> logout && <cli> login`), move urgent work to the fallback, verify with one trivial exec before re-dispatch.
53. **~16 parallel strong subagents (some forking their own) used up a 5-hour window in under an hour; later, 4
    started together at a reset hit ~90 % in 2.5 h and had to be stopped mid-task.** → Hard cap ≤ 4 with "no sub-agents
    or forks"; normally 1–2 at a time following a WINDOW-PLAN on the straight line (`quota-pace.py`: START / HOLD /
    FINISH-ONLY); prefer not starting over stopping; fresh compact briefs over resuming very long contexts.
54. **The reviewer model, used as an edit-only executor, wrote correct code but could not run python/node.** → Use it for
    small, clearly scoped edits; the coordinator runs the tests (expect test-side fixes) and another model reviews.
55. **A new strong executor tended to patch the named counterexamples rather than close the invariant.** → Keep a
    track-record row per model (rounds, residual defects); security/concurrency/egress work gets the strictest reviewer.

## I. Live acceptance and deploy
56. **Live acceptance failed with generic codes (`state_conflict`, an unclassified `ValueError`) that offline tests
    never hit** (an empty legacy binding list in configured mode; history created under an older policy version; a
    provider echoing a different model id). → Add content-free typed sub-reasons at the boundary (fixed codes, same-family
    ids and counts; never provider content or secrets), redeploy, re-run once, fix the named predicate narrowly.
57. **An acceptance object with odd history kept failing and hid whether the normal path worked.** → Run a parallel
    lane on a fresh object for the new-user path.
58. **A request-scoped, read-only field was added to a sealed read projection.** A test helper re-sealed a GET snapshot
    that now carried it, and write responses (which omit read-only fields) re-enabled a disabled button after any save.
    → Keep such fields outside the seal; helpers strip them; the UI carries the last read's value forward.
59. **A guarded deploy tool refused mid-run** ("old deployment changed"); the cause was a raw-vs-schema-normalized
    comparison, not tampering. → Diagnose before retrying; fix narrowly; add a resume subcommand.
60. **The live deploy step was blocked by the auto-mode classifier, even with an allow rule.** → Merge everything, rebind
    once, hand the user one exact command; verify receipts afterwards.
61. **Asking the user for a provider key that was already configured in the test account.** → Check recorded env and
    memory before blocking on the user.

## J. Briefs and process hygiene
62. **A card written with an unquoted heredoc lost backticked words** (the shell ran them). → `<<'EOF'` + sed.
63. **A wrapper got the card text instead of the card path; the session only received the policy header.** → Pass the
    FILE; check the log for a card keyword after launch.
64. **A wrapper without +x launched via nohup failed silently for an hour.** → Always `zsh <script>`; check
    `<out>/STARTED_UTC` within ~10 s.
65. **A reused runner script lacked the forbidden-test exclusion.** → Every broad command names `--ignore=<path>`.
66. **The shared headless browser disappeared mid-scan (twice); one start had used a plain `&` and died with the
    tool shell.** → Start it detached (double fork) under a supervisor; every web card says "never close, kill or restart
    the shared browser; close only your own tabs".
67. **Killing a wrapper left its child CLI running; two runs then wrote one worktree.** → Stop the child by PID/session,
    confirm with `ps`, then relaunch. Lanes started with `&` inside a waiter die with the waiter: launch separately.
68. **Pollers built on `pgrep -f` matched themselves and never exited; leftover `until … sleep` shells piled up.** → PID
    files or log markers; one waiter; sweep leftovers after subagents finish.
69. **A review CLI's image analysis uploaded screenshots to an external host.** → Images go only to local-vision reviewers,
    and only with synthetic data.
70. **Design review/scoring rules quietly removed effects the user had explicitly liked.** → Keep a "liked effects" list
    in the design brief; removing an item needs the user's OK.
71. **Live tests ran while an implementer edited files the running service verifies by bytes.** → Do not test an
    instance whose checked files are being edited; wait for the hand-back, then restart.
72. **Narrowing a safety guard to get past a false positive was blocked by the auto reviewer (even the revert was).**
    → Guard changes are the user's security decision: stop and present options and commands first.

## K. Pacing, pools and long runs
73. **A cheap model investigated well but stopped at the analysis when the brief left a choice open.** → Write every
    decision into the brief; then cheap models finish well-specified tasks in one round. Spread such work over the
    whole cheap pool.
74. **An expensive agent polling a hung test run pushed the window ~20 points above the pacing line.** → Long or waiting work goes to a cheap
    executor; the expensive agent reports from the evidence it already has.
75. **A chained "wait for A, then run B" deadlocked for 2.5 h**: the waiter matched processes whose argv contained the
    out dir — including the chain itself. → Wait on a PID or a sentinel file; never put the waited path in the chain's
    argv.
76. **A memory blow-up made the OS reaper kill every background lane and waiter at once.** → After any mass-kill notice,
    check every lane's PID/markers, kill orphans, re-dispatch dead lanes, recreate the waiter.
77. **A commit into the tree serving a live run triggered an autoreload that reset requests; the run blamed the
    product.** → Live runs serve from a dedicated detached worktree at the pinned SHA.
78. **An audit agent's in-tree docs made the tree dirty and the clean-tree smoke gate refused to run.** → Agents and
    harnesses write docs, logs and run output outside product worktrees (or into an excluded folder).
79. **Two lanes independently built the same decoupling.** → Tell overlapping lanes about each other's commits.

## L. Gates and defect classes
80. **A smoke PASS was followed by real failures on steps it did not cover.** → Extend smoke coverage stepwise; run a
    broader real-model e2e periodically; offer per-path retries but count only an all-paths PASS on the frozen SHA.
81. **Two live smoke runs failed on the harness's own request payloads.** → Validate harness payloads offline against
    the product's real request models before spending model calls.
82. **Four different schema-drift failures in four runs were fixed one by one.** → After 2–3 of a class, audit the
    class from the raw kept outputs and fix it with one general step; here the root cause was a cleanup that deleted the
    keys the repair needed.
83. **Four review rounds kept finding holes in one integrity ledger and the code grew.** → The design was wrong: take the
    real source of truth (the filesystem) and make the ledger a cache; the code shrank by ~28 %.
84. **Repair prompts stated a limit and also said "do not truncate"; others said "drop" and "never delete".** → Audit
    prompts for self-contradiction before adding repair machinery.
85. **A default value became a hard cap that refused valid requests.** → Record each limit's provenance (user-set /
    declared / default); enforce only the first two; defaults are estimates.
86. **Unknown errors were collapsed into misleading specific codes** ("plan changed", "unknown send", a security message
    for a missing chapter heading). → Keep unknown errors distinct; a misleading user message is a product bug.
87. **A plan to regenerate a sealed schema/manifest would have broken in-flight jobs pinned to its digest.** → Sealed
    contracts are immutable: decouple via a frozen copy plus a drift test; changes go into a new version.
88. **A registered experiment needed rule changes mid-way (a tolerant parser, a prompt example).** → Change registered
    plans only by a reviewed amendment written before any result exists; never lower a rule after seeing data.
