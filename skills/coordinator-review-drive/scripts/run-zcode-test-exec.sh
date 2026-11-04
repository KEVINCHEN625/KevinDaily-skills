#!/bin/zsh
# run-zcode-test-exec.sh — zcode (GLM) executor that CAN run tests, with writes confined by macOS sandbox-exec.
#
# usage: run-zcode-test-exec.sh <G> <worktree> <card-file> <out-dir> <evidence-dir> [model-label]
#   worktree      lane worktree the executor may edit and test in
#   evidence-dir  the only other project directory it may write (reports/logs); created if missing
# zcode runs in `guarded` mode (can execute python/node), but the whole process tree runs under a
# sandbox profile that denies every file write outside: worktree, out-dir, evidence-dir, ~/.zcode
# (its own session state), ~/Library/Caches, and system temp dirs. git metadata of the main repo is NOT writable, so the
# executor cannot commit; the coordinator commits. Reads and network are unrestricted (model API, CPA).
# Output: LAST-MESSAGE.md, stderr.log, SANDBOX.sb, EXIT_CODE, FINISHED_UTC.
set -u
source "${0:A:h}/lib.zsh"
(( $# == 5 || $# == 6 )) || crd_usage "run-zcode-test-exec.sh <G> <worktree> <card-file> <out-dir> <evidence-dir> [model-label]"
G=${1:A}; W=${2:A}; P=${3:A}; O=${4:A}; E=${5:A}; LABEL=${6:-zcode-provider-default}

crd_check_token model-label "$LABEL"
[[ $(uname -s) == Darwin ]] && command -v sandbox-exec >/dev/null || crd_die "run-zcode-test-exec.sh requires macOS sandbox-exec"
crd_require_g "$G"; crd_require_dir worktree "$W"; crd_require_file card-file "$P"
ZCODE=${CRD_ZCODE_BIN:-zcode}; command -v "$ZCODE" >/dev/null || crd_die "zcode not found: $ZCODE"
ZBIN=${$(command -v "$ZCODE"):A}
CFG=${CRD_ZCODE_PROVIDER_CONFIG:-/Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json}
[[ -z ${CRD_ZCODE_PROVIDER_CONFIG:-} || -f $CFG ]] || crd_die "CRD_ZCODE_PROVIDER_CONFIG not found: $CFG"
case $E in
  $HOME|$HOME/Desktop|/) crd_die "evidence-dir too broad: $E";;
esac
[[ $W != "$E"/* ]] || crd_die "evidence-dir must not be an ancestor of the worktree: $E"
# SBPL embeds path strings; reject characters that would change the sandbox policy.
TMPREAL=${${TMPDIR:-/tmp}:A}
for v in "$W" "$O" "$E" "$HOME" "$TMPREAL"; do
  [[ $v != *\"* && $v != *\\* && $v != *$'\n'* && $v != *$'\r'* ]] || crd_die "sandbox paths cannot contain quotes, backslashes or newlines"
done
mkdir -p "$E" || crd_die "cannot create evidence-dir: $E"

crd_fresh_out "$O"
crd_start "$O" zcode-test-exec "-" "$LABEL" "-" "$W" "guarded+sandbox"
trap 'crd_finish "$O" 143; exit 143' TERM HUP
trap 'crd_finish "$O" 130; exit 130' INT
crd_compose_prompt "$G" "$P" "$O/PROMPT.sent.md"

# Paths above resolve symlinks (/tmp -> /private/tmp) before creating subpath rules.
cat > "$O/SANDBOX.sb" <<EOF
(version 1)
(allow default)
(deny file-write*)
(allow file-write*
  (subpath "$W")
  (subpath "$O")
  (subpath "$E")
  (subpath "$HOME/.zcode")
  (subpath "$HOME/Library/Caches")
  (subpath "/private/tmp")
  (subpath "/private/var/folders")
  (subpath "$TMPREAL")
  (literal "/dev/null") (literal "/dev/zero") (literal "/dev/dtracehelper")
  (regex #"^/dev/tty")
  (regex #"^/dev/fd/"))
EOF

if [[ -f $CFG ]]; then
  ZCODE_BUILTIN_PROVIDER_CONFIG_FILE=$CFG sandbox-exec -f "$O/SANDBOX.sb" "$ZBIN" --mode guarded --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/LAST-MESSAGE.md" 2> "$O/stderr.log"
else
  sandbox-exec -f "$O/SANDBOX.sb" "$ZBIN" --mode guarded --cwd "$W" -p "$(cat "$O/PROMPT.sent.md")" > "$O/LAST-MESSAGE.md" 2> "$O/stderr.log"
fi
rc=$?
crd_finish "$O" $rc
exit $rc
