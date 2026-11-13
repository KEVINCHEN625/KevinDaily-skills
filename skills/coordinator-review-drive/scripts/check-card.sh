#!/bin/bash
# usage: check-card.sh <card.md>
# Lints a task card before dispatch (pstack Orchestrate: "each kickoff names the evidence that proves the work is
# done ... if you can't name the evidence, the unit isn't scoped yet"). Prints CARD-CHECK PASS or
# CARD-CHECK FAIL: <missing...>; exit 0 on PASS, 1 on FAIL. launch-lane.sh calls it and refuses a failing card.
#
# Required lines (at line start):
#   CARD: impl|fix|review|page|test|research|plan|other
#   GOAL:            the user's goal in one or two lines (not the task steps)
#   TRACK: main|side main = on the path to the MAIN-GOAL of G/HANDOFF.md; side = everything else (WIP-limited:
#                    launch-lane.sh refuses a side lane while goal-check.sh reports WIP OVER or STUCK)
#   ITEMS:           followed by numbered items I1:, I2:, ...   (the reply must answer each id)
#   REPLY-CONTRACT   the standard reply block from templates/TASK-CARD.md
# Extra by type:
#   impl|fix|page|test: DONE-EVIDENCE: (behaviour the user would observe + the command/page scenario that shows it)
#   impl|fix|page:      SCOPE: (paths it may write)   FORBIDDEN: (paths/actions it must not touch)
#   review:             REVIEW-SHA: <7-40 hex>        (findings are judged at this commit only)
# A FORBIDDEN-TESTS.txt in the card's directory or any parent (up to 8 levels) lists test paths that must never run;
# impl|fix|test cards must name each of them.
set -u
card="${1:-}"
[ -n "$card" ] && [ -f "$card" ] || { echo "CARD-CHECK FAIL: no card file '$card'"; exit 1; }
miss=()
head_part=$(awk '/REPLY-CONTRACT/{exit} {print}' "$card")
has() { echo "$head_part" | grep -qiE "^[[:space:]]*$1"; }
type=$(grep -iE '^[[:space:]]*CARD:' "$card" | head -1 | sed -E 's/^[[:space:]]*CARD:[[:space:]]*//I; s/[^a-zA-Z].*$//' | tr 'A-Z' 'a-z')
case "$type" in impl|fix|review|page|test|research|plan|other) ;; *) miss+=("CARD: <impl|fix|review|page|test|research|plan|other> (got '${type:-none}')");; esac
has 'GOAL:' || miss+=("GOAL:")
echo "$head_part" | grep -qiE '^[[:space:]]*TRACK:[[:space:]]*(main|side)([^a-z]|$)' || miss+=("TRACK: main|side")
has 'ITEMS:' || miss+=("ITEMS:")
echo "$head_part" | grep -qE '^[[:space:]]*-?[[:space:]]*I1[:.)]' || miss+=("item I1: (before REPLY-CONTRACT)")
grep -q 'REPLY-CONTRACT' "$card" || miss+=("REPLY-CONTRACT block")
case "$type" in
  impl|fix|page|test) has 'DONE-EVIDENCE:' || miss+=("DONE-EVIDENCE:");;
esac
case "$type" in
  impl|fix|page) has 'SCOPE:' || miss+=("SCOPE:"); has 'FORBIDDEN:' || miss+=("FORBIDDEN:");;
  review) grep -qiE '^[[:space:]]*(REVIEW-SHA:[[:space:]]*[0-9a-f]{7,40}|REVIEW-TARGET:[[:space:]]*[^[:space:]])' "$card"             || miss+=("REVIEW-SHA: <sha> (or REVIEW-TARGET: <path> sha256 <digest> outside git)");;
esac
case "$type" in
  impl|fix|test)
    d=$(cd "$(dirname "$card")" && pwd); ff=""
    for _ in 1 2 3 4 5 6 7 8; do [ -f "$d/FORBIDDEN-TESTS.txt" ] && { ff="$d/FORBIDDEN-TESTS.txt"; break; }; d=$(dirname "$d"); done
    if [ -n "$ff" ]; then
      while IFS= read -r t; do
        t="${t%%#*}"; t="$(echo "$t" | tr -d '[:space:]')"; [ -n "$t" ] || continue
        grep -qF "$(basename "$t")" "$card" || miss+=("forbidden test not named: $t")
      done < "$ff"
    fi;;
esac
if [ ${#miss[@]} -eq 0 ]; then echo "CARD-CHECK PASS type=$type"; exit 0; fi
printf 'CARD-CHECK FAIL type=%s missing: ' "${type:-?}"; (IFS='; '; echo "${miss[*]}"); exit 1
