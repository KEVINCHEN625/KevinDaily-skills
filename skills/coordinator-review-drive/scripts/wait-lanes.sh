#!/bin/zsh
# wait-lanes.sh — background waiter for dispatched lanes (coordinator-review-drive).
#
# usage: wait-lanes.sh <G> <lane-list-file> [stall-seconds=1800] [poll-seconds=30]
#   lane-list-file  one lane per line:  <out-dir> [label] [stall-seconds]
#                   '#' starts a comment; relative paths resolve against G (the list itself too).
#                   The list is read once at start: after editing it, start a new waiter.
#
# Run it in the background; it prints and EXITS on the first event batch so the coordinator is woken:
#   DONE  <label> exit=<rc> dur=<s> <out>   FINISHED_UTC present and not yet .seen (the waiter creates .seen)
#         > <first line of LAST-MESSAGE.md>  (READY-FOR-REVIEW / NEED-DECISION / NEED-RESTART / BLOCKED / ...)
#   STALL <label> quiet=<s> pid=<p> <out>   started, unfinished, no file in out-dir changed for stall-seconds
#                                           (reported once per quiet period; the process may still be working)
#   DEAD  <label> <out>                     started, unfinished, wrapper PID gone (killed/crashed, no markers)
#   ALL-SEEN                                nothing left to wait for
# env:
#   CRD_WAIT_MODE=any|all       any (default): exit on the first event; all: report DONE only when every lane
#                               has finished (STALL/DEAD still exit early)
#   CRD_WAIT_MAX_SECONDS=0      >0: give up after that many seconds (TIMEOUT)
# exit: 0 DONE or ALL-SEEN | 3 STALL/DEAD reported | 4 TIMEOUT | 2 usage error
set -u
zmodload -F zsh/stat b:zstat
zmodload zsh/datetime

