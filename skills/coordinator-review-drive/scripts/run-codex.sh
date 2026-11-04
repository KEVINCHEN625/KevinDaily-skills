#!/bin/zsh
# run-codex.sh — one Codex CLI task in a named, reusable session (coordinator-review-drive).
#
# usage: run-codex.sh <G> <session-name> <cwd> <read-only|workspace-write> <model> <effort> <prompt-file> <out-dir>
#   G             project goal dir (sessions are stored in G/sessions/codex/<session-name>.id)
#   session-name  task-type affinity: the same kind of task always reuses the same name
#                 (e.g. sol-impl-<area>, sol-web-tester-<surface>, astra-key-plans); first call starts
#                 a session and records its id, later calls `codex exec resume` it (memory + prompt-cache hits)
#   CRD_CODEX_EXTRA  optional "-c service_tier=<tier>" only; arbitrary flags could override the sandbox
#   model/effort  passed straight to codex (-m, -c model_reasoning_effort=...); nothing is hardcoded
#   out-dir       must be new (never reused); gets PROMPT.sent.md, codex.log, LAST-MESSAGE.md, EXIT_CODE, FINISHED_UTC
#
# The policy header (G/POLICY-HEADER.txt, else templates/POLICY-HEADER.txt) is prepended to the prompt.
# Never uses --dangerously-bypass-* or danger-full-access. Launch it with launch-lane.sh and wait with wait-lane.sh.
# Read-only sandboxes cannot write files: ask for the full deliverable in the final message (LAST-MESSAGE.md).
set -u
source "${0:A:h}/lib.zsh"
(( $# == 8 )) || crd_usage "run-codex.sh <G> <session-name> <cwd> <read-only|workspace-write> <model> <effort> <prompt-file> <out-dir>"
G=${1:A}; NAME=$2; CWD=${3:A}; SB=$4; MODEL=$5; EFF=$6; P=${7:A}; O=${8:A}

[[ $SB == read-only || $SB == workspace-write ]] || crd_die "sandbox must be read-only or workspace-write (never danger-full-access)"
crd_check_token session-name "$NAME"; crd_check_token model "$MODEL"; crd_check_token effort "$EFF"
crd_require_g "$G"; crd_require_dir cwd "$CWD"; crd_require_file prompt-file "$P"
CODEX=${CRD_CODEX_BIN:-codex}; command -v "$CODEX" >/dev/null || crd_die "codex CLI not found: $CODEX"
EXTRA_ARGS=()
if [[ -n ${CRD_CODEX_EXTRA:-} ]]; then
  EXTRA_ARGS=(${=CRD_CODEX_EXTRA})
  (( $#EXTRA_ARGS == 2 )) && [[ $EXTRA_ARGS[1] == -c && $EXTRA_ARGS[2] =~ '^service_tier=[A-Za-z0-9._-]+$' ]] || crd_die 'CRD_CODEX_EXTRA only accepts "-c service_tier=<tier>"; sandbox/approval overrides are not supported'
fi

ID="$G/sessions/codex/$NAME.id"
trap 'crd_session_unlock' EXIT
crd_session_lock "$G/sessions/codex/$NAME.lock"
crd_fresh_out "$O"
crd_start "$O" codex "$NAME" "$MODEL" "$EFF" "$CWD" "$SB"
trap 'crd_finish "$O" 143; crd_session_unlock; exit 143' TERM HUP
trap 'crd_finish "$O" 130; crd_session_unlock; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

cd "$CWD" || { crd_finish "$O" 2; exit 2; }
if [[ -s $ID ]]; then
  print -r -- "resume $(cat "$ID")" > "$O/SESSION"
  "$CODEX" exec resume "$(cat "$ID")" -m "$MODEL" -c model_reasoning_effort="$EFF" -c sandbox_mode="$SB" "${EXTRA_ARGS[@]}" \
    --skip-git-repo-check -o "$O/LAST-MESSAGE.md" - < "$O/PROMPT.sent.md" > "$O/codex.log" 2>&1
  rc=$?
else
  "$CODEX" exec -C "$CWD" -s "$SB" -m "$MODEL" -c model_reasoning_effort="$EFF" "${EXTRA_ARGS[@]}" \
    --skip-git-repo-check -o "$O/LAST-MESSAGE.md" - < "$O/PROMPT.sent.md" > "$O/codex.log" 2>&1
  rc=$?
  crd_capture_codex_session "$O/codex.log" "$ID"
  [[ -s $ID ]] && print -r -- "new $(cat "$ID")" > "$O/SESSION"
fi
crd_finish "$O" $rc
exit $rc
