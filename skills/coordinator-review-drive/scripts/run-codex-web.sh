#!/bin/zsh
# run-codex-web.sh — Codex real-page (browser) testing session (coordinator-review-drive).
#
# usage: run-codex-web.sh <G> <session-name> <cwd> <model> <effort> <prompt-file> <out-dir>
#
# workspace-write sandbox + network (for localhost), ONE extra writable root for E2E evidence, and a
# session-scoped MCP server named "chrome" (chrome-devtools-mcp attached to a Chrome the COORDINATOR launched
# natively with --remote-debugging-port) whose tools are pre-approved for THIS server only.
# Never --dangerously-bypass-*; other approvals unchanged. Same session store/affinity as run-codex.sh.
#
# env (infrastructure, not models):
#   CRD_BROWSER_URL            DevTools endpoint                  (default http://127.0.0.1:9333)
#   CRD_EVIDENCE_ROOT          extra writable root for evidence    (default G/e2e-web)
#   CRD_CHROME_MCP_COMMAND     MCP server command                  (default npx)
#   CRD_CHROME_MCP_ARGS_JSON   MCP args as a JSON/TOML string array
#                              (default ["-y","chrome-devtools-mcp@latest","--browserUrl","<CRD_BROWSER_URL>"])
#   Tip: inside a sandbox npx may need network; prefer an absolute node path + the installed
#   chrome-devtools-mcp .js entry so the server starts offline.
# Tester prompts must say: use ONLY the MCP tools of the server named "chrome"; never Browser Use / cua / iab.
# Do not run two testers on the same account/page set concurrently.
set -u
source "${0:A:h}/lib.zsh"
(( $# == 7 )) || crd_usage "run-codex-web.sh <G> <session-name> <cwd> <model> <effort> <prompt-file> <out-dir>"
G=${1:A}; NAME=$2; CWD=${3:A}; MODEL=$4; EFF=$5; P=${6:A}; O=${7:A}

crd_check_token session-name "$NAME"; crd_check_token model "$MODEL"; crd_check_token effort "$EFF"
crd_require_g "$G"; crd_require_dir cwd "$CWD"; crd_require_file prompt-file "$P"
CODEX=${CRD_CODEX_BIN:-codex}; command -v "$CODEX" >/dev/null || crd_die "codex CLI not found: $CODEX"

URL=${CRD_BROWSER_URL:-http://127.0.0.1:9333}
EVID=${CRD_EVIDENCE_ROOT:-$G/e2e-web}; EVID=${EVID:A}
MCP_CMD=${CRD_CHROME_MCP_COMMAND:-npx}
MCP_ARGS=${CRD_CHROME_MCP_ARGS_JSON:-"[\"-y\",\"chrome-devtools-mcp@latest\",\"--browserUrl\",\"$URL\"]"}
for v in "$URL" "$EVID" "$MCP_CMD"; do [[ $v != *'"'* ]] || crd_die "double quotes are not allowed in: $v"; done
[[ $MCP_ARGS == \[*\] ]] || crd_die "CRD_CHROME_MCP_ARGS_JSON must be a JSON string array"
mkdir -p "$EVID" || crd_die "cannot create evidence root $EVID"

WEB=(-c sandbox_workspace_write.network_access=true
     -c "sandbox_workspace_write.writable_roots=[\"$EVID\"]"
     -c "mcp_servers.chrome.command=\"$MCP_CMD\""
     -c "mcp_servers.chrome.args=$MCP_ARGS"
     -c 'mcp_servers.chrome.default_tools_approval_mode="approve"')

ID="$G/sessions/codex/$NAME.id"
trap 'crd_session_unlock' EXIT
crd_session_lock "$G/sessions/codex/$NAME.lock"
crd_fresh_out "$O"
crd_start "$O" codex-web "$NAME" "$MODEL" "$EFF" "$CWD" "workspace-write+network+chrome-mcp"
trap 'crd_finish "$O" 143; crd_session_unlock; exit 143' TERM HUP
trap 'crd_finish "$O" 130; crd_session_unlock; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

cd "$CWD" || { crd_finish "$O" 2; exit 2; }
if [[ -s $ID ]]; then
  print -r -- "resume $(cat "$ID")" > "$O/SESSION"
  "$CODEX" exec resume "$(cat "$ID")" -m "$MODEL" -c model_reasoning_effort="$EFF" -c sandbox_mode=workspace-write "${WEB[@]}" \
    --skip-git-repo-check -o "$O/LAST-MESSAGE.md" - < "$O/PROMPT.sent.md" > "$O/codex.log" 2>&1
  rc=$?
else
  "$CODEX" exec -C "$CWD" -s workspace-write -m "$MODEL" -c model_reasoning_effort="$EFF" "${WEB[@]}" \
    --skip-git-repo-check -o "$O/LAST-MESSAGE.md" - < "$O/PROMPT.sent.md" > "$O/codex.log" 2>&1
  rc=$?
  crd_capture_codex_session "$O/codex.log" "$ID"
  [[ -s $ID ]] && print -r -- "new $(cat "$ID")" > "$O/SESSION"
fi
crd_finish "$O" $rc
exit $rc
