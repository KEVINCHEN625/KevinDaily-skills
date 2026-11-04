#!/bin/zsh
# run-claude.sh — one headless Claude Code task (`claude -p`) with optional named-session reuse.
# Typical use: cheap web research or fixed-command test runs on a small model, or a second opinion.
#
# usage: run-claude.sh <G> <session-name|-> <cwd> <model> <prompt-file> <out-dir> [allowed-tools]
#   session-name  "-" = one-off; otherwise G/sessions/claude/<name>.id is resumed (--resume) on later calls
#   model         full model id (e.g. claude-haiku-5-5). Agent-tool aliases may map to older models, so the
#                 wrapper writes MODEL-USAGE.txt from the JSON modelUsage: verify the model actually used.
#   allowed-tools comma list for --allowedTools (default read/research only: Read,Grep,Glob,WebSearch,WebFetch)
# env: CRD_CLAUDE_PERMISSION_MODE (default "default"; tools outside allowed-tools are denied in -p mode)
#
# Output: result.json (raw), LAST-MESSAGE.md (the result text), MODEL-USAGE.txt, SESSION.
# Never pass --dangerously-skip-permissions.
set -u
source "${0:A:h}/lib.zsh"
(( $# == 6 || $# == 7 )) || crd_usage "run-claude.sh <G> <session-name|-> <cwd> <model> <prompt-file> <out-dir> [allowed-tools]"
G=${1:A}; NAME=$2; CWD=${3:A}; MODEL=$4; P=${5:A}; O=${6:A}
TOOLS=${7:-Read,Grep,Glob,WebSearch,WebFetch}
PMODE=${CRD_CLAUDE_PERMISSION_MODE:-default}

crd_check_token model "$MODEL"
case $PMODE in
  default|acceptEdits|plan|dontAsk) ;;
  *) crd_die "CRD_CLAUDE_PERMISSION_MODE must be default, acceptEdits, plan or dontAsk (permission bypass is not supported)" ;;
esac
[[ $NAME == - ]] || crd_check_token session-name "$NAME"
[[ $TOOLS =~ '^[A-Za-z0-9_,:*() .-]+$' ]] || crd_die "allowed-tools has unsafe characters: $TOOLS"
crd_require_g "$G"; crd_require_dir cwd "$CWD"; crd_require_file prompt-file "$P"
CLAUDE=${CRD_CLAUDE_BIN:-claude}; command -v "$CLAUDE" >/dev/null || crd_die "claude CLI not found: $CLAUDE"

trap 'crd_session_unlock' EXIT
ID=""
if [[ $NAME != - ]]; then
  ID="$G/sessions/claude/$NAME.id"
  crd_session_lock "$G/sessions/claude/$NAME.lock"
fi
crd_fresh_out "$O"
crd_start "$O" claude-headless "$NAME" "$MODEL" "-" "$CWD" "$PMODE;tools=$TOOLS"
trap 'crd_finish "$O" 143; crd_session_unlock; exit 143' TERM HUP
trap 'crd_finish "$O" 130; crd_session_unlock; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

ARGS=(-p --model "$MODEL" --output-format json --permission-mode "$PMODE" --allowedTools "$TOOLS")
[[ -n $ID && -s $ID ]] && ARGS+=(--resume "$(cat "$ID")")

cd "$CWD" || { crd_finish "$O" 2; exit 2; }
"$CLAUDE" "${ARGS[@]}" < "$O/PROMPT.sent.md" > "$O/result.json" 2> "$O/stderr.log"
rc=$?
python3 -I - "$O" "${ID:-}" <<'PY'
import json, sys, os
out, idfile = sys.argv[1], sys.argv[2]
try:
    with open(os.path.join(out, "result.json"), encoding="utf-8") as result_file:
        data = json.load(result_file)
    if not isinstance(data, dict):
        raise ValueError("result must be a JSON object")
except Exception as exc:  # non-JSON output: keep raw file, say so
    open(os.path.join(out, "LAST-MESSAGE.md"), "w").write(f"BLOCKED: result.json is not JSON ({exc.__class__.__name__}); see result.json/stderr.log\n")
    sys.exit(2)
open(os.path.join(out, "LAST-MESSAGE.md"), "w").write(str(data.get("result", "")) + "\n")
usage = data.get("modelUsage") or {}
if not isinstance(usage, dict):
    usage = {}
open(os.path.join(out, "MODEL-USAGE.txt"), "w").write("\n".join(sorted(usage)) + "\n")
sid = data.get("session_id")
if isinstance(sid, str) and sid:
    open(os.path.join(out, "SESSION"), "w").write(sid + "\n")
    if idfile:
        open(idfile, "w").write(sid + "\n")
if data.get("is_error"):
    sys.exit(1)
PY
parse_rc=$?
(( rc == 0 && parse_rc != 0 )) && rc=$parse_rc
crd_finish "$O" $rc
exit $rc
