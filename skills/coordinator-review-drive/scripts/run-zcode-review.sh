#!/bin/zsh
# run-zcode-review.sh — read-only second review on local zcode (e.g. GLM) in PLAN mode (coordinator-review-drive).
#
# usage: run-zcode-review.sh <G> <read-cwd> <prompt-file> <out-dir> [model-label]
#   read-cwd     the worktree under review (the reviewer cannot write: --mode plan)
#   model-label  only RECORDED in DISPATCH.json (zcode headless has no model/effort flag; the provider
#                config decides the model — report that honestly, e.g. no "max" effort in headless)
# env:
#   CRD_ZCODE_PROVIDER_CONFIG  provider config path exported as ZCODE_BUILTIN_PROVIDER_CONFIG_FILE
#                              (default: /Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json
#                              when that file exists; the wrapper never opens it)
#   CRD_REVIEW_END_MARKER      completeness marker the prompt asks for (default REVIEW-END)
#
# Output: REVIEW.md (also copied to LAST-MESSAGE.md for the waiter) and REVIEW-STATUS = COMPLETE | INCOMPLETE.
# INCOMPLETE usually means truncation or a "will write after approval" preface: re-run into a NEW out dir with
# "output the full report directly in your answer; do not wait for approval; split into parts with end markers".
# Never use the default --prompt mode (yolo) for reviews.
set -u
source "${0:A:h}/lib.zsh"
(( $# == 4 || $# == 5 )) || crd_usage "run-zcode-review.sh <G> <read-cwd> <prompt-file> <out-dir> [model-label]"
G=${1:A}; W=${2:A}; P=${3:A}; O=${4:A}; LABEL=${5:-zcode-provider-default}

crd_check_token model-label "$LABEL"
crd_require_g "$G"; crd_require_dir read-cwd "$W"; crd_require_file prompt-file "$P"
ZCODE=${CRD_ZCODE_BIN:-zcode}; command -v "$ZCODE" >/dev/null || crd_die "zcode not found: $ZCODE"
CFG=${CRD_ZCODE_PROVIDER_CONFIG:-/Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json}
[[ -z ${CRD_ZCODE_PROVIDER_CONFIG:-} || -f $CFG ]] || crd_die "CRD_ZCODE_PROVIDER_CONFIG not found: $CFG"
MARK=${CRD_REVIEW_END_MARKER:-REVIEW-END}

crd_fresh_out "$O"
crd_start "$O" zcode-review "-" "$LABEL" "-" "$W" plan-read-only
trap 'crd_finish "$O" 143; exit 143' TERM HUP
trap 'crd_finish "$O" 130; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

if [[ -f $CFG ]]; then
  ZCODE_BUILTIN_PROVIDER_CONFIG_FILE=$CFG "$ZCODE" --mode plan --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/REVIEW.md" 2> "$O/stderr.log"
else
  "$ZCODE" --mode plan --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/REVIEW.md" 2> "$O/stderr.log"
fi
rc=$?
cp "$O/REVIEW.md" "$O/LAST-MESSAGE.md"
if grep -q -F -- "$MARK" "$O/REVIEW.md"; then print COMPLETE > "$O/REVIEW-STATUS"; else print INCOMPLETE > "$O/REVIEW-STATUS"; fi
crd_finish "$O" $rc
exit $rc
