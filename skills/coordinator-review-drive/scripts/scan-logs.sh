#!/bin/bash
# usage: scan-logs.sh [--ack FILE] [--min N] [--top N] [--tail-lines N] [--mark FILE [--update-mark]] <log>...
# Error-signature histogram over instance logs (backend, worker, proxy, frontend). Run it before every test run
# (preflight-run.sh calls it) and after every run: EVERY signature is a blocker candidate, not only the one that
# stopped the page. Why: a backend RuntimeError once sat in a log thousands of times for days while page runs found
# one blocker per run. Requires perl.
# Idea adapted from Matt Pocock's skills (MIT): diagnosing-bugs "build a feedback loop" / retro "information access:
# tee dev server logs"; and pstack (MIT) prove-it-works "read the real state".
#
#   --ack FILE     known signatures: one fixed substring per line, optional "# D-123 reason". A signature that
#                  contains an ack substring is listed as "ack" and does not fail the scan.
#   --min N        an un-acked signature counts as a blocker when it occurs >= N times (default 3)
#   --top N        print the N most frequent signatures (default 25)
#   --tail-lines N read at most the last N lines of each log (default 400000)
#   --mark FILE    per-log byte offsets of the previous scan: only newer bytes are read. The file is rewritten only
#                  with --update-mark (the single write this script can do).
# Scan window (a scan of a whole multi-day log is noise: on one large log it gave hundreds of signatures, a handful
# of them from the current day). The first that applies wins, and the window is printed in the LOG-SCAN line:
#   1. --mark FILE with an entry for the log      -> bytes written since that scan
#   2. --runs RUNS.tsv                            -> lines since the last run logged there
#   3. --since <YYYY-MM-DDTHH:MM:SSZ>             -> lines since that UTC time
#   4. --since-hours N                            -> lines of the last N hours
#   5. none                                       -> the whole tail (window=ALL)
#   Time windows compare against the timestamp at the start of each log line (YYYY-MM-DD HH:MM:SS, taken as local
#   time; set LOG_TZ=utc when the log is written in UTC). A line without a timestamp belongs to the last timestamp
#   seen above it. A log with no timestamps at all cannot be windowed: it is scanned whole and named in NO-TIMESTAMP.
# Output: first line "LOG-SCAN PASS|FAIL files=… lines=… signatures=… blockers=…", then "count  NEW|ack  signature".
# Secrets are redacted before printing; numbers, ids and timestamps are normalised. Exit 0 = PASS, 1 = FAIL, 2 = usage.
set -u
ack=""; min=3; top=25; tailn=400000; mark=""; upd=0; logs=(); since=""; runs=""; sinceh=""
while [ $# -gt 0 ]; do
  case "$1" in --ack|--min|--top|--tail-lines|--mark|--since|--runs|--since-hours)
    [ $# -ge 2 ] || { echo "LOG-SCAN usage: $1 needs a value" >&2; exit 2; };; esac
  case "$1" in
    --since) since="${2:-}"; shift 2;;
    --runs) runs="${2:-}"; shift 2;;
    --since-hours) sinceh="${2:-}"; shift 2;;
    --ack) ack="${2:-}"; shift 2;;
    --min) min="${2:-}"; shift 2;;
    --top) top="${2:-}"; shift 2;;
    --tail-lines) tailn="${2:-}"; shift 2;;
    --mark) mark="${2:-}"; shift 2;;
    --update-mark) upd=1; shift;;
    -*) echo "LOG-SCAN usage: unknown option $1" >&2; exit 2;;
    *) logs+=("$1"); shift;;
  esac
done
case "$min$top$tailn$sinceh" in *[!0-9]*|"") echo "LOG-SCAN usage: --min/--top/--tail-lines/--since-hours need numbers" >&2; exit 2;; esac
epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null || echo 0; }
# resolve the time window (epoch seconds; 0 = none)
wepoch=0; wsrc=""
if [ -n "$runs" ] && [ -s "$runs" ]; then
  lastrun=$(awk -F'\t' 'NR>1 && $1!="" {l=$1} END {print l}' "$runs")
  [ -n "$lastrun" ] && { wepoch=$(epoch "$lastrun"); wsrc="last run in RUNS.tsv ($lastrun)"; }
fi
if [ "$wepoch" -eq 0 ] && [ -n "$since" ]; then wepoch=$(epoch "$since"); wsrc="--since $since"
  [ "$wepoch" -gt 0 ] || { echo "LOG-SCAN usage: --since needs YYYY-MM-DDTHH:MM:SSZ" >&2; exit 2; }; fi
if [ "$wepoch" -eq 0 ] && [ -n "$sinceh" ]; then wepoch=$(( $(date +%s) - sinceh*3600 )); wsrc="last ${sinceh}h"; fi
wstr=""
if [ "$wepoch" -gt 0 ]; then
  wstr=$(perl -MPOSIX -e 'my @t = (lc($ENV{LOG_TZ}||"") eq "utc") ? gmtime($ARGV[0]) : localtime($ARGV[0]); print strftime("%Y-%m-%d %H:%M:%S", @t)' "$wepoch")
