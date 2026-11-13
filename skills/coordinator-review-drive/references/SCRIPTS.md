# Script reference

All take explicit arguments; none reads credentials or calls a model. `bash` scripts run on macOS bash 3.2 and on
Linux bash; wrappers are zsh (invoke as `zsh <script>`). Env knobs are in each header. Extra tools: `perl`
(`launch-lane.sh`, `scan-logs.sh`), `lsof` (`check-serving.sh`), `git` (commit, merge, serving and preflight checks).

## Checks (turn a rule into a verdict line)
| Script | Verdict line | Writes |
|---|---|---|
| `goal-check.sh <G> [--stall-hours 12] [--max-side 2] [--max-total 6] [--handoff-max-age-hours 6] [--memory <index>]` | `HANDOFF` / `STUCK-CHECK` / `WIP` / `RULES`, then `GOAL-CHECK PASS\|ATTENTION n` | nothing |
| `preflight-run.sh <G> <page\|replay\|gate> <tree> [--port N]… [--log F]… [--ack F] [--no-replay "<reason>"]` | `TREE` / `SERVING` / `HOST` / `LOGS` / `REPLAY` / `STUCK`, then `PREFLIGHT PASS\|WARN\|FAIL` | nothing |
| `scan-logs.sh [--ack F] [--min N] [--top N] [--mark F [--update-mark]] [--runs RUNS.tsv] [--since <UTC>] [--since-hours N] <log>…` (env `LOG_TZ=utc`) | `LOG-SCAN PASS\|FAIL … window=[…]` + signature histogram (secrets redacted); window = mark, else last logged run, else `--since`, else last N hours, else ALL | the mark file, only with `--update-mark` |
| `check-serving.sh <tree> <port>…` | per port `OK` / `STARTED-BEFORE-HEAD` / `OUTSIDE-TREE` / `NOT-LISTENING`, then `SERVING-CHECK` | nothing |
| `check-card.sh <card>` | `CARD-CHECK PASS\|FAIL` (CARD, TRACK, GOAL, DONE-EVIDENCE, SCOPE, FORBIDDEN, ITEMS, REPLY-CONTRACT, forbidden tests) | nothing |
| `check-report.sh <reply> [card]` | `REPORT-CHECK PASS\|FAIL` (STATUS, GOAL, every item, EVIDENCE `$ cmd`, RED, PROOF per finding, COVERAGE, RESOURCE-HANDOFF) | nothing |

## Actions with a guard
| Script | Purpose |
|---|---|
| `log-run.sh <G> <goal> <page\|replay\|gate> <sha> <reached> <target> <PASS\|FAIL> <evidence> [blocker…]` · `log-run.sh <G> <goal> unstuck <record>` | append one validated row to `G/RUNS.tsv`; column 10 is `no-replay` for a page run on a build with no earlier passing replay |
| `launch-lane.sh <out> <wrapper> [args…]` | lint the card, refuse a used out dir and a side lane over the WIP limit (exit 2), start the wrapper detached in its own process group; records `WRAPPER_PID`, `WRAPPER_START`, `LAUNCHED_UTC`, `CARD_PATH`; env `LEGACY_CARD=1`, `WIP_OVERRIDE=<reason>` |
| `wait-lane.sh <out> [--stall S] [--max S]` / `--pid P --log F` | ONE waiter per lane, `run_in_background`; always exits 0; first line `LANE DONE/DIED/STALL/TIMEOUT`, then `REPORT-CHECK` |
| `kill-lane.sh <out>` | stop exactly one lane (its own process group); refuses a lane that shares a group, and a PID whose start time differs from `WRAPPER_START` (reused PID) |
| `safe-rm.sh [--apply] [--allow-work-files] <root> <path>…` | guarded delete of computed paths; dry run by default |
| `lane-commit.sh <wt> <subject> <lane> [path…]` | add exact changed files (NUL-safe, rename-aware), commit with a `Lane:` trailer (and `Co-Authored-By:` when env `COAUTHOR` is set), prove HEAD moved and the files are clean |
| `merge-lane.sh <lane-wt> <lane-br> <inst-wt> <inst-br> [check…]` (env `RUN_LOCK`, `LIVE_PORTS`, `LIVE_WAIT`, `MERGE_LINK_DEPS`) | the only merge into a running instance: refuses during a run, pre-merges, every check must exit 0, ff-only, then waits until `check-serving.sh` passes |
| `lane-commit-msg.sh <out-file> <subject> <lane> [body]` | commit message with trailers as the last paragraph, verified (used by `lane-commit.sh`) |
| `init-goal.sh <G> [title]` | create G from templates (never overwrites) |
| `make-lane-worktree.sh <repo> <root> <slug> <base> [dep…]` | lane worktree + branch, deps symlinked |

## Wrappers (out-dir contract: `DISPATCH.md` §5)
| Script | Purpose |
|---|---|
| `run-codex.sh <G> <session> <cwd> <read-only\|workspace-write> <model> <effort> <card> <out>` | Codex task, named-session resume, policy header |
| `run-codex-web.sh <G> <session> <cwd> <model> <effort> <card> <out>` | Codex browser tester |
| `run-dsh.sh <G> <workdir> <card> <out> <provider> <model> <effort> [mode]` | dsh headless task; retries on upstream errors |
| `run-zcode-review.sh <G> <worktree> <prompt> <out> [label]` | read-only second review, end-marker check |
| `run-zcode-exec.sh` / `run-zcode-test-exec.sh` | reviewer model as small-edit executor (you run the tests; another model reviews) |
| `run-claude.sh <G> <session\|-> <cwd> <model> <prompt> <out> [allowed-tools]` | headless claude -p, MODEL-USAGE.txt |

## Other
`probe-agents.sh` (presence/version/capacity; no secrets, no model calls) · `quota-pace.py`, `claude-quota.py`
(window pacing; `ROUTING.md` §2.1) · `chrome-supervisor.sh <port> <profile>` (one shared headless Chrome, restart
limits) · `wait-lanes.sh` (legacy list waiter; never on the same lanes as `wait-lane.sh`) · `lib.zsh` (sourced).
