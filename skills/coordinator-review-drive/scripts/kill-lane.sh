#!/bin/bash
# usage: kill-lane.sh <out-dir>
# Stops ONE lane: its own process group only (launch-lane.sh starts each lane in a new session, so its PGID equals
# WRAPPER_PID). Refuses when the lane does not own its group (legacy launch) or the group is the caller's own.
# Also refuses when the PID's start time differs from WRAPPER_START (recorded by launch-lane.sh): a recycled PID.
# Why: a process-group kill of one lane once killed three sibling lanes that shared the coordinator's PGID.
set -u
out="${1:-}"
[ -n "$out" ] && [ -f "$out/WRAPPER_PID" ] || { echo "KILL-LANE REFUSED: no $out/WRAPPER_PID"; exit 1; }
pid=$(cat "$out/WRAPPER_PID")
[[ "$pid" =~ ^[0-9]+$ ]] || { echo "KILL-LANE REFUSED: bad pid '$pid'"; exit 1; }
kill -0 "$pid" 2>/dev/null || { echo "KILL-LANE: pid $pid already gone"; exit 0; }
if [ -s "$out/WRAPPER_START" ]; then
  want=$(cat "$out/WRAPPER_START"); have=$(LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^ *//; s/ *$//')
  [ "$want" = "$have" ] || { echo "KILL-LANE REFUSED: pid $pid started '$have', the lane's wrapper started '$want' — the PID was reused; the lane is gone"; exit 1; }
else
  echo "KILL-LANE note: no WRAPPER_START in $out (lane launched by an older launch-lane.sh); PID reuse cannot be ruled out"
fi
pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')
mine=$(ps -o pgid= -p $$ | tr -d ' ')
if [ "$pgid" != "$pid" ] || [ "$pgid" = "$mine" ]; then
  echo "KILL-LANE REFUSED: lane pid $pid is not its own group leader (pgid $pgid, caller pgid $mine)."
  echo "  Kill its process tree instead: pstree/ps -o pid,ppid to list children of $pid, then kill those exact PIDs."
  exit 1
fi
kill -TERM -- "-$pgid" 2>/dev/null; for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$pgid" 2>/dev/null || break; sleep 1; done
kill -0 -- "-$pgid" 2>/dev/null && kill -KILL -- "-$pgid" 2>/dev/null
date -u +%FT%TZ > "$out/KILLED_UTC"
echo "KILL-LANE done pgid=$pgid"
