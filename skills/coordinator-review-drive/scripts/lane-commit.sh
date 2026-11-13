#!/bin/bash
# usage: lane-commit.sh <worktree> <subject> <lane-id> [path ...]
# Commits a lane's change with correct trailers and PROVES it happened. With no paths it lists every changed and
# untracked file from `git status --porcelain -z` and adds them by exact name (never `git add -A`). Prints the files,
# then `LANE-COMMIT ok <sha>` only if HEAD moved and the listed files are no longer dirty; otherwise LANE-COMMIT FAIL.
# Why: an unquoted file list under zsh was once passed as ONE path, `git add` failed, the commit never happened,
# and the reviewer was launched on the base SHA. Env COAUTHOR is passed to lane-commit-msg.sh.
set -u
wt="${1:?worktree}"; subject="${2:?subject}"; lane="${3:?lane id}"; shift 3
here=$(cd "$(dirname "$0")" && pwd)
cd "$wt" || { echo "LANE-COMMIT FAIL: no worktree $wt"; exit 1; }
before=$(git rev-parse HEAD)
files=()
if [ $# -gt 0 ]; then files=("$@"); else
  skip=0   # a rename/copy record "R  new\0old\0" carries the old path as an extra NUL field: skip it
  while IFS= read -r -d '' rec; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "${rec:0:2}" in R*|C*|?R|?C) skip=1;; esac
    path="${rec:3}"; [ -n "$path" ] && files+=("$path")
  done < <(git status --porcelain -z --untracked-files=all)
fi
[ ${#files[@]} -gt 0 ] || { echo "LANE-COMMIT FAIL: nothing to commit"; exit 1; }
printf '  %s\n' "${files[@]}"
git add -- "${files[@]}" || { echo "LANE-COMMIT FAIL: git add"; exit 1; }
msg=$(mktemp "${TMPDIR:-/tmp}/lane-msg.XXXXXX")
bash "$here/lane-commit-msg.sh" "$msg" "$subject" "$lane" >/dev/null || { rm -f "$msg"; echo "LANE-COMMIT FAIL: message"; exit 1; }
git commit -q -F "$msg"; rc=$?; rm -f "$msg"
after=$(git rev-parse HEAD)
[ $rc -eq 0 ] && [ "$after" != "$before" ] || { echo "LANE-COMMIT FAIL: HEAD did not move (rc=$rc)"; exit 1; }
dirty=$(git status --porcelain -- "${files[@]}")
[ -z "$dirty" ] || { echo "LANE-COMMIT FAIL: still dirty: $dirty"; exit 1; }
echo "LANE-COMMIT ok $(git rev-parse --short=9 HEAD)"