(( $# >= 2 && $# <= 4 )) || { print -u2 "usage: wait-lanes.sh <G> <lane-list-file> [stall-seconds] [poll-seconds]"; exit 2; }
G=${1:A}; LIST=$2; STALL=${3:-1800}; POLL=${4:-30}
[[ $LIST == /* ]] || LIST=$G/$LIST
[[ -f $LIST ]] || { print -u2 "lane list not found: $LIST"; exit 2; }
[[ $STALL =~ ^[0-9]+$ && $POLL =~ ^[0-9]+$ ]] && (( POLL > 0 )) || { print -u2 "stall/poll seconds must be positive integers"; exit 2; }
MODE=${CRD_WAIT_MODE:-any}; MAX=${CRD_WAIT_MAX_SECONDS:-0}
[[ $MODE == any || $MODE == all ]] || { print -u2 "CRD_WAIT_MODE must be any or all"; exit 2; }
[[ $MAX =~ ^[0-9]+$ ]] || { print -u2 "CRD_WAIT_MAX_SECONDS must be an integer"; exit 2; }

typeset -a OUTS LABELS STALLS
typeset -A LISTED
while IFS= read -r line || [[ -n $line ]]; do
  line=${line%%\#*}; w=(${=line}); (( $#w )) || continue
  o=${w[1]}; [[ $o == /* ]] || o=$G/$o; o=${o:A}
  st=${w[3]:-$STALL}; [[ $st =~ ^[0-9]+$ ]] || { print -u2 "bad stall-seconds '$st' for $o"; exit 2; }
  (( ${+LISTED[$o]} )) && print -u2 "WARNING: out dir listed twice: $o"
  LISTED[$o]=1; OUTS+=("$o"); LABELS+=("${w[2]:-${o:t}}"); STALLS+=("$st")
done < "$LIST"
(( $#OUTS )) || { print "ALL-SEEN (empty lane list: $LIST)"; exit 0; }

newest_mtime() {  # newest non-dot file in the out dir (marker dotfiles excluded)
  local pat="$1/**/*(N.om[1])"; local -a f; f=( $~pat )
  if (( $#f )); then zstat +mtime -- "$f[1]"; else zstat +mtime -- "$1"; fi
}
first_line() { [[ -f $1 ]] && grep -m1 -v '^[[:space:]]*$' "$1" | cut -c1-300; }

ST=""; LAST=0
state_of() {  # <out> <stall-seconds>  -> sets ST (and LAST for STALL)
  local o=$1 lim=$2 pid
  if [[ -f $o/FINISHED_UTC ]]; then if [[ -e $o/.seen ]]; then ST=SEEN; else ST=DONE; fi; return; fi
  if [[ ! -f $o/STARTED_UTC ]]; then ST=PENDING; return; fi
  pid=$(cat "$o/PID" 2>/dev/null)
  if [[ -n $pid ]] && ! kill -0 "$pid" 2>/dev/null; then
    if [[ -f $o/FINISHED_UTC ]]; then ST=DONE; return; fi   # finished between checks
    if [[ -e $o/.dead-reported ]]; then ST=DEAD-SEEN; else ST=DEAD; fi; return
  fi
  LAST=$(newest_mtime "$o")
  if (( EPOCHSECONDS - LAST >= lim )); then ST=STALL; else ST=RUNNING; fi
}

report_done() {  # <index>
  local i=$1 o=$OUTS[$1] rc t0 t1
  rc=$(cat "$o/EXIT_CODE" 2>/dev/null || print '?')
  t1=$(zstat +mtime -- "$o/FINISHED_UTC")
  t0=$(zstat +mtime -- "$o/STARTED_UTC" 2>/dev/null || print "$t1")
  print -r -- "DONE ${LABELS[i]} exit=$rc dur=$(( t1 - t0 ))s $o"
  [[ -f $o/REVIEW-STATUS ]] && print -r -- "  review-status: $(cat "$o/REVIEW-STATUS")"
  [[ -f $o/RETRIES.log ]] && print -r -- "  retries: $(wc -l < "$o/RETRIES.log" | tr -d ' ')"
  print -r -- "  > $(first_line "$o/LAST-MESSAGE.md")"
  : > "$o/.seen"
}

summary() {
  local i
  print -r -- "--- lanes ($LIST) ---"
  for i in {1..$#OUTS}; do state_of "$OUTS[i]" "$STALLS[i]"; print -r -- "$ST ${LABELS[i]} $OUTS[i]"; done
}

T0=$EPOCHSECONDS
while true; do
  EV=(); ALERT=(); unfinished=0
  for i in {1..$#OUTS}; do
    o=$OUTS[i]
    state_of "$o" "$STALLS[i]"
    case $ST in
      DONE)            [[ $MODE == any ]] && EV+=($i) ;;
      RUNNING|PENDING) (( unfinished++ )) ;;
      STALL)
        (( unfinished++ ))
        if [[ $(cat "$o/.stall-reported" 2>/dev/null) != "$LAST" ]]; then
          ALERT+=("STALL ${LABELS[i]} quiet=$(( EPOCHSECONDS - LAST ))s pid=$(cat "$o/PID" 2>/dev/null) $o")
          print -r -- "$LAST" > "$o/.stall-reported"
        fi ;;
      DEAD)
        ALERT+=("DEAD ${LABELS[i]} wrapper pid $(cat "$o/PID" 2>/dev/null) gone without FINISHED_UTC $o")
        : > "$o/.dead-reported" ;;
    esac
  done
  if [[ $MODE == all ]] && (( unfinished == 0 )); then
    for i in {1..$#OUTS}; do state_of "$OUTS[i]" "$STALLS[i]"; [[ $ST == DONE ]] && EV+=($i); done
  fi
  if (( $#EV || $#ALERT )); then
    for i in $EV; do report_done $i; done
    for a in $ALERT; do print -r -- "$a"; done
    summary
    (( $#ALERT )) && exit 3
    exit 0
  fi
  if (( unfinished == 0 )); then print "ALL-SEEN (no unfinished lanes)"; summary; exit 0; fi
  if (( MAX > 0 && EPOCHSECONDS - T0 >= MAX )); then print "TIMEOUT after ${MAX}s"; summary; exit 4; fi
  sleep $POLL
done
