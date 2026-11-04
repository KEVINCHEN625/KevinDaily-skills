#!/bin/bash
# usage: launch-lane.sh <out-dir> <wrapper> [wrapper args...]
# Starts a lane wrapper (run-codex.sh / run-claude.sh / run-zcode-review.sh / run-dsh.sh ...)
# detached, and records its PID in <out-dir>/WRAPPER_PID so wait-lane.sh can tell
# "still running" from "died without writing FINISHED_UTC". Prints the PID.
set -u
[ $# -ge 2 ] || { echo "usage: launch-lane.sh <out-dir> <wrapper> [args...]" >&2; exit 2; }
out="$1"; shift
for marker in WRAPPER_PID LAUNCHED_UTC STARTED_UTC FINISHED_UTC EXIT_CODE LAST-MESSAGE.md REVIEW.md .seen launcher.log; do
  [ ! -e "$out/$marker" ] || { echo "REFUSED: out-dir already used ($marker present): $out" >&2; exit 2; }
done
mkdir -p "$out" || exit 2
nohup "$@" >"$out/launcher.log" 2>&1 &
pid=$!
echo "$pid" > "$out/WRAPPER_PID"
date -u +%FT%TZ > "$out/LAUNCHED_UTC"
echo "$pid"
