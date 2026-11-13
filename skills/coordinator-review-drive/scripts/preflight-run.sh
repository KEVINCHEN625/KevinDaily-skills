#!/bin/bash
# usage: preflight-run.sh <G> <page|replay|gate> <instance-tree> [--port N]... [--log FILE]... [--ack FILE]
#            [--min-free-gb 10] [--max-load 20] [--min-log-count 3] [--no-replay "<reason>"]
# Environment freshness before EVERY test run (page run, whole-path replay, gate). Read-only. A run that starts
# without "PREFLIGHT PASS|WARN" measures the wrong thing. Why: a dev proxy served another tree's code for days, and a
# backend error repeated thousands of times in a log nobody read between long page runs.
# Checks:
#   TREE     <instance-tree> is a git tree; prints its HEAD; uncommitted tracked changes -> WARN (someone mid-edit?)
#   SERVING  check-serving.sh for every --port (FAIL on OUTSIDE-TREE / NOT-LISTENING, WARN on STARTED-BEFORE-HEAD)
#   HOST     free disk on G >= --min-free-gb, 1-minute load <= --max-load
#   LOGS     scan-logs.sh over every --log (ack file default G/LOG-ACK.txt), window = since the last run logged in
#            G/RUNS.tsv (else the last 24 h; the window is printed): un-acked error signatures -> FAIL.
#            Fix them or ack them with a decision id BEFORE spending a run. No --log given -> WARN.
#   REPLAY   kind=page only: the main goal's last replay row in G/RUNS.tsv must be PASS on this HEAD, otherwise FAIL
#            (find all blockers with the cheap replay, not one per page run). --no-replay "<reason>" downgrades to
#            WARN only while a replay-harness lane is active on the main track in HANDOFF.md AND fewer than 2 page
#            runs of this goal ran without a passing replay (RUNS.tsv column 10, written by log-run.sh).
#   STUCK    kind=page only: goal-check.sh says STUCK -> FAIL until the unstuck record is logged.
# Last line: PREFLIGHT PASS|WARN|FAIL kind=… sha=…   Exit 0 on PASS/WARN, 1 on FAIL, 2 on usage.
# Ideas adapted (MIT): pstack prove-it-works (check the real thing), Matt Pocock diagnosing-bugs (a fast, red-capable
# feedback loop comes before any hypothesis).
set -u
G="${1:-}"; kind="${2:-}"; tree="${3:-}"
[ $# -ge 3 ] || { echo "PREFLIGHT usage: preflight-run.sh <G> <page|replay|gate> <instance-tree> [options]" >&2; exit 2; }
shift 3
ports=(); logs=(); ack=""; minfree=10; maxload=20; mincount=3; noreplay=""
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || { echo "PREFLIGHT usage: $1 needs a value" >&2; exit 2; }   # every option here takes a value
  case "$1" in
    --port) ports+=("${2:-}"); shift 2;;
    --log) logs+=("${2:-}"); shift 2;;
    --ack) ack="${2:-}"; shift 2;;
    --min-free-gb) minfree="${2:-}"; shift 2;;
    --max-load) maxload="${2:-}"; shift 2;;
    --min-log-count) mincount="${2:-}"; shift 2;;
    --no-replay) noreplay="${2:-}"; shift 2;;
    *) echo "PREFLIGHT usage: unknown argument $1" >&2; exit 2;;
  esac
done
case "$kind" in page|replay|gate) ;; *) echo "PREFLIGHT usage: kind must be page|replay|gate" >&2; exit 2;; esac
case "$minfree$maxload$mincount" in *[!0-9]*|"") echo "PREFLIGHT usage: numeric options expected" >&2; exit 2;; esac
[ -n "$G" ] && [ -d "$G" ] || { echo "PREFLIGHT usage: no goal dir '$G'" >&2; exit 2; }
[ -n "$tree" ] && [ -d "$tree" ] || { echo "PREFLIGHT usage: no instance tree '$tree'" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
worst=PASS
bump() { case "$1" in FAIL) worst=FAIL;; WARN) [ "$worst" = PASS ] && worst=WARN;; esac; }

sha=$(git -C "$tree" rev-parse HEAD 2>/dev/null || echo "")
if [ -z "$sha" ]; then echo "TREE FAIL: not a git tree: $tree"; bump FAIL
else
  dirty=$(git -C "$tree" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" -gt 0 ]; then echo "TREE WARN: $tree @${sha:0:10} has $dirty uncommitted tracked change(s) — is someone editing the served tree?"; bump WARN
  else echo "TREE OK: $tree @${sha:0:10} clean"; fi
fi

if [ ${#ports[@]} -gt 0 ]; then
  sv=$(bash "$here/check-serving.sh" "$tree" "${ports[@]}")
  echo "$sv" | sed 's/^/  /'
  case "$(echo "$sv" | tail -1)" in
    *"SERVING-CHECK PASS") echo "SERVING OK";;
    *"SERVING-CHECK WARN") echo "SERVING WARN: a process started before the tree's HEAD moved — restart it unless the merge did not touch its code"; bump WARN;;
    *) echo "SERVING FAIL: restart the listed port(s) from $tree"; bump FAIL;;
  esac