fi
[ ${#logs[@]} -ge 1 ] || { echo "LOG-SCAN usage: scan-logs.sh [options] <log>..." >&2; exit 2; }
[ "$upd" = 1 ] && [ -z "$mark" ] && { echo "LOG-SCAN usage: --update-mark needs --mark FILE" >&2; exit 2; }
tmp=$(mktemp -t scanlogs.XXXXXX) || exit 2
newmark=$(mktemp -t scanmark.XXXXXX) || exit 2
trap 'rm -f "$tmp" "$newmark"' EXIT
files=0; missing=""; nots=""; usedmark=0
for f in "${logs[@]}"; do
  [ -n "$f" ] && [ -f "$f" ] || { missing="$missing ${f:-<empty>}"; continue; }
  files=$((files+1))
  size=$(wc -c < "$f" | tr -d ' ')
  off=0
  if [ -n "$mark" ] && [ -f "$mark" ]; then
    off=$(awk -F'\t' -v p="$f" '$1==p {o=$2} END {print o+0}' "$mark")
    [ "$off" -gt "$size" ] && off=0          # log was rotated or truncated
  fi
  printf '%s\t%s\n' "$f" "$size" >> "$newmark"
  if [ "$off" -gt 0 ]; then usedmark=1; tail -c +"$((off+1))" "$f" | tail -n "$tailn" >> "$tmp"
  elif [ -n "$wstr" ]; then
    if tail -n "$tailn" "$f" | grep -qaE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}'; then
      tail -n "$tailn" "$f" | W="$wstr" perl -ne 'if (/(\d{4}-\d\d-\d\d)[T ](\d\d:\d\d:\d\d)/) { $cur = "$1 $2" } print if defined $cur && $cur ge $ENV{W}' >> "$tmp"
    else nots="$nots $f"; tail -n "$tailn" "$f" >> "$tmp"; fi
  else tail -n "$tailn" "$f" >> "$tmp"; fi
done
lines=$(wc -l < "$tmp" | tr -d ' ')
out=$(perl -ne '
  next unless /\b(ERROR|CRITICAL|FATAL)\b|\b\w*(Error|Exception)\b\s*[:(]|panic:|" [45]\d\d\b|status(_code)?["\x27]?\s*[=:]\s*[45]\d\d\b|\b50[0234] (Internal|Bad Gateway|Service|Gateway)/;
  next if /Traceback \(most recent call last\)/;
  chomp; s/\e\[[0-9;]*m//g;
  s/\b(Bearer|Basic)\s+\S+/<REDACTED>/gi; s/\b(sk|pk|rk)-[A-Za-z0-9_-]{8,}/<REDACTED>/g;
  s/((?:authorization|api[_-]?key|token|secret|password|passwd|cookie)["\x27]?\s*[:=]\s*)("[^"]*"|\x27[^\x27]*\x27|\S+)/$1<REDACTED>/gi;
  s/[\w.+-]+@[\w-]+\.[\w.-]+/<email>/g;
  s/\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d(?:[.,]\d+)?(?:Z|[+-]\d\d:?\d\d)?//g; s/\[\d\d\/\w{3}\/\d{4}[^\]]*\]//g;
  s/\b\d\d:\d\d:\d\d(?:[.,]\d+)?\b//g;
  s/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/<id>/gi; s/\b0x[0-9a-f]+\b/<hex>/gi;
  s/\b[0-9a-f]{12,}\b/<hex>/gi; s/\b\d+\.\d+\.\d+\.\d+(?::\d+)?\b/<ip>/g;
  s/\?[^\s"]*/?…/g; s/\/\d+(?=[\/?"\s]|$)/\/N/g; s/\b\d{4,}\b/N/g; s/(?<!status)(?<!code)([=#\[])\d+/$1N/g;
  s/\s+/ /g; s/^ //; $_ = substr($_, 0, 170);
  $c{$_}++;
  END { for (sort { $c{$b} <=> $c{$a} || $a cmp $b } keys %c) { print "$c{$_}\t$_\n" } }' "$tmp")
sigs=0; blockers=0; body=""; shown=0
if [ -n "$out" ]; then
  while IFS=$'\t' read -r n sig; do
    [ -n "$n" ] || continue
    sigs=$((sigs+1)); tag=NEW
    if [ -n "$ack" ] && [ -f "$ack" ]; then
      while IFS= read -r a; do
        a="${a%%#*}"; a="${a#"${a%%[![:space:]]*}"}"; a="${a%"${a##*[![:space:]]}"}"
        [ -n "$a" ] || continue
        case "$sig" in *"$a"*) tag=ack; break;; esac
      done < "$ack"
    fi
    [ "$tag" = NEW ] && [ "$n" -ge "$min" ] && blockers=$((blockers+1))
    if [ "$shown" -lt "$top" ]; then body="$body$(printf '%7s  %-3s  %s' "$n" "$tag" "$sig")"$'\n'; shown=$((shown+1)); fi
  done <<< "$out"
fi
verdict=PASS; [ "$blockers" -gt 0 ] && verdict=FAIL
[ "$files" -eq 0 ] && verdict=FAIL
if [ "$usedmark" = 1 ]; then window="since the --mark offsets"; elif [ -n "$wstr" ]; then window="since $wstr $([ "$(printf '%s' "${LOG_TZ:-}" | tr 'A-Z' 'a-z')" = utc ] && echo UTC || echo local) — $wsrc"; else window="ALL (last $tailn lines per log)"; fi
echo "LOG-SCAN $verdict files=$files lines=$lines signatures=$sigs blockers=$blockers (un-acked, count>=$min) window=[$window]${nots:+ NO-TIMESTAMP(scanned whole):$nots}${missing:+ MISSING-LOGS:$missing}"
printf '%s' "$body"
if [ "$upd" = 1 ]; then cp "$newmark" "$mark" && echo "mark updated: $mark" 2>/dev/null; fi
[ "$verdict" = PASS ] && exit 0 || exit 1
