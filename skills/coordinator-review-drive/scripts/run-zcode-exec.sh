#!/bin/zsh
# run-zcode-exec.sh — zcode (e.g. GLM) as a SMALL-EDIT EXECUTOR in edit mode (coordinator-review-drive).
#
# usage: run-zcode-exec.sh <G> <worktree> <card-file> <out-dir> [model-label]
#   worktree     the lane worktree the executor may edit (--mode edit; never yolo/build)
#   card-file    task card FILE (not text); G/POLICY-HEADER.txt is prepended
#   model-label  only RECORDED in DISPATCH.json (the provider config decides the model)
# env:
#   CRD_ZCODE_MODE             edit (default) or guarded (can run tests; writes are NOT sandboxed — card must restrict scope)
#   CRD_ZCODE_PROVIDER_CONFIG  provider config path exported as ZCODE_BUILTIN_PROVIDER_CONFIG_FILE
#                              (default: /Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json
#                              when that file exists; the wrapper never opens it)
#
# Output: LAST-MESSAGE.md (the executor's reply), stderr.log, EXIT_CODE, FINISHED_UTC.
# Observed behaviour: in edit mode the sandbox may refuse python/node/git, so the executor cannot run tests. The card
# must say "do not run git or tests; the coordinator runs them". The coordinator then runs the tests, and a DIFFERENT
# model reviews the diff (this model is the usual second reviewer; it never reviews its own change).
set -u
source "${0:A:h}/lib.zsh"
(( $# == 4 || $# == 5 )) || crd_usage "run-zcode-exec.sh <G> <worktree> <card-file> <out-dir> [model-label]"
G=${1:A}; W=${2:A}; P=${3:A}; O=${4:A}; LABEL=${5:-zcode-provider-default}

crd_check_token model-label "$LABEL"
crd_require_g "$G"; crd_require_dir worktree "$W"; crd_require_file card-file "$P"
ZCODE=${CRD_ZCODE_BIN:-zcode}; command -v "$ZCODE" >/dev/null || crd_die "zcode not found: $ZCODE"
ZMODE=${CRD_ZCODE_MODE:-edit}; [[ $ZMODE == edit || $ZMODE == guarded ]] || crd_die "CRD_ZCODE_MODE must be edit or guarded"
CFG=${CRD_ZCODE_PROVIDER_CONFIG:-/Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json}
[[ -z ${CRD_ZCODE_PROVIDER_CONFIG:-} || -f $CFG ]] || crd_die "CRD_ZCODE_PROVIDER_CONFIG not found: $CFG"

crd_fresh_out "$O"
crd_start "$O" zcode-exec "-" "$LABEL" "-" "$W" "$ZMODE"
trap 'crd_finish "$O" 143; exit 143' TERM HUP
trap 'crd_finish "$O" 130; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

if [[ -f $CFG ]]; then
  ZCODE_BUILTIN_PROVIDER_CONFIG_FILE=$CFG "$ZCODE" --mode "$ZMODE" --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/LAST-MESSAGE.md" 2> "$O/stderr.log"
else
  "$ZCODE" --mode "$ZMODE" --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/LAST-MESSAGE.md" 2> "$O/stderr.log"
fi
rc=$?
crd_finish "$O" $rc
exit $rc
