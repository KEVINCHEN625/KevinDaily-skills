#!/bin/bash
# usage: merge-lane.sh <lane-worktree> <lane-branch> <instance-worktree> <instance-branch> [check-cmd ...]
# The only way to merge a reviewed lane into a running instance:
#   1. merge <instance-branch> into the lane (abort on conflict);
#   2. run every check-cmd inside the lane worktree with `bash -c` — ANY non-zero exit stops here, nothing merged;
#      a check that cannot run (missing node_modules, missing interpreter) is a failure, not a skip;
#   3. `git merge --ff-only <lane-branch>` in the instance worktree;
# Prints MERGE-LANE ok <sha> or MERGE-LANE FAIL: <step>.
# Env: RUN_LOCK=<file>   refuse while that file exists (touch it for the time a page test runs on the instance:
#                        a merge under a tester hot-reloads the code it is testing).
#      LIVE_PORTS="p1 p2" LIVE_WAIT=<sec, default 180>   after the merge poll check-serving.sh until every port is
#                        served from the instance tree by a process started after the new HEAD. A health endpoint
#                        answering 200 proves nothing: the OLD process answers it. Exit 2 "MERGE-LANE NOT-LIVE" on
#                        timeout (the merge itself is done; restart the listed ports).
#      MERGE_LINK_DEPS="web/node_modules …"  relative dependency dirs to symlink from the instance worktree into the
#                        lane worktree when the lane lacks them (so a check can run at all).
# Without LIVE_PORTS: run check-serving.sh yourself and restart what it flags.
# Why: a one-liner once printed "typecheck=1" (dependencies missing in the lane worktree, so the check never ran) and
# merged anyway, because nothing gated on the exit code.
# Example checks: "cd web && ./node_modules/.bin/tsc --noEmit -p ."  "python3 -m pytest -q tests/test_x.py"
set -u
lw="${1:?lane worktree}"; lb="${2:?lane branch}"; iw="${3:?instance worktree}"; ib="${4:?instance branch}"; shift 4
here=$(cd "$(dirname "$0")" && pwd)
if [ -n "${RUN_LOCK:-}" ] && [ -e "$RUN_LOCK" ]; then echo "MERGE-LANE FAIL: a run is in progress on the instance ($RUN_LOCK) — merge between runs"; exit 1; fi
[ "$(git -C "$iw" rev-parse --abbrev-ref HEAD)" = "$ib" ] || { echo "MERGE-LANE FAIL: $iw is not on $ib"; exit 1; }
[ "$(git -C "$lw" rev-parse --abbrev-ref HEAD)" = "$lb" ] || { echo "MERGE-LANE FAIL: $lw is not on $lb"; exit 1; }
[ -z "$(git -C "$lw" status --porcelain --untracked-files=no)" ] || { echo "MERGE-LANE FAIL: lane worktree has uncommitted changes"; exit 1; }
if ! git -C "$lw" merge -q --no-edit "$ib" >/dev/null 2>&1; then
  git -C "$lw" merge --abort 2>/dev/null; echo "MERGE-LANE FAIL: conflict merging $ib into $lb"; exit 1
fi
for dep in ${MERGE_LINK_DEPS:-}; do
  case "$dep" in /*|..|../*|*/../*|*/..|.git|.git/*) echo "MERGE-LANE FAIL: MERGE_LINK_DEPS entry must be relative without .. or .git: $dep"; exit 1;; esac
  if [ -d "$lw/$(dirname "$dep")" ] && [ ! -e "$lw/$dep" ] && [ -d "$iw/$dep" ]; then
    ln -s "$iw/$dep" "$lw/$dep" && echo "linked $dep from the instance"
  fi
done
n=0
for c in "$@"; do
  n=$((n+1)); out=$( cd "$lw" && bash -c "$c" 2>&1 ); rc=$?
  echo "check $n rc=$rc: $c"; echo "$out" | grep -E "passed|failed|error|Error|Tests |Test Files" | tail -4 | sed 's/^/    /'
  [ $rc -eq 0 ] || { echo "MERGE-LANE FAIL: check $n"; exit 1; }
done
git -C "$iw" merge -q --ff-only "$lb" || { echo "MERGE-LANE FAIL: ff-only into $ib"; exit 1; }
echo "MERGE-LANE ok $(git -C "$iw" rev-parse --short=9 HEAD)"
if [ -n "${LIVE_PORTS:-}" ]; then
  waitmax="${LIVE_WAIT:-180}"; case "$waitmax" in ""|*[!0-9]*) waitmax=180;; esac
  t=0; sv=""
  while :; do
    # shellcheck disable=SC2086
    sv=$(bash "$here/check-serving.sh" "$iw" $LIVE_PORTS)
    case "$(echo "$sv" | tail -1)" in *"SERVING-CHECK PASS") echo "MERGE-LANE live after ${t}s"; break;; esac
    [ "$t" -ge "$waitmax" ] && { echo "$sv" | sed 's/^/  /'; echo "MERGE-LANE NOT-LIVE after ${t}s: restart the port(s) above from $iw"; exit 2; }
    sleep 5; t=$((t+5))
  done
fi
