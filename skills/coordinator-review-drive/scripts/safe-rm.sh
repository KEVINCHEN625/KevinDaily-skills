#!/bin/bash
# usage: safe-rm.sh [--apply] [--allow-work-files] <root> <path> [path...]
# The only way the coordinator deletes a path that was computed (variable, command substitution, list file).
# Why: `P=$(grep … | head -1)` was once empty, `cleanup.sh $U/$P` received the lane root and `rm -rf` deleted a
# whole folder of lane work. Dry run by default: prints what it would remove. --apply deletes.
# Refuses a path (and then deletes NOTHING at all) when it:
#   is empty · is not absolute · contains "/../" or ends in "/.." · does not exist · is a symlink ·
#   resolves to <root> itself or outside <root> · is "/" or $HOME or one level below $HOME ·
#   is a directory holding lane work files (TASK*.md, DECISIONS.md, HANDOFF.md, RUNS.tsv, LAST-MESSAGE.md,
#   REVIEW.md, DESIGN*.md, PLAN*.md, ISSUES*.md, or a .git entry), unless --allow-work-files.
# <root> must be an existing absolute directory at least 3 levels deep (e.g. $HOME/work/tmp-root).
# Exit 0 = dry run printed or deletion done; 1 = refused; 2 = usage.
set -u
apply=0; allow=0
while [ $# -gt 0 ]; do case "$1" in --apply) apply=1; shift;; --allow-work-files) allow=1; shift;; *) break;; esac; done
root="${1:-}"; [ $# -ge 1 ] && shift
[ -n "$root" ] && [ $# -ge 1 ] || { echo "SAFE-RM usage: safe-rm.sh [--apply] [--allow-work-files] <root> <path>..." >&2; exit 2; }
case "$root" in /*) ;; *) echo "SAFE-RM REFUSED: root is not absolute: '$root'"; exit 1;; esac
[ -d "$root" ] && [ ! -L "$root" ] || { echo "SAFE-RM REFUSED: root is not a real directory: '$root'"; exit 1; }
rroot=$(cd "$root" && pwd -P) || exit 1
depth=$(printf '%s' "$rroot" | tr -cd '/' | wc -c | tr -d ' ')
[ "$depth" -ge 3 ] || { echo "SAFE-RM REFUSED: root too shallow: $rroot"; exit 1; }
home=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P || echo "")
targets=()
for p in "$@"; do
  [ -n "$p" ] || { echo "SAFE-RM REFUSED: empty path argument (an unset variable?) — nothing deleted"; exit 1; }
  case "$p" in /*) ;; *) echo "SAFE-RM REFUSED: not absolute: '$p' — nothing deleted"; exit 1;; esac
  case "$p/" in */../*|*/./*) echo "SAFE-RM REFUSED: path has . or .. component: '$p' — nothing deleted"; exit 1;; esac
  [ -L "${p%/}" ] && { echo "SAFE-RM REFUSED: symlink: '$p' — nothing deleted"; exit 1; }
  [ -e "$p" ] || { echo "SAFE-RM REFUSED: does not exist: '$p' — nothing deleted"; exit 1; }
  if [ -d "$p" ]; then rp=$(cd "$p" && pwd -P); else rp="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"; fi
  [ -n "$rp" ] || { echo "SAFE-RM REFUSED: cannot resolve '$p' — nothing deleted"; exit 1; }
  case "$rp" in
    "$rroot") echo "SAFE-RM REFUSED: target is the root itself: $rp — nothing deleted"; exit 1;;
    "$rroot"/*) ;;
    *) echo "SAFE-RM REFUSED: outside root ($rroot): $rp — nothing deleted"; exit 1;;
  esac
  if [ -n "$home" ]; then case "$rp" in "$home"|"$home"/*) rest="${rp#"$home"}"; rest="${rest#/}"
      case "$rest" in ""|*/*) ;; *) echo "SAFE-RM REFUSED: top-level home entry: $rp — nothing deleted"; exit 1;; esac;; esac; fi
  if [ -d "$rp" ] && [ "$allow" != 1 ]; then
    hit=$(find "$rp" -maxdepth 3 \( -name 'TASK*.md' -o -name 'DECISIONS.md' -o -name 'HANDOFF.md' -o -name 'RUNS.tsv' \
      -o -name 'LAST-MESSAGE.md' -o -name 'REVIEW.md' -o -name 'DESIGN*.md' -o -name 'PLAN*.md' -o -name 'ISSUES*.md' \
      -o -name '.git' \) -print 2>/dev/null | head -3)
    [ -z "$hit" ] || { echo "SAFE-RM REFUSED: holds lane work files — nothing deleted: $rp"; echo "$hit" | sed 's/^/  /'; exit 1; }
  fi
  targets+=("$rp")
done
for rp in "${targets[@]}"; do
  size=$(du -sh "$rp" 2>/dev/null | cut -f1)
  if [ "$apply" = 1 ]; then rm -rf -- "$rp" && echo "SAFE-RM removed ${size:-?} $rp"; else echo "SAFE-RM would remove ${size:-?} $rp"; fi
done
[ "$apply" = 1 ] || echo "SAFE-RM dry run: nothing deleted. Read the list, then re-run with --apply."
exit 0
