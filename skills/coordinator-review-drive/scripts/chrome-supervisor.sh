#!/bin/zsh
# chrome-supervisor.sh — keep ONE shared headless Chrome alive for web-tester lanes (coordinator-review-drive).
#
# usage: chrome-supervisor.sh <port> <profile-dir> [chrome-binary]
#   Checks http://127.0.0.1:<port>/json/version every CRD_CHROME_CHECK_SECONDS (default 15, 10 s timeout).
#   Only after 3 CONSECUTIVE failures does it stop the Chrome that owns <profile-dir> (TERM, then KILL), remove stale
#   Singleton* locks in <profile-dir> ONLY and start one headless Chrome. It gives up (exit 1, no new Chrome) after
#   3 restarts in 10 minutes. A lock dir <profile-dir>.supervisor.lock allows only one supervisor per profile.
#   Why: an earlier version started a NEW Chrome on every failed check without stopping the old one; under load it
#   stacked Chromes until memory ran out and the OS reaper killed every background lane.
#   Writes its PID to <profile-dir>.supervisor.pid and logs to ${CRD_CHROME_LOG:-<profile-dir>.supervisor.log}.
#
# Start it DETACHED, or it dies with the tool shell (double fork):
#   ( nohup zsh $SKILL/scripts/chrome-supervisor.sh 9333 <G>/browser/profile >/dev/null 2>&1 & )
# Stop it at goal close (it is a long-lived shared service, not a lane resource):
#   kill "$(cat <profile-dir>.supervisor.pid)"   # then stop Chrome by its listening PID: lsof -ti tcp:<port> -sTCP:LISTEN
#
# Testers must never close, kill or restart this browser; they open and close only their own tabs (≤ 3 each).
# The profile is a dedicated test profile: never point it at the user's real Chrome profile.
set -u
zmodload zsh/datetime
(( $# == 2 || $# == 3 )) || { print -u2 "usage: chrome-supervisor.sh <port> <profile-dir> [chrome-binary]"; exit 2; }
PORT=$1; PROFILE=${2:A}
[[ $PORT =~ '^[0-9]+$' ]] && (( PORT > 0 && PORT <= 65535 )) || { print -u2 "port must be between 1 and 65535"; exit 2; }
for dep in curl pgrep; do command -v "$dep" >/dev/null || { print -u2 "$dep is required"; exit 2; }; done
DEFAULT_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x $DEFAULT_BIN ]] || DEFAULT_BIN=$(whence -p google-chrome chromium chromium-browser 2>/dev/null | head -n 1)
BIN=${3:-$DEFAULT_BIN}
[[ -n $BIN && -x $BIN ]] || { print -u2 "chrome binary not found; pass it as the third argument"; exit 2; }
EVERY=${CRD_CHROME_CHECK_SECONDS:-15}; [[ $EVERY =~ '^[0-9]+$' ]] && (( EVERY > 0 )) || EVERY=15
LOG=${CRD_CHROME_LOG:-$PROFILE.supervisor.log}
LOCK=$PROFILE.supervisor.lock

mkdir -p "$PROFILE"
mkdir "$LOCK" 2>/dev/null || { print -r -- "$(date -u +%FT%TZ) another supervisor holds $LOCK; exiting" >> "$LOG"; exit 0; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
print -r -- $$ > "$PROFILE.supervisor.pid"
print -r -- "$(date -u +%FT%TZ) supervisor start pid=$$ port=$PORT profile=$PROFILE" >> "$LOG"

PROFILE_RE=$(print -rn -- "$PROFILE" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
owned() { pgrep -f -- "(^|[[:space:]])--user-data-dir=$PROFILE_RE([[:space:]]|$)" 2>/dev/null }   # the '--user-data-dir=' prefix never matches this script
fails=2; restarts=()   # 2: the first failed check at start launches Chrome at once
while true; do
  if curl -fs -m 10 "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then
    fails=0
  else
    fails=$(( fails + 1 ))
    if (( fails >= 3 )); then
      now=$EPOCHSECONDS; recent=(); for t in $restarts; do (( now - t < 600 )) && recent+=$t; done; restarts=($recent)
      if (( ${#restarts} >= 3 )); then
        print -r -- "$(date -u +%FT%TZ) 3 restarts in 10 min; giving up (no new Chrome)" >> "$LOG"; exit 1
      fi
      for p in $(owned); do kill "$p" 2>/dev/null; done
      sleep 3; for p in $(owned); do kill -9 "$p" 2>/dev/null; done
      rm -f "$PROFILE/SingletonLock" "$PROFILE/SingletonSocket" "$PROFILE/SingletonCookie"
      "$BIN" --headless=new --remote-debugging-address=127.0.0.1 --remote-debugging-port="$PORT" \
        --user-data-dir="$PROFILE" --no-first-run --no-default-browser-check --disable-gpu --disable-extensions \
        --renderer-process-limit=${CRD_CHROME_RENDERER_LIMIT:-6} about:blank >> "$LOG" 2>&1 &!
      restarts+=$EPOCHSECONDS; fails=0
      print -r -- "$(date -u +%FT%TZ) chrome (re)started; restarts in 10 min: ${#restarts}" >> "$LOG"
      sleep 10
    fi
  fi
  sleep "$EVERY"
done
