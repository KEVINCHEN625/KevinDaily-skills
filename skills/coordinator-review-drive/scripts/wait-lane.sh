#!/bin/bash
# usage: wait-lane.sh <out-dir> [--stall SEC] [--max SEC] [--poll SEC] [--output FILE]
#        wait-lane.sh --pid PID --log FILE [--stall SEC] [--max SEC] [--poll SEC]   (long-running loops)
#
# One reliable waiter per detached lane. Run it with the harness's background mode
# (run_in_background) — never with nohup/& — so the coordinator is notified when it exits.
# It ALWAYS exits 0; the FIRST output line is the verdict:
#   LANE DONE exit=<rc> output=<ok|EMPTY|MISSING>   wrapper finished (FINISHED_UTC written)
#   LANE DIED                                         wrapper process gone, no FINISHED_UTC
#   LANE STALL idle=<s>s                              no file in the out-dir changed for --stall seconds
#   LANE TIMEOUT still-running                        --max reached; the lane is still alive — re-arm a waiter
#   PID EXITED / PID STALL / PID TIMEOUT              the --pid form
#   LANE USAGE-ERROR ...                              bad arguments or a missing out dir (reported at once)
# When the lane was started by launch-lane.sh with a linted card (CARD_PATH present, no LEGACY_CARD), the second line
# is the reply check: REPORT-CHECK PASS|FAIL (check-report.sh). FAIL = not accepted, whatever the first line says.
# Then known error signatures found in the logs and the tail of the output.
# Design rules (lessons from missed reports): no shell globs, no unanchored `pgrep -f`
# (it matches the waiter's own command line), liveness from a recorded PID, stall from
# the newest mtime of ANY file in the out-dir (falls back to the launch time when no log exists).
set -u
stall=2400; max=21600; poll=30; out=""; output=""; pid=""; log=""
while [ $# -gt 0 ]; do
  case "$1" in --stall|--max|--poll|--output|--pid|--log)
    [ $# -ge 2 ] || { echo "LANE USAGE-ERROR $1 needs a value"; exit 0; };; esac
  case "$1" in
    --stall) stall="$2"; shift 2;;
    --max) max="$2"; shift 2;;
    --poll) poll="$2"; shift 2;;
    --output) output="$2"; shift 2;;
    --pid) pid="$2"; shift 2;;
    --log) log="$2"; shift 2;;
    *) if [ -z "$out" ]; then out="$1"; elif [[ "$1" =~ ^[0-9]+$ ]]; then poll="$1"; fi; shift;;  # legacy: wait-lane.sh <out-dir> [poll-seconds]
  esac
done
case "$stall$max$poll" in *[!0-9]*|"") echo "LANE USAGE-ERROR --stall/--max/--poll need numbers"; exit 0;; esac
now() { date +%s; }
mtime() {  # GNU first: GNU `stat -f` can emit filesystem text even when it fails.
  local stamp
  stamp=$(stat -c %Y "$1" 2>/dev/null) || stamp=$(stat -f %m "$1" 2>/dev/null) || stamp=0
  [[ "$stamp" =~ ^[0-9]+$ ]] || stamp=0
  echo "$stamp"
}
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
newest_in() {  # newest mtime of any regular file under $1 (0 if none)
  local n=0 m f
  while IFS= read -r -d '' f; do m=$(mtime "$f"); [ "$m" -gt "$n" ] && n=$m; done < <(find "$1" -type f -print0 2>/dev/null)
  echo "$n"
}
signatures() {  # known failure signatures in the given files
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    grep -a -h -o -E "at capacity|model_not_found|not supported when using Codex|\"type\":\"500\"|系统异常|Rate limit|429|quota|Traceback \(most recent call last\)|No such file or directory|permission denied|Operation not permitted|no matches found" "$f" 2>/dev/null | sort | uniq -c | head -8
  done
}
start=$(now)

