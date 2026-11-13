#!/bin/bash
# usage: launch-lane.sh <out-dir> <wrapper> [wrapper args...]
# Starts a lane wrapper (run-codex.sh / run-claude.sh / run-zcode-review.sh / run-dsh.sh ...) detached, in its OWN
# session and process group (PGID == WRAPPER_PID, via perl POSIX::setsid), so kill-lane.sh can stop exactly this lane.
# Records WRAPPER_PID, WRAPPER_START (the PID's start time, for kill-lane.sh's PID-reuse check), LAUNCHED_UTC and
# CARD_PATH (the first wrapper argument that is an existing *.md file). Prints the PID.
# The card is linted with check-card.sh first; a failing card is refused (set LEGACY_CARD=1 to launch an old-format
# card anyway; the waiter then skips the report check).
# Refuses (exit 2, nothing written): missing arguments; an out dir that already holds a run's markers (a reused dir
# made a waiter report the OLD result as new); a failing card; and a `TRACK: side` card while goal-check.sh reports
# WIP OVER or STUCK for the goal dir that holds the out dir (set WIP_OVERRIDE="<reason>" to launch anyway; the reason
# is written to <out-dir>/WIP_OVERRIDE). Requires perl.
set -u
[ $# -ge 2 ] && [ -n "${1:-}" ] || { echo "usage: launch-lane.sh <out-dir> <wrapper> [args...]" >&2; exit 2; }
out="$1"; shift
for marker in WRAPPER_PID LAUNCHED_UTC STARTED_UTC FINISHED_UTC EXIT_CODE LAST-MESSAGE.md REVIEW.md .seen launcher.log; do
  [ ! -e "$out/$marker" ] || { echo "REFUSED: out-dir already used ($marker present): $out — pick a new one (e.g. ${out}-r2)" >&2; exit 2; }
done
command -v perl >/dev/null 2>&1 || { echo "REFUSED: perl is required (own process group via POSIX::setsid)" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
card=""
for a in "$@"; do case "$a" in *.md) [ -f "$a" ] && { card="$a"; break; };; esac; done
if [ -n "$card" ] && [ "${LEGACY_CARD:-0}" != 1 ]; then
  if ! res=$(bash "$here/check-card.sh" "$card"); then
    echo "REFUSED: $res (card $card). Fix the card, or LEGACY_CARD=1 for an old-format card." >&2; exit 2
  fi
fi
wipnote=""
if [ -n "$card" ] && grep -qiE '^[[:space:]]*TRACK:[[:space:]]*side' "$card"; then
  d="$out"; while [ ! -d "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do d=$(dirname "$d"); done
  d=$(cd "$d" 2>/dev/null && pwd); g=""
  for _ in 1 2 3 4 5 6 7 8; do [ -n "$d" ] && [ -f "$d/HANDOFF.md" ] && { g="$d"; break; }; [ "$d" = "/" ] && break; d=$(dirname "$d"); done
  if [ -n "$g" ]; then
    gc=$(bash "$here/goal-check.sh" "$g" 2>/dev/null | grep -E '^(WIP OVER|STUCK-CHECK STUCK)' | head -2)
    if [ -n "$gc" ]; then
      if [ -n "${WIP_OVERRIDE:-}" ]; then wipnote="WIP_OVERRIDE: ${WIP_OVERRIDE} | $gc"
      else echo "REFUSED: side lane while the goal needs attention: $gc" >&2
           echo "  Work the main goal first (references/UNSTUCK.md), park side work, or set WIP_OVERRIDE=\"<reason>\"." >&2; exit 2; fi
    fi
  fi
fi
mkdir -p "$out" || exit 2
[ -n "$wipnote" ] && printf '%s\n' "$wipnote" > "$out/WIP_OVERRIDE"
if [ -n "$card" ]; then
  echo "$(cd "$(dirname "$card")" && pwd)/$(basename "$card")" > "$out/CARD_PATH"
  [ "${LEGACY_CARD:-0}" = 1 ] && touch "$out/LEGACY_CARD"
fi
nohup perl -e 'use POSIX qw(setsid); setsid(); exec @ARGV or die "exec failed: $!\n"' "$@" >"$out/launcher.log" 2>&1 &
pid=$!
echo "$pid" > "$out/WRAPPER_PID"
LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null | sed 's/^ *//; s/ *$//' > "$out/WRAPPER_START"
date -u +%FT%TZ > "$out/LAUNCHED_UTC"
echo "$pid"
