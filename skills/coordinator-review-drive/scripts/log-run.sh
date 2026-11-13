#!/bin/bash
# usage: log-run.sh <G> <goal-id> <page|replay|gate> <sha> <reached> <target> <PASS|FAIL> <evidence-path> [blocker...]
#        log-run.sh <G> <goal-id> unstuck <unstuck-record.md>
# Appends ONE row to G/RUNS.tsv, the run ledger that goal-check.sh reads to detect "stuck" and preflight-run.sh reads
# to demand a passing whole-path replay before a page run. Log every replay, page and gate run, pass or fail.
#   reached/target  progress on the goal's own scale (e.g. 9 11 = 9 of 11 layers adopted). PASS needs reached == target.
#   blocker...      one short stable signature per blocker found in this run (ALL of them, from the page AND the logs)
#   unstuck         records that the unstuck protocol was done; the record file must hold the six headings of
#                   templates/UNSTUCK-RECORD.md.
# Adapted from pstack (MIT) show-me-your-work: one row per iteration with an evidence pointer and the predicate state.
# Exit 0 = row appended; 1 = refused (nothing written); 2 = usage.
set -u
G="${1:-}"; goal="${2:-}"; kind="${3:-}"
[ -n "$G" ] && [ -d "$G" ] || { echo "LOG-RUN REFUSED: no goal dir '$G'"; exit 1; }
case "$goal" in ""|*[!A-Za-z0-9._-]*) echo "LOG-RUN REFUSED: goal id must be [A-Za-z0-9._-]+: '$goal'"; exit 1;; esac
clean() { printf '%s' "$1" | tr '\t\n\r' '   ' | cut -c1-200; }
ledger="$G/RUNS.tsv"
utc=$(date -u +%FT%TZ)
case "$kind" in
  unstuck)
    rec="${4:-}"
    [ -n "$rec" ] && [ -s "$rec" ] || { echo "LOG-RUN REFUSED: unstuck record missing or empty: '$rec'"; exit 1; }
    miss=""
    for h in 'Blockers' 'Forecast' 'Premise' 'Replay' 'WIP' 'Escalation'; do
      grep -qiE "^##+[[:space:]]*[0-9.]*[[:space:]]*$h" "$rec" || miss="$miss $h"
    done
    [ -z "$miss" ] || { echo "LOG-RUN REFUSED: unstuck record lacks heading(s):$miss (see templates/UNSTUCK-RECORD.md)"; exit 1; }
    grep -q '<fill' "$rec" && { echo "LOG-RUN REFUSED: unstuck record still has <fill…> placeholders"; exit 1; }
    row="$utc	$goal	unstuck	-	-	-	RECORD	-	$(clean "$rec")	-";;
  page|replay|gate)
    [ $# -ge 8 ] || { echo "LOG-RUN usage: log-run.sh <G> <goal> $kind <sha> <reached> <target> <PASS|FAIL> <evidence> [blocker...]" >&2; exit 2; }
    sha="$4"; reached="$5"; target="$6"; result="$7"; ev="$8"; shift 8
    case "$sha" in ""|*[!0-9a-fA-F]*) echo "LOG-RUN REFUSED: sha must be hex (the build that ran): '$sha'"; exit 1;; esac
    [ ${#sha} -ge 7 ] || { echo "LOG-RUN REFUSED: sha needs >= 7 hex chars"; exit 1; }
    case "$reached$target" in ""|*[!0-9]*) echo "LOG-RUN REFUSED: reached/target must be integers"; exit 1;; esac
    [ "$target" -gt 0 ] && [ "$reached" -le "$target" ] || { echo "LOG-RUN REFUSED: need 0 <= reached <= target, target > 0"; exit 1; }
    case "$result" in PASS|FAIL) ;; *) echo "LOG-RUN REFUSED: result must be PASS or FAIL"; exit 1;; esac
    [ "$result" = PASS ] && [ "$reached" != "$target" ] && { echo "LOG-RUN REFUSED: PASS needs reached == target ($reached/$target)"; exit 1; }
    [ "$result" = FAIL ] && [ $# -eq 0 ] && { echo "LOG-RUN REFUSED: a FAIL row needs at least one blocker signature"; exit 1; }
    [ -n "$ev" ] && [ -e "$ev" ] || { echo "LOG-RUN REFUSED: evidence path does not exist: '$ev'"; exit 1; }
    bl=""; for b in "$@"; do b=$(clean "$b" | tr ';' ','); [ -n "$b" ] && bl="${bl:+$bl; }$b"; done
    # column 10: a page run on a build with no earlier passing replay of this goal is recorded as "no-replay"
    flag="-"
    if [ "$kind" = page ]; then
      flag="no-replay"
      [ -s "$ledger" ] && awk -F'\t' -v g="$goal" -v s="$sha" 'NR>1 && $2==g && $3=="replay" && $7=="PASS" && (index($4,s)==1 || index(s,$4)==1) {f=1} END {exit f?0:1}' "$ledger" && flag="-"
    fi
    row="$utc	$goal	$kind	$sha	$reached	$target	$result	${bl:--}	$(clean "$ev")	$flag";;
  *) echo "LOG-RUN usage: kind must be page|replay|gate|unstuck (got '$kind')" >&2; exit 2;;
esac
[ -s "$ledger" ] || printf 'utc\tgoal\tkind\tsha\treached\ttarget\tresult\tblockers\tevidence\tflags\n' > "$ledger"
printf '%s\n' "$row" >> "$ledger" && echo "LOG-RUN ok: $row"
