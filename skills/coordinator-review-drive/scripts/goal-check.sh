#!/bin/bash
# usage: goal-check.sh <G> [--stall-hours 12] [--max-side 2] [--max-total 6] [--handoff-max-age-hours 6]
#                          [--memory <MEMORY.md index>] [--now <epoch>]
# The ONE command of every coordinator wake-up (start, resume, after compaction, heartbeat, lane notification).
# Read-only. Prints one verdict line per check, then "GOAL-CHECK PASS" or "GOAL-CHECK ATTENTION n". Exit 0 / 1.
#   HANDOFF      G/HANDOFF.md exists, has MAIN-GOAL / PREDICATE / PROGRESS / ENV / NEXT / WIP lines, no <placeholders>
#                in them, and is fresh (state that only lives in the conversation is lost at compaction).
#   WIP          "WIP: <main|side> | <id> | <what> | <running|review|queued|parked|done> | <where>" lines: active side
#                items <= --max-side, all active <= --max-total, and the main track is not idle while side work runs.
#   STUCK-CHECK  from G/RUNS.tsv (log-run.sh): STUCK when the main goal has 2 failed page runs since the last unstuck
#                record, or its best progress did not advance for --stall-hours, or one blocker shows in >= 3 runs since the last
#                unstuck record. Only an unstuck record resets these counters (a passing page run ends the goal: MET);
#                a replay or gate PASS does not.
#                STUCK means: do references/UNSTUCK.md now; preflight-run.sh refuses the next page run until then.
#   RULES        size budgets: SKILL.md 16 KB, G/AGENT-LESSONS.md 24 KB, G/ALLOCATION.md 8 KB, G/HANDOFF.md 6 KB; with
#                --memory: at most 60 index entries, none marked SUPERSEDED/DONE. Over budget = prune (references/STATE.md).
# Ideas adapted (MIT): pstack autonomous-run ("state the exit condition as a checkable predicate"; "a plateau is not a
# stop … pivot"), attack-the-premise, correct ("drop a rule once its mistake can't happen"); Matt Pocock chief-of-staff
# (wiki "lint": superseded claims), handoff.
set -u
G="${1:-}"; [ $# -ge 1 ] && shift
stall=12; maxside=2; maxtotal=6; maxage=6; memory=""; now=$(date +%s)
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || { echo "GOAL-CHECK usage: $1 needs a value" >&2; exit 2; }   # every option here takes a value
  case "$1" in
    --stall-hours) stall="${2:-}"; shift 2;;
    --max-side) maxside="${2:-}"; shift 2;;
    --max-total) maxtotal="${2:-}"; shift 2;;
    --handoff-max-age-hours) maxage="${2:-}"; shift 2;;
    --memory) memory="${2:-}"; shift 2;;
    --now) now="${2:-}"; shift 2;;
    *) echo "GOAL-CHECK usage: unknown argument $1" >&2; exit 2;;
  esac
done
case "$stall$maxside$maxtotal$maxage$now" in *[!0-9]*|"") echo "GOAL-CHECK usage: numeric options expected" >&2; exit 2;; esac
[ -n "$G" ] && [ -d "$G" ] || { echo "GOAL-CHECK usage: goal-check.sh <G> [options] (no goal dir '$G')" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
att=0
mtime() {  # GNU first: GNU `stat -f` can print filesystem text even when it fails.
  local s; s=$(stat -c %Y "$1" 2>/dev/null) || s=$(stat -f %m "$1" 2>/dev/null) || s=0
  case "$s" in ""|*[!0-9]*) s=0;; esac; echo "$s"; }
epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null || echo 0; }
size() { wc -c < "$1" 2>/dev/null | tr -d ' '; }

# ---- HANDOFF
H="$G/HANDOFF.md"; goal=""
if [ ! -s "$H" ]; then
  echo "HANDOFF MISSING: write $H from templates/HANDOFF.md before anything else"; att=$((att+1))
else
  miss=""
  for k in MAIN-GOAL PREDICATE PROGRESS ENV NEXT WIP; do
    l=$(grep -E "^$k:" "$H" | head -1)
    if [ -z "$l" ]; then miss="$miss $k"; elif printf '%s' "$l" | grep -qE '<[A-Za-z][^<>]*>'; then miss="$miss $k(placeholder)"; fi
  done
  goal=$(grep -E '^MAIN-GOAL:' "$H" | head -1 | sed -E 's/^MAIN-GOAL:[[:space:]]*//' | awk '{print $1}')
  case "$goal" in *[!A-Za-z0-9._-]*) goal="";; esac
  age=$(( (now - $(mtime "$H")) / 3600 ))
  if [ -n "$miss" ]; then echo "HANDOFF INCOMPLETE: missing$miss"; att=$((att+1))
  elif [ "$age" -ge "$maxage" ]; then echo "HANDOFF STALE: last written ${age}h ago (limit ${maxage}h) — rewrite it from the real state now"; att=$((att+1))
  else echo "HANDOFF OK: goal=$goal age=${age}h"; fi
fi

# ---- STUCK (before WIP: the WIP verdict depends on it)
L="$G/RUNS.tsv"; stuck=0; met=0
if [ -z "$goal" ]; then
  echo "STUCK-CHECK SKIPPED: no MAIN-GOAL id in HANDOFF.md"
elif [ ! -s "$L" ] || ! awk -F'\t' -v g="$goal" 'NR>1 && $2==g {f=1} END {exit f?0:1}' "$L"; then
  echo "STUCK-CHECK NO-RUNS: goal=$goal has no rows in RUNS.tsv — the detector is blind until runs are logged (log-run.sh)"