if [ -n "$pid" ]; then
  while :; do
    if ! alive "$pid"; then echo "PID EXITED pid=$pid"; break; fi
    if [ -n "$log" ]; then
      last=$(mtime "$log"); [ "$last" -eq 0 ] && last=$start
      idle=$(( $(now) - last )); [ "$idle" -gt "$stall" ] && { echo "PID STALL idle=${idle}s pid=$pid (still alive)"; break; }
    fi
    [ $(( $(now) - start )) -gt "$max" ] && { echo "PID TIMEOUT still-running pid=$pid — re-arm a waiter"; break; }
    sleep "$poll"
  done
  [ -n "$log" ] && { signatures "$log"; echo "--- tail $log"; tail -n 12 "$log" | cut -c1-400; }
  exit 0
fi

[ -n "$out" ] || { echo "LANE USAGE-ERROR no out-dir"; exit 0; }
# a mistyped out dir used to wait the whole --stall time and then report STALL
[ -d "$out" ] || { echo "LANE USAGE-ERROR out-dir does not exist: $out"; exit 0; }
launched=$(mtime "$out/LAUNCHED_UTC"); [ "$launched" -eq 0 ] && launched=$start
wpid=""; [ -f "$out/WRAPPER_PID" ] && wpid=$(cat "$out/WRAPPER_PID")
[ -n "$wpid" ] || { [ ! -f "$out/PID" ] || wpid=$(cat "$out/PID"); }
verdict=""
while :; do
  if [ -f "$out/FINISHED_UTC" ]; then
    rc=$(cat "$out/EXIT_CODE" 2>/dev/null || echo "?")
    if [ -z "$output" ]; then
      for c in LAST-MESSAGE.md REVIEW.md RESULT.md; do [ -f "$out/$c" ] && { output="$out/$c"; break; }; done
    fi
    st=MISSING; [ -n "$output" ] && [ -f "$output" ] && { [ -s "$output" ] && st=ok || st=EMPTY; }
    verdict="LANE DONE exit=$rc output=$st"; break
  fi
  if [ -n "$wpid" ] && ! alive "$wpid"; then
    sleep 3; [ -f "$out/FINISHED_UTC" ] && continue
    verdict="LANE DIED wrapper pid=$wpid gone without FINISHED_UTC"; break
  fi
  last=$(newest_in "$out"); [ "$last" -lt "$launched" ] && last=$launched
  idle=$(( $(now) - last ))
  [ "$idle" -gt "$stall" ] && { verdict="LANE STALL idle=${idle}s (wrapper ${wpid:-unknown} $(alive "$wpid" && echo alive || echo unknown))"; break; }
  [ $(( $(now) - start )) -gt "$max" ] && { verdict="LANE TIMEOUT still-running — re-arm a waiter"; break; }
  sleep "$poll"
done
echo "$verdict  dir=$out"
# REPLY-CONTRACT check (check-report.sh) when the lane was launched with a linted card
if [ -n "$output" ] && [ -f "$out/CARD_PATH" ] && [ ! -f "$out/LEGACY_CARD" ]; then
  bash "$(cd "$(dirname "$0")" && pwd)/check-report.sh" "$output" "$(cat "$out/CARD_PATH")" 2>/dev/null | head -1
fi
logs=(); while IFS= read -r -d '' f; do logs+=("$f"); done < <(find "$out" -maxdepth 1 -type f \( -name '*.log' -o -name 'LAST-MESSAGE.md' -o -name 'REVIEW.md' \) -print0 2>/dev/null)
[ ${#logs[@]} -gt 0 ] && signatures "${logs[@]}"
if [ -n "$output" ] && [ -s "$output" ]; then echo "--- tail $output"; tail -c 2500 "$output"; else
  # bash 3.2 + set -u: expanding an empty array aborts, so guard it (the waiter must always exit 0)
  if [ ${#logs[@]} -gt 0 ]; then for f in "${logs[@]}"; do echo "--- tail $f"; tail -n 6 "$f" | cut -c1-400; done; fi; fi
exit 0
