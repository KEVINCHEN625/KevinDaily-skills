# lib.zsh — shared helpers for the coordinator-review-drive wrappers (zsh only; sourced, not executed).
# Never reads or prints credentials, tokens, auth files or .env files.
#
# Out-dir contract written by every wrapper (read by wait-lane.sh and the legacy wait-lanes.sh):
#   STARTED_UTC  PID  DISPATCH.json  PROMPT.sent.md  ...tool logs...  LAST-MESSAGE.md  EXIT_CODE  FINISHED_UTC
#   EXIT_CODE is written before FINISHED_UTC, so a present FINISHED_UTC always has its EXIT_CODE.
#   launch-lane.sh adds WRAPPER_PID/LAUNCHED_UTC; the legacy wait-lanes.sh adds .seen, .stall-reported, .dead-reported.
#
# Binary overrides (alternate installs, or stubs for dry-run tests; PATH may be reset by ~/.zshenv):
#   CRD_CODEX_BIN, CRD_DSH_BIN, CRD_ZCODE_BIN, CRD_CLAUDE_BIN

zmodload zsh/datetime 2>/dev/null

CRD_SCRIPTS_DIR=${${(%):-%x}:A:h}
CRD_SKILL_DIR=${CRD_SCRIPTS_DIR:h}
CRD_LOCK=""

crd_die()   { print -u2 -r -- "ERROR: $*"; crd_session_unlock; exit 2; }
crd_usage() { print -u2 -r -- "usage: $*"; exit 2; }

# Only plain tokens may flow into CLI configs (session names, model ids, effort levels, providers).
crd_check_token() {  # <what> <value>
  if [[ $1 == session-name ]]; then
    [[ $2 =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] || crd_die "session-name must be a filename-safe name: '$2'"
  else
    [[ $2 =~ '^[A-Za-z0-9][A-Za-z0-9._:/@+-]*$' ]] || crd_die "$1 has unsafe characters: '$2'"
  fi
}

crd_require_g() {  # <G>
  [[ -d $1 ]] || crd_die "goal dir G does not exist: $1 (create it with scripts/init-goal.sh)"
  mkdir -p "$1/sessions/codex" "$1/sessions/claude" || crd_die "cannot create $1/sessions"
}

crd_require_file() { [[ -f $2 ]] || crd_die "$1 not found: $2"; }
crd_require_dir()  { [[ -d $2 ]] || crd_die "$1 not found: $2"; }

# Never reuse an out dir: stale FINISHED_UTC/.seen/LAST-MESSAGE make the waiter misreport or hang.
crd_fresh_out() {  # <out-dir>
  local o=$1 m
  if [[ -e $o ]]; then
    [[ -d $o ]] || crd_die "out dir path exists and is not a directory: $o"
    for m in STARTED_UTC FINISHED_UTC EXIT_CODE LAST-MESSAGE.md REVIEW.md .seen; do
      if [[ -e $o/$m ]]; then
        crd_die "out dir already used ($m present): $o
  Never reuse an out dir. Pick a new one (e.g. ${o}-r2). If the name really must be reused,
  move the old markers into $o/prev-<UTC>/ first (keep them; do not delete)."
      fi
    done
  fi
  mkdir -p "$o" || crd_die "cannot create out dir $o"
}

# One task at a time per named session (resume of a busy session corrupts its history).
crd_session_lock() {  # <lock-dir>
  local l=$1 p
  if ! mkdir "$l" 2>/dev/null; then
    p=$(cat "$l/pid" 2>/dev/null)
    if [[ -n $p ]] && kill -0 "$p" 2>/dev/null; then
      crd_die "session busy: pid $p holds $l (same-session tasks run one at a time; use another session name or wait)"
    fi
    # A second process may see the directory before its owner writes the pid.
    # Never remove it here: that race can start two writers in the same session.
    crd_die "stale or incomplete session lock: $l; verify its owner has stopped, then move this lock aside before retrying"
  fi
  print -r -- $$ > "$l/pid"
  CRD_LOCK=$l
}
crd_session_unlock() { if [[ -n ${CRD_LOCK:-} ]]; then rm -rf "$CRD_LOCK"; CRD_LOCK=""; fi; return 0; }

crd_start() {  # <out> <tool> <session|-> <model> <effort|-> <cwd> <mode|->
  local o=$1
  date -u +%FT%TZ > "$o/STARTED_UTC"
  print -r -- $$ > "$o/PID"
  python3 -I - "$o/DISPATCH.json" "$2" "$3" "$4" "$5" "$6" "$7" "$(cat "$o/STARTED_UTC")" "$$" <<'PY'
import json, sys
out, *vals = sys.argv[1:]
keys = ("tool", "session", "model", "effort", "cwd", "mode", "started_utc", "wrapper_pid")
rec = dict(zip(keys, vals))
rec["note"] = "model/effort are the requested values; confirm the actual model from the tool log/report"
with open(out, "w") as f:
    json.dump(rec, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}

crd_finish() {  # <out> <rc>
  [[ -e $1/FINISHED_UTC ]] && return 0
  print -r -- "$2" > "$1/EXIT_CODE"
  date -u +%FT%TZ > "$1/FINISHED_UTC"
}

# Policy header prepended to executor prompts: G/POLICY-HEADER.txt overrides the skill default.
crd_policy_file() {  # <G>
  if [[ -f $1/POLICY-HEADER.txt ]]; then print -r -- "$1/POLICY-HEADER.txt"
  else print -r -- "$CRD_SKILL_DIR/templates/POLICY-HEADER.txt"; fi
}
crd_compose_prompt() {  # <G> <prompt-file> <dest>
  { cat "$(crd_policy_file "$1")"; print; cat "$2"; } > "$3"
}

crd_capture_codex_session() {  # <codex.log> <id-file>
  local sid
  sid=$(grep -a -m1 "session id:" "$1" 2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g' \
        | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n 1)
  [[ -n $sid ]] && print -r -- "$sid" > "$2"
  return 0
}