else
  # shellcheck disable=SC2034
  read -r best target tbest tun failed nun met repeat lastutc <<EOF2
$(awk -F'\t' -v g="$goal" '
    NR==1 || $2!=g { next }
    { last=$1 }
    $3=="unstuck" { tun=$1; failed=0; nun++; split("", c); next }
    $3=="page" || $3=="replay" {
      r=$5+0; if (!seen || r>best) { best=r; tbest=$1; seen=1; nun=0 }
      target=$6
      if ($3=="page" && $7=="PASS") met=1
      if ($3=="page" && $7=="FAIL") failed++
      if ($8!="-" && $8!="") { n=split($8, b, /; */); for (i=1;i<=n;i++) if (b[i]!="") c[b[i]]++ }
    }
    END {
      rep="-"; for (k in c) if (c[k]>=3) { gsub(/[ \t]+/,"_",k); rep=k; break }
      printf "%d %s %s %s %d %d %d %s %s\n", best, (target==""?"?":target), (tbest==""?"-":tbest), (tun==""?"-":tun), failed, nun, met, rep, last
    }' "$L")
EOF2
  if [ "${met:-0}" = 1 ]; then
    echo "STUCK-CHECK MET: goal=$goal has a passing page run — move the main goal on (update HANDOFF.md)"
  else
    ref=$(epoch "$tbest"); if [ "$tun" != "-" ]; then u=$(epoch "$tun"); [ "$u" -gt "$ref" ] && ref=$u; fi
    hrs=$(( (now - ref) / 3600 )); why=""
    [ "${failed:-0}" -ge 2 ] && why="$why; $failed failed page runs since the last unstuck record"
    [ "$ref" -gt 0 ] && [ "$hrs" -ge "$stall" ] && why="$why; best progress $best/$target not advanced for ${hrs}h (limit ${stall}h)"
    [ "$repeat" != "-" ] && why="$why; blocker '$repeat' seen in >= 3 runs (attack the premise)"
    if [ -n "$why" ]; then
      stuck=1; att=$((att+1))
      esc=""; [ "${nun:-0}" -ge 2 ] && esc=" ESCALATE: $nun unstuck rounds without progress — give the user the facts and 2-3 options"
      echo "STUCK-CHECK STUCK: goal=$goal best=$best/$target${why}.$esc"
      echo "  -> do references/UNSTUCK.md now (all logs, forecast, premise, whole-path replay, WIP cut), then: log-run.sh <G> $goal unstuck <record>"
    else
      echo "STUCK-CHECK OK: goal=$goal best=$best/$target last-advance=${hrs}h ago failed-page-runs=${failed:-0}"
    fi
  fi
fi

# ---- WIP
if [ -s "$H" ]; then
  read -r am as queued parked bad <<EOF2
$(grep -E '^WIP:' "$H" | awk -F'|' '
    { t=$1; sub(/^WIP:[ \t]*/,"",t); gsub(/[ \t]/,"",t); s=$4; gsub(/[ \t]/,"",s); s=tolower(s); t=tolower(t)
      if (t!="main" && t!="side") { bad++; next }
      if (s=="running" || s=="review") { if (t=="main") am++; else as++ }
      else if (s=="queued") q++; else if (s=="parked" || s=="done") p++; else bad++ }
    END { printf "%d %d %d %d %d\n", am, as, q, p, bad }')
EOF2
  am=${am:-0}; as=${as:-0}; bad=${bad:-0}
  w=""
  [ "$bad" -gt 0 ] && w="$w; $bad malformed WIP line(s) (WIP: main|side | id | what | running|review|queued|parked|done | where)"
  [ "$as" -gt "$maxside" ] && w="$w; side active $as > $maxside — park or finish side work"
  [ $((am+as)) -gt "$maxtotal" ] && w="$w; active $((am+as)) > $maxtotal"
  [ "$met" != 1 ] && [ "$am" -eq 0 ] && [ "$as" -gt 0 ] && w="$w; MAIN-STARVED — $as side item(s) active, nothing active on the main goal"
  [ "$stuck" = 1 ] && [ "$as" -gt 0 ] && w="$w; WIP-FREEZE — stuck: start no side lane, park what can be parked"
  if [ -n "$w" ]; then echo "WIP OVER: main=$am side=$as${w}"; att=$((att+1)); else echo "WIP OK: main=$am side=$as queued=${queued:-0} parked/done=${parked:-0}"; fi
fi

# ---- RULES budget
r=""
budget() { [ -f "$1" ] || return 0; s=$(size "$1"); [ "${s:-0}" -gt "$2" ] && r="$r; $(basename "$1") ${s}B > ${2}B"; return 0; }
budget "$here/../SKILL.md" 16000; budget "$G/AGENT-LESSONS.md" 24000; budget "$G/ALLOCATION.md" 8000; budget "$G/HANDOFF.md" 6000
if [ -n "$memory" ]; then
  if [ -f "$memory" ]; then
    n=$(grep -cE '^[[:space:]]*- ' "$memory"); st=$(grep -cE 'SUPERSEDED|superseded|DONE' "$memory")
    [ "$n" -gt 60 ] && r="$r; memory index $n entries > 60"
    [ "$st" -gt 0 ] && r="$r; $st memory entries marked SUPERSEDED/DONE still indexed"
  else r="$r; memory index not found: $memory"; fi
fi
if [ -n "$r" ]; then echo "RULES OVER:${r#;} — prune per references/STATE.md §4"; att=$((att+1)); else echo "RULES OK"; fi

if [ "$att" -eq 0 ]; then echo "GOAL-CHECK PASS"; exit 0; fi
echo "GOAL-CHECK ATTENTION $att"; exit 1
