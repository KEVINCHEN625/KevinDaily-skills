#!/bin/bash
# usage: check-report.sh <reply-file> [card.md]
# Lints a lane's final reply against the REPLY-CONTRACT (templates/TASK-CARD.md). Adapted from pstack (MIT):
# swarm "drop a result that does not record what its brief names", prove-it-works "truncated output and your own
# echo prove nothing", interrogate "a finding survives only when a run proves it".
# Prints REPORT-CHECK PASS or REPORT-CHECK FAIL: <problems>; exit 0 / 1. wait-lane.sh runs it automatically when the
# out dir has CARD_PATH (written by launch-lane.sh). A FAIL means: send the lane back with a full round-N card.
set -u
r="${1:-}"; card="${2:-}"
[ -n "$r" ] && [ -s "$r" ] || { echo "REPORT-CHECK FAIL: empty or missing reply '$r'"; exit 1; }
p=()
type=""
[ -n "$card" ] && [ -f "$card" ] && type=$(grep -iE '^[[:space:]]*CARD:' "$card" | head -1 | sed -E 's/^[[:space:]]*CARD:[[:space:]]*//I; s/[^a-zA-Z].*$//' | tr 'A-Z' 'a-z')
# strip markdown emphasis so **STATUS:** and `I1:` still count
txt=$(sed -E 's/\*\*//g; s/`//g; s/^([[:space:]]*)状态[:：]/\1STATUS: /; s/^([[:space:]]*)目标[:：]/\1GOAL: /; s/评审结束|审核结束/REVIEW-END/; s/STATUS: 通过/STATUS: APPROVE/; s/STATUS: 需要修改|STATUS: 要求修改/STATUS: REQUEST_CHANGES/; s/(I[0-9]+[:：][[:space:]]*)已完成/\1done/; s/(I[0-9]+[:：][[:space:]]*)跳过/\1skip/' "$r")
echo "$txt" | grep -qiE '^[[:space:]>#-]*STATUS:[[:space:]]*(READY-FOR-REVIEW|NEED-DECISION|NEED-RESTART|BLOCKED|REPORT|PLAN-READY|PASS|ISSUES|APPROVE|REQUEST_CHANGES)' \
  || p+=("STATUS line")
echo "$txt" | grep -qiE '^[[:space:]>#-]*GOAL:' || p+=("GOAL restated")
if [ -n "$card" ] && [ -f "$card" ]; then
  ids=$(sed -E 's/\*\*//g; s/`//g' "$card" | grep -oE '^[[:space:]]*-?[[:space:]]*I[0-9]+[:.)]' | grep -oE 'I[0-9]+' | sort -u)
  for id in $ids; do
    # explicit form only: "I<n>: done" or "I<n>: skip: <reason>" (also "| I<n> | done |"; 已完成/跳过 are mapped above).
    # "I<n>: not done", "I<n>: 未完成" and free text do not match.
    echo "$txt" | grep -qiE "(^|[[:space:]|(*-])$id[[:space:]]*([:.)|-]|：|—|–)+[[:space:]]*(done([^a-z]|$)|skip[[:space:]]*(:|：)[[:space:]]*[^[:space:]])" \
      || p+=("$id: done | skip: <reason>")
  done
fi
if [ "$type" = review ] || echo "$txt" | grep -qiE '^[[:space:]>#*-]*STATUS:[[:space:]]*(APPROVE|REQUEST_CHANGES)'; then
  # every finding F<n> needs a PROOF line before the next finding
  noproof=$(echo "$txt" | awk '
    /^[[:space:]>#*0-9.)-]*(Findings?:[[:space:]]*)?F[0-9]+[[:space:]]+P[0-3]/ { if (open) bad=bad" "cur; cur=""; if (match($0,/F[0-9]+[[:space:]]+P[0-3]/)) { cur=substr($0,RSTART,RLENGTH); sub(/[[:space:]].*$/,"",cur) }; open=($0 ~ /PROOF:/) ? 0 : 1; next }
    /PROOF:/ { open=0 }
    END { if (open) bad=bad" "cur; print bad }')
  [ -n "${noproof// /}" ] && p+=("PROOF for findings:$noproof")
  echo "$txt" | grep -qE 'REVIEW-END' || p+=("REVIEW-END")
  # exhaustive-review contract: a card that asks for COVERAGE gets a COVERAGE block (one line per path-matrix row)
  if [ -n "$card" ] && [ -f "$card" ] && grep -q 'COVERAGE' "$card"; then
    echo "$txt" | grep -qE '^[[:space:]>#*-]*COVERAGE:' || p+=("COVERAGE block")
  fi
else
  echo "$txt" | grep -qiE '^[[:space:]>#-]*EVIDENCE:' || p+=("EVIDENCE section")
  echo "$txt" | grep -qE '^[[:space:]]*\$[[:space:]]+[^[:space:]]' || p+=("EVIDENCE command lines (\$ <cmd>)")
  case "$type" in
    impl|fix) echo "$txt" | grep -qE '(^|[^A-Za-z])(RED|[Bb]efore[- ]fix|BEFORE)([^A-Za-z]|$)|修复前' || p+=("RED-before-fix output");;
  esac
  case "$type" in
    impl|fix|page|test) echo "$txt" | grep -qiE 'RESOURCE-HANDOFF' || p+=("RESOURCE-HANDOFF");;
  esac
fi
if [ ${#p[@]} -eq 0 ]; then echo "REPORT-CHECK PASS${type:+ type=$type}"; exit 0; fi
printf 'REPORT-CHECK FAIL%s missing: ' "${type:+ type=$type}"; (IFS='; '; echo "${p[*]}"); exit 1
