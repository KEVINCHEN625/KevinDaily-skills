#!/bin/bash
# usage: lane-commit-msg.sh <out-file> <subject> <lane-id> [body-text-file]
# Writes a commit message whose LAST paragraph is exactly the trailers (git only parses trailers in the final
# paragraph; a body after them silently drops them — this happened more than once). Then: git commit -F <out-file>.
# Optional co-author trailer: set COAUTHOR="Name <email>" (none is added when it is unset or empty).
set -u
out="${1:?out file}"; subject="${2:?subject}"; lane="${3:?lane id}"; body="${4:-}"
co="${COAUTHOR:-}"
case "$lane" in *[!A-Za-z0-9._/-]*) echo "LANE-COMMIT-MSG FAIL: lane id must be [A-Za-z0-9._/-]+: '$lane'"; exit 1;; esac
{
  printf '%s\n' "$subject"
  if [ -n "$body" ] && [ -s "$body" ]; then printf '\n'; sed -e '/^Lane:/d' -e '/^Co-Authored-By:/d' "$body"; fi
  printf '\nLane: %s\n' "$lane"
  [ -n "$co" ] && printf 'Co-Authored-By: %s\n' "$co"
} > "$out"
git interpret-trailers --parse < "$out" | grep -q "^Lane: $lane" || { echo "LANE-COMMIT-MSG FAIL: trailers not parsed"; exit 1; }
echo "LANE-COMMIT-MSG ok $out"