else echo "SERVING WARN: no --port given, nothing proves which code is serving"; bump WARN; fi

free=$(df -g "$G" 2>/dev/null | awk 'NR==2 {print $4}'); [ -n "$free" ] || free=$(df -BG "$G" 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
load=$( (sysctl -n vm.loadavg 2>/dev/null || cat /proc/loadavg 2>/dev/null) | tr -d '{}' | awk '{printf "%d", $1}')
h=OK; [ -n "$free" ] && [ "$free" -lt "$minfree" ] && h=FAIL; [ -n "$load" ] && [ "$load" -gt "$maxload" ] && h=FAIL
echo "HOST $h: free=${free:-?}GB (min $minfree) load1=${load:-?} (max $maxload)"; [ "$h" = FAIL ] && bump FAIL

if [ ${#logs[@]} -gt 0 ]; then
  [ -n "$ack" ] || ack="$G/LOG-ACK.txt"
  lsout=$(bash "$here/scan-logs.sh" --mark "$G/LOG-MARK" --runs "$G/RUNS.tsv" --since-hours 24 --ack "$ack" --min "$mincount" --top 12 "${logs[@]}"); lrc=$?
  echo "$lsout" | sed 's/^/  /'
  if [ "$lrc" -eq 0 ]; then echo "LOGS OK"; else echo "LOGS FAIL: un-acked error signatures above — each one is a blocker to fix or to ack in $ack with a decision id"; bump FAIL; fi
else echo "LOGS WARN: no --log given — the instance logs were not read"; bump WARN; fi

if [ "$kind" = page ]; then
  goal=""; [ -s "$G/HANDOFF.md" ] && goal=$(grep -E '^MAIN-GOAL:' "$G/HANDOFF.md" | head -1 | sed -E 's/^MAIN-GOAL:[[:space:]]*//' | awk '{print $1}')
  if [ -z "$goal" ]; then echo "REPLAY FAIL: no MAIN-GOAL id in $G/HANDOFF.md"; bump FAIL
  else
    last=""; [ -s "$G/RUNS.tsv" ] && last=$(awk -F'\t' -v g="$goal" 'NR>1 && $2==g && $3=="replay" {l=$7"\t"$4"\t"$5"/"$6"\t"$1} END {print l}' "$G/RUNS.tsv")
    res=$(printf '%s' "$last" | cut -f1); rsha=$(printf '%s' "$last" | cut -f2); prog=$(printf '%s' "$last" | cut -f3); when=$(printf '%s' "$last" | cut -f4)
    ok=0
    if [ "$res" = PASS ] && [ -n "$rsha" ] && [ -n "$sha" ]; then case "$sha" in "$rsha"*) ok=1;; esac; case "$rsha" in "$sha"*) ok=1;; esac; fi
    if [ "$ok" = 1 ]; then echo "REPLAY OK: goal=$goal replay PASS $prog on ${rsha:0:10} at $when"
    elif [ -n "$noreplay" ]; then
      # the override is bounded: a replay-harness lane must be active on the main track, and at most 2 page runs
      # per goal may have run without a passing replay (log-run.sh writes "no-replay" in column 10)
      harness=$(grep -E '^WIP:' "$G/HANDOFF.md" | awk -F'|' '{t=$1; sub(/^WIP:[ \t]*/,"",t); gsub(/[ \t]/,"",t); s=$4; gsub(/[ \t]/,"",s); if (tolower(t)=="main" && (tolower(s)=="running"||tolower(s)=="review") && tolower($2 $3) ~ /replay/) n++} END {print n+0}')
      used=0; [ -s "$G/RUNS.tsv" ] && used=$(awk -F'\t' -v g="$goal" 'NR>1 && $2==g && $3=="page" && $10=="no-replay" {n++} END {print n+0}' "$G/RUNS.tsv")
      if [ "$harness" -lt 1 ]; then echo "REPLAY FAIL: --no-replay needs an active replay-harness lane in HANDOFF.md (a 'WIP: main | … replay … | running' line); none found"; bump FAIL
      elif [ "$used" -ge 2 ]; then echo "REPLAY FAIL: --no-replay already used for $used page runs of $goal (limit 2) — finish the replay harness first"; bump FAIL
      else echo "REPLAY WARN: no passing replay on this HEAD (last: ${res:-none} ${prog:-} ${rsha:0:10}); override $((used+1))/2, reason: $noreplay"; bump WARN; fi
    else echo "REPLAY FAIL: goal=$goal needs a whole-path replay PASS on ${sha:0:10} before a page run (last: ${res:-none} ${prog:-} ${rsha:0:10}). Run the replay, fix ALL its blockers, log it with log-run.sh."; bump FAIL; fi
    gc=$(bash "$here/goal-check.sh" "$G" 2>/dev/null | grep -E '^STUCK-CHECK' | head -1)
    case "$gc" in "STUCK-CHECK STUCK"*) echo "STUCK FAIL: $gc"; bump FAIL;; *) echo "STUCK OK: ${gc:-no ledger}";; esac
  fi
fi
echo "PREFLIGHT $worst kind=$kind tree=$tree sha=${sha:0:10}"
[ "$worst" = FAIL ] && exit 1 || exit 0
