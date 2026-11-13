#!/bin/zsh
# run-dsh.sh — one headless dsh task (e.g. a fast, cheap executor model) (coordinator-review-drive).
#
# usage: run-dsh.sh <G> <workdir> <task-file> <out-dir> <provider> <model> <effort> [read-only|workspace-write]
#   workdir   sandbox root (a lane worktree); default mode workspace-write; never danger-full-access
#   provider/model/effort  written into a credential-free overlay patch (out-dir/model.patch.yml), e.g.
#             <provider-id>  <exact-model-id>  <effort>   (the ids your dsh profile accepts)
# env:
#   CRD_DSH_PROFILE        dsh profile to boot (default headless)
#   CRD_DSH_EXTRA_PATCH    optional second overlay (e.g. an MCP adapter patch for web work)
#   CRD_RETRY_BASE_SECONDS backoff base (default 60; attempt n sleeps n*base)
#
# Retries (up to 3 attempts) ONLY on upstream server/transport errors:
#   "dsh: SERVER:", "dsh: TRANSPORT:", "PI_AI_ERROR: server_error"
# Each attempt keeps its own stderr (stderr.attemptN.log); a retry continues from the workdir's current state.
# Extend the retry pattern when a new upstream error class appears (do not retry on task failures).
set -u
source "${0:A:h}/lib.zsh"
(( $# == 7 || $# == 8 )) || crd_usage "run-dsh.sh <G> <workdir> <task-file> <out-dir> <provider> <model> <effort> [read-only|workspace-write]"
G=${1:A}; W=${2:A}; TASK=${3:A}; O=${4:A}; PROV=$5; MODEL=$6; EFF=$7; MODE=${8:-workspace-write}

[[ $MODE == read-only || $MODE == workspace-write ]] || crd_die "mode must be read-only or workspace-write"
crd_check_token provider "$PROV"; crd_check_token model "$MODEL"; crd_check_token effort "$EFF"
crd_require_g "$G"; crd_require_dir workdir "$W"; crd_require_file task-file "$TASK"
DSH=${CRD_DSH_BIN:-dsh}; command -v "$DSH" >/dev/null || crd_die "dsh not found: $DSH"
PROFILE=${CRD_DSH_PROFILE:-headless}; crd_check_token profile "$PROFILE"
EXTRA=${CRD_DSH_EXTRA_PATCH:-}
[[ -z $EXTRA || -f $EXTRA ]] || crd_die "CRD_DSH_EXTRA_PATCH not found: $EXTRA"
BASE=${CRD_RETRY_BASE_SECONDS:-60}; [[ $BASE =~ ^[0-9]+$ ]] || crd_die "CRD_RETRY_BASE_SECONDS must be an integer"
RETRY_RE='dsh: (SERVER|TRANSPORT):|PI_AI_ERROR: server_error'

crd_fresh_out "$O"
crd_start "$O" dsh "-" "$PROV/$MODEL" "$EFF" "$W" "$MODE"
trap 'crd_finish "$O" 143; exit 143' TERM HUP
trap 'crd_finish "$O" 130; exit 130' INT
crd_compose_prompt "$G" "$TASK" "$O/PROMPT.sent.md"
cat > "$O/model.patch.yml" <<EOF
- id: agent-default-model
  config:
    provider: $PROV
    model: $MODEL
    reasoningEffort: $EFF
EOF
PATCHES=(--patch "$O/model.patch.yml")
[[ -n $EXTRA ]] && PATCHES+=(--patch "${EXTRA:A}")

cd "$W" || { crd_finish "$O" 2; exit 2; }
rc=1
for attempt in 1 2 3; do
  DSH_PERMISSION_MODE=$MODE "$DSH" --profile "$PROFILE" "${PATCHES[@]}" "$(cat "$O/PROMPT.sent.md")" \
    > "$O/LAST-MESSAGE.md" 2> "$O/stderr.attempt$attempt.log"
  rc=$?
  cp "$O/stderr.attempt$attempt.log" "$O/stderr.log"
  if (( rc != 0 )) && (( attempt < 3 )) && grep -q -E "$RETRY_RE" "$O/stderr.attempt$attempt.log"; then
    cp "$O/LAST-MESSAGE.md" "$O/LAST-MESSAGE.attempt$attempt.md" 2>/dev/null
    print -r -- "$(date -u +%FT%TZ) attempt $attempt: upstream error (rc=$rc), retrying in $(( attempt * BASE ))s" >> "$O/RETRIES.log"
    sleep $(( attempt * BASE ))
    continue
  fi
  break
done
crd_finish "$O" $rc
exit $rc
