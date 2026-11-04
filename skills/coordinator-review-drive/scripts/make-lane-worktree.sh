#!/bin/zsh
# make-lane-worktree.sh — one isolated git worktree + branch per lane (coordinator-review-drive).
#
# usage: make-lane-worktree.sh <repo> <worktrees-root> <slug> <base-ref> [shared-relpath ...]
#   Creates <worktrees-root>/<slug> on new branch ${CRD_BRANCH_PREFIX:-lane}/<slug> from <base-ref>, then
#   symlinks each shared-relpath (installed deps such as backend/.venv, frontend/node_modules) from <repo>
#   so the lane does not reinstall anything.
# env: CRD_BRANCH_PREFIX (default lane), CRD_LANE_WORKDIR (e.g. .lane-work: appended once to the repo's
#      LOCAL .git/info/exclude so executor scratch dirs never show up in git status; opt-in).
#
# Local git write only (worktree add + new branch). Never pushes, never touches existing branches/worktrees,
# refuses an existing target path or branch. Coordinator runs this (executor sandboxes usually cannot write
# shared git metadata). Note: some sandboxes cannot follow symlinks that point outside their roots — if a
# lane's tools are denied access, materialize a copy of that dependency inside the lane instead.
set -eu
(( $# >= 4 )) || { print -u2 "usage: make-lane-worktree.sh <repo> <worktrees-root> <slug> <base-ref> [shared-relpath ...]"; exit 2; }
R=${1:A}; ROOT=${2:A}; SLUG=$3; BASE=$4; shift 4
[[ $SLUG =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] || { print -u2 "bad slug: $SLUG"; exit 2; }
PFX=${CRD_BRANCH_PREFIX:-lane}
[[ $PFX =~ '^[A-Za-z0-9][A-Za-z0-9._/-]*$' ]] || { print -u2 "bad CRD_BRANCH_PREFIX: $PFX"; exit 2; }
BR=$PFX/$SLUG; L=$ROOT/$SLUG
# Shared dependencies must stay under each checkout; validate before creating any branch.
for p in "$@"; do
  [[ -n $p && $p != /* && $p != .. && $p != ../* && $p != */../* && $p != */.. && $p != .git && $p != .git/* ]] || {
    print -u2 "shared-relpath must be relative, with no .. or .git components: $p"; exit 2;
  }
done
git check-ref-format --branch "$BR" >/dev/null

git -C "$R" rev-parse --git-dir >/dev/null
[[ ! -e $L ]] || { print -u2 "REFUSED: target exists: $L"; exit 2; }
if git -C "$R" rev-parse --verify -q "refs/heads/$BR" >/dev/null; then print -u2 "REFUSED: branch exists: $BR"; exit 2; fi
git -C "$R" rev-parse --verify -q "$BASE^{commit}" >/dev/null || { print -u2 "REFUSED: unknown base: $BASE"; exit 2; }

mkdir -p "$ROOT"
git -C "$R" worktree add -b "$BR" "$L" "$BASE" >/dev/null
for p in "$@"; do
  if [[ ! -e $R/$p ]]; then print -u2 "skip (missing in repo): $p"; continue; fi
  if [[ -e $L/$p || -L $L/$p ]]; then print -u2 "skip (already in lane): $p"; continue; fi
  mkdir -p "${L}/${p:h}"
  ln -s "${${:-$R/$p}:A}" "$L/$p"   # one-hop link to the canonical (symlink-resolved) path
done
if [[ -n ${CRD_LANE_WORKDIR:-} ]]; then
  EX=$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)/info/exclude
  grep -qxF -- "${CRD_LANE_WORKDIR%/}/" "$EX" 2>/dev/null || print -r -- "${CRD_LANE_WORKDIR%/}/" >> "$EX"
fi
print -r -- "$L"
print -r -- "branch: $BR"
git -C "$L" log --oneline -1
print -r -- "dirty entries: $(git -C "$L" status --porcelain | wc -l | tr -d ' ')"
