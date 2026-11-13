#!/bin/zsh
# init-goal.sh — create (or complete) a project goal dir G from the skill templates. Never overwrites.
#
# usage: init-goal.sh <G> [goal-title]
#   Creates G/{lanes,STAGE-REVIEWS,sessions/codex,sessions/claude,e2e-web,model-probes,unstuck} and copies
#   HANDOFF.md DECISIONS.md GOAL-STATE.json AGENT-LESSONS.md ALLOCATION.md POLICY-HEADER.txt LANES.txt and the two
#   PREAMBLE-*.md files (fill their <...> placeholders once per project) when missing.
#   G should live OUTSIDE the product repo (e.g. ~/.local/share/<collection>/goals/<project>-<YYYY-MM-DD>).
set -u
(( $# == 1 || $# == 2 )) || { print -u2 "usage: init-goal.sh <G> [goal-title]"; exit 2; }
G=${1:A}; TITLE=${2:-}
T=${0:A:h:h}/templates
[[ -d $T ]] || { print -u2 "templates dir missing: $T"; exit 2; }
command -v python3 >/dev/null || { print -u2 "python3 is required"; exit 2; }

mkdir -p "$G"/{lanes,STAGE-REVIEWS,sessions/codex,sessions/claude,e2e-web,model-probes,unstuck} || exit 2
for f in HANDOFF.md DECISIONS.md GOAL-STATE.json AGENT-LESSONS.md ALLOCATION.md POLICY-HEADER.txt LANES.txt PREAMBLE-IMPLEMENTER.md PREAMBLE-READONLY.md; do
  if [[ -e $G/$f ]]; then
    print -r -- "keep  $G/$f (exists)"
  else
    cp "$T/$f" "$G/$f" || exit 2
    print -r -- "new   $G/$f"
    if [[ $f == GOAL-STATE.json || $f == DECISIONS.md ]]; then
      python3 -I - "$G/$f" "$TITLE" "$(date -u +%F)" <<'PY_INIT' || exit 2
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
title, today = sys.argv[2:]
text = path.read_text(encoding="utf-8").replace("<YYYY-MM-DD>", today)
if path.suffix == ".json":
    if title:
        text = text.replace('"<GOAL TITLE>"', json.dumps(title, ensure_ascii=False))
    json.loads(text)  # Never write a title that breaks the JSON state file.
elif title:
    text = text.replace("<GOAL TITLE>", title)
path.write_text(text, encoding="utf-8")
PY_INIT
    fi
  fi
done
print -r -- "G=$G"
print "next: run scripts/probe-agents.sh, confirm the environment with the user, record D-001, fill HANDOFF.md"
print "      (MAIN-GOAL, PREDICATE, PROGRESS, ENV, NEXT, WIP), then: bash scripts/goal-check.sh $G"
