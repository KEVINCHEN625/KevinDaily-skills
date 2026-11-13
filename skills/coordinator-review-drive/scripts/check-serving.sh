#!/bin/bash
# usage: check-serving.sh <tree> <port> [port...]
# After every merge into an instance tree, and after every restart: prove which code each port is really serving
# (pstack prove-it-works: "read the real state ... a same-SHA restart lets old code report the new commit").
# Why: a dev proxy kept serving another tree's code for days, so a merged proxy fix was never live.
# Requires lsof and git. Works with BSD (macOS) and GNU (Linux) ps/date.
# Per port prints: pid, start time, cwd, command, and a verdict:
#   OK            cwd inside <tree> and started after the tree's last HEAD update
#   STARTED-BEFORE-HEAD  cwd inside <tree> but started before the last HEAD update (fine only for auto-reloading
#                 children or when the merge did not touch its code; otherwise restart it)
#   OUTSIDE-TREE  serving code from another directory -> restart it from <tree>
#   NOT-LISTENING nothing on that port
# Last line: SERVING-CHECK PASS | WARN | FAIL. Always exits 0. Read-only.
set -u
tree="${1:-}"; shift || true
[ -n "$tree" ] && [ -d "$tree" ] && [ $# -ge 1 ] || { echo "usage: check-serving.sh <tree> <port>..."; exit 0; }
command -v lsof >/dev/null 2>&1 || { echo "SERVING-CHECK FAIL: lsof is required"; exit 0; }
tree=$(cd "$tree" && pwd -P)
head_ts=$(git -C "$tree" reflog show -1 --date=unix --format=%gd HEAD 2>/dev/null | grep -oE '[0-9]{9,}' | head -1)
[ -n "$head_ts" ] || head_ts=$(git -C "$tree" log -1 --format=%ct 2>/dev/null || echo 0)
echo "tree=$tree head=$(git -C "$tree" rev-parse --short HEAD 2>/dev/null) head_updated=$(date -r "$head_ts" '+%F %T' 2>/dev/null || date -d "@$head_ts" '+%F %T' 2>/dev/null || echo "$head_ts")"
worst=PASS
for port in "$@"; do
  pid=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -1)
  if [ -z "$pid" ]; then echo "port $port: NOT-LISTENING"; worst=FAIL; continue; fi
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
  # LC_ALL=C: in a non-English locale `ps -o lstart` prints localised day/month names that `date -f` cannot parse;
  # start_ts then became 0 and every process looked STARTED-BEFORE-HEAD.
  start=$(LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^ *//')
  start_ts=$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$start" +%s 2>/dev/null || LC_ALL=C date -d "$start" +%s 2>/dev/null || echo 0)
  cmd=$(ps -o args= -p "$pid" 2>/dev/null | cut -c1-160)
  case "$cwd/" in
    "$tree"/*) if [ "$start_ts" -eq 0 ]; then v=START-TIME-UNKNOWN; [ $worst = PASS ] && worst=WARN
               elif [ "$start_ts" -ge "$head_ts" ]; then v=OK; else v=STARTED-BEFORE-HEAD; [ $worst = PASS ] && worst=WARN; fi;;
    *) v=OUTSIDE-TREE; worst=FAIL;;
  esac
  echo "port $port: $v pid=$pid started='$start' cwd=$cwd cmd=$cmd"
done
echo "SERVING-CHECK $worst"
exit 0
