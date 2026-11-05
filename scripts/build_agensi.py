#!/usr/bin/env python3
"""Build the Agensi distribution without modifying the installable source skill.

Usage: python3 scripts/build_agensi.py /absolute/new-output-directory

Agensi delivers scripts individually into temporary files. This adapter embeds the
shared helpers/default policy into each runner and emits a standalone goal
initializer. The host runs wrappers in managed background tasks, retains their
temporary files until completion, and runs a separately loaded waiter. No skill
directory is installed, and launch-lane.sh is deliberately omitted.

Build output contains no timestamps or absolute source paths. Its content digest
covers sorted relative paths, executable modes and file bytes. This is an offline
packaging operation: it does not execute a harness, fetch dependencies or publish.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "skills" / "coordinator-review-drive"
DEFAULT_DOCS = ROOT / "distribution" / "agensi"
DOCUMENTS = ("SKILL.md", "README.md", "PLAYBOOK.md")
RUNNERS = frozenset({
    "run-codex.sh", "run-codex-web.sh", "run-claude.sh", "run-dsh.sh",
    "run-zcode-review.sh", "run-zcode-exec.sh", "run-zcode-test-exec.sh",
})
OMITTED_SCRIPTS = frozenset({"lib.zsh", "launch-lane.sh"})
# Conservative: all emitted script bytes fit, including embedded data. Agensi's
# published 20 KB logic allowance therefore does not require a data exemption.
MAX_SCRIPT_BYTES = 20_000
LIB_IMPORT = 'source "${0:A:h}/lib.zsh"'


def _replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"source shape changed ({label}); review the adapter before building")
    return text.replace(old, new, 1)


def _read(path: Path) -> bytes:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"expected a regular source file: {path}")
    return path.read_bytes()


def _embedded_helpers(source: Path) -> str:
    lib = _read(source / "scripts" / "lib.zsh").decode("utf-8")
    lib = _replace_once(
        lib,
        'CRD_SCRIPTS_DIR=${${(%):-%x}:A:h}\nCRD_SKILL_DIR=${CRD_SCRIPTS_DIR:h}\n',
        "", "helper installation paths",
    )
    lib = lib.replace(
        "# lib.zsh — shared helpers for the coordinator-review-drive wrappers (zsh only; sourced, not executed).",
        "# Shared coordinator-review-drive helpers embedded for standalone Agensi execution.",
    ).replace(
        "#   launch-lane.sh adds WRAPPER_PID/LAUNCHED_UTC; the legacy wait-lanes.sh adds .seen, .stall-reported, .dead-reported.",
        "#   Direct invocation writes PID; a separately loaded wait-lane.sh accepts that marker.",
    ).replace(
        "(create it with scripts/init-goal.sh)",
        "(create it with the standalone init-goal.sh)",
    )
    start = "# Policy header prepended to executor prompts: G/POLICY-HEADER.txt overrides the skill default.\n"
    end = "crd_capture_codex_session() {"
    if lib.count(start) != 1 or lib.count(end) != 1:
        raise ValueError("source shape changed (policy helper); review the adapter before building")
    before, policy_and_tail = lib.split(start, 1)
    _, tail = policy_and_tail.split(end, 1)
    policy = _read(source / "templates" / "POLICY-HEADER.txt").decode("utf-8")
    policy = policy.replace(
        "[Coordinator policy — prepended to every executor prompt; copy to G/POLICY-HEADER.txt to customize]",
        "[Coordinator policy — embedded default for this task]",
        1,
    ).rstrip("\n")
    delimiter = "CRD_AGENSI_DEFAULT_POLICY_DATA"
    if delimiter in policy.splitlines():
        raise ValueError("default policy collides with its heredoc delimiter")
    compose = (
        "# A user-authored project policy may replace the embedded default.\n"
        "# No reusable policy/template file is installed in the goal directory.\n"
        "crd_compose_prompt() {  # <G> <prompt-file> <dest>\n"
        "  {\n"
        "    if [[ -f $1/POLICY-HEADER.txt ]]; then\n"
        '      cat "$1/POLICY-HEADER.txt"\n'
        "    else\n"
        f"      cat <<'{delimiter}'\n"
        f"{policy}\n{delimiter}\n"
        "    fi\n"
        "    print\n"
        '    cat "$2"\n'
        '  } > "$3"\n'
        "}\n\n"
    )
    return before + compose + end + tail


def _blank_record(value):
    """Retain the supplied state schema while removing examples/claimed facts."""
    if isinstance(value, dict):
        return {key: _blank_record(item) for key, item in value.items()
                if not key.startswith("<")}
    if isinstance(value, list):
        return []
    if isinstance(value, bool):
        return False
    if isinstance(value, str):
        return ""
    return None


def _initializer(source: Path) -> str:
    original = json.loads(_read(source / "templates" / "GOAL-STATE.json"))
    state = _blank_record(original)
    state["mode"]["quota"] = "normal"
    state["coordinator"]["role"] = original["coordinator"]["role"]
    state["authority"]["deploy"] = "none"
    state["authority"]["real_providers"] = "none"
    state["baseline"]["comparison_key"] = original["baseline"]["comparison_key"]
    # repr is a Python string literal inside a quoted shell heredoc. Neither goal
    # titles nor embedded JSON are interpolated into shell program text at runtime.
    state_literal = repr(json.dumps(state, ensure_ascii=False, sort_keys=True))
    return r'''#!/bin/zsh
# Agensi standalone goal initializer. Creates fresh project records, never a skill installation.
# usage: init-goal.sh <G> [goal-title]
# Existing records are preserved. Reusable templates/preambles are read through MCP when needed.
set -u
(( $# == 1 || $# == 2 )) || { print -u2 "usage: init-goal.sh <G> [goal-title]"; exit 2; }
command -v python3 >/dev/null || { print -u2 "python3 is required"; exit 2; }
python3 -I - "$1" "${2:-}" <<'CRD_AGENSI_INIT_PY'
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

# Embedded empty schema data, derived from the source GOAL-STATE.json.
state = json.loads(__STATE_LITERAL__)
goal = Path(sys.argv[1]).expanduser().resolve()
title = sys.argv[2]
now = datetime.now(timezone.utc)
state["goal"] = title
state["created_utc"] = now.date().isoformat()
state["updated_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")

for relative in ("lanes", "STAGE-REVIEWS", "sessions/codex", "sessions/claude",
                 "e2e-web", "model-probes"):
    (goal / relative).mkdir(parents=True, exist_ok=True)

records = {
    "GOAL-STATE.json": json.dumps(state, indent=2, ensure_ascii=False) + "\n",
    "DECISIONS.md": "# Decisions — " + title + "\n\n",
    "AGENT-LESSONS.md": (
        "# Agent lessons — " + title + "\n\n## Observations\n\n"
        "| Date | Harness / version | Verified model | Task | Evidence | Outcome | Next assignment |\n"
        "| --- | --- | --- | --- | --- | --- | --- |\n"
    ),
    "ALLOCATION.md": (
        "# Allocation — " + title + "\n\n"
        "| Role | Harness | Requested model | Verified model | Effort | Budget / quota | Evidence |\n"
        "| --- | --- | --- | --- | --- | --- | --- |\n\n"
        "## Session affinity\n\n| Task type | Session | Harness |\n| --- | --- | --- |\n\n"
        "## Provider status\n\n| Harness | Status | Verified at | Evidence |\n| --- | --- | --- | --- |\n"
    ),
    "LANES.txt": "# out-dir [label] [stall-seconds]\n",
}
for name, content in records.items():
    path = goal / name
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
    except FileExistsError:
        print(f"keep  {path} (exists)")
    else:
        print(f"new   {path}")
print(f"G={goal}")
print("next: inspect available harnesses and record the confirmed project inputs.")
CRD_AGENSI_INIT_PY
'''.replace("__STATE_LITERAL__", state_literal)


def _standalone_script(path: Path, source: Path, helpers: str) -> bytes:
    text = _read(path).decode("utf-8")
    if path.name in RUNNERS:
        text = _replace_once(text, LIB_IMPORT, helpers.rstrip("\n"), path.name)
        text = text.replace(
            "# The policy header (G/POLICY-HEADER.txt, else templates/POLICY-HEADER.txt) is prepended to the prompt.",
            "# A user project policy (G/POLICY-HEADER.txt), or the embedded default, is prepended.",
        ).replace(
            "Launch it with launch-lane.sh and wait with wait-lane.sh.",
            "Run through host-managed background execution; load wait-lane.sh separately.",
        )
    elif path.name == "init-goal.sh":
        text = _initializer(source)
    elif path.name == "wait-lane.sh":
        # With a separately scheduled temporary wrapper, the waiter can start
        # before crd_start writes PID. Recheck while missing; keep the remainder
        # of the original completion/stall/error protocol unchanged.
        check = '  if [ -n "$wpid" ] && ! alive "$wpid"; then\n'
        refresh = (
            '  if [ -z "$wpid" ]; then\n'
            '    [ -f "$out/WRAPPER_PID" ] && wpid=$(cat "$out/WRAPPER_PID")\n'
            '    [ -n "$wpid" ] || { [ ! -f "$out/PID" ] || wpid=$(cat "$out/PID"); }\n'
            '  fi\n'
        )
        text = _replace_once(text, check, refresh + check, "waiter startup PID refresh")
    if re.search(r"^\s*(?:source|\.)\s+", text, re.MULTILINE):
        raise ValueError(f"script still sources an external helper: {path.name}")
    if "CRD_SKILL_DIR" in text or "CRD_SCRIPTS_DIR" in text:
        raise ValueError(f"script still depends on an installed skill directory: {path.name}")
    data = text.encode("utf-8")
    if len(data) > MAX_SCRIPT_BYTES:
        raise ValueError(f"script exceeds the conservative {MAX_SCRIPT_BYTES}-byte budget: {path.name}")
    return data


def build_package(source: Path, output: Path, docs: Path | None = None) -> dict:
    """Create a new/empty package directory and return a reproducible build report."""
    if not output.is_absolute():
        raise ValueError("output must be an absolute path")
    source = source.resolve(strict=True)
    docs = docs.resolve() if docs is not None else None
    output = output.resolve()
    for protected in (source, docs):
        if protected is not None and (output == protected or output.is_relative_to(protected)
                                      or protected.is_relative_to(output)):
            raise ValueError("output must be outside the source and documentation directories")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("output must be new or an empty directory; existing files will not be replaced")

    entries = {}
    overrides = []
    for name in DOCUMENTS:
        override = docs / name.replace(".md", ".source.md") if docs is not None else None
        selected = override if override is not None and override.is_file() else source / name
        entries[name] = (_read(selected), 0o644)
        if selected == override:
            overrides.append(name)

    helpers = _embedded_helpers(source)
    found_runners = set()
    for path in sorted((source / "scripts").iterdir()):
        if path.name in OMITTED_SCRIPTS:
            continue
        if not path.is_file() or path.suffix not in {".sh", ".py", ".zsh"}:
            raise ValueError(f"unexpected script source: {path}")
        entries[f"scripts/{path.name}"] = (_standalone_script(path, source, helpers), 0o755)
        if path.name in RUNNERS:
            found_runners.add(path.name)
    if found_runners != RUNNERS:
        raise ValueError(f"missing required runners: {sorted(RUNNERS - found_runners)}")
    for path in sorted((source / "templates").rglob("*")):
        if path.is_symlink():
            raise ValueError(f"template symlink is not supported: {path}")
        if path.is_file():
            entries[path.relative_to(source).as_posix()] = (_read(path), 0o644)

    # Build everything before touching output. Generated docs are copied byte for
    # byte; the original skill and repository remain unchanged.
    output.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    sizes = {}
    for relative, (data, mode) in sorted(entries.items()):
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as handle:
            handle.write(data)
        destination.chmod(mode)
        digest.update(f"{relative}\0{mode:o}\0{len(data)}\0".encode("utf-8"))
        digest.update(data)
        if relative.startswith("scripts/"):
            sizes[relative] = len(data)
    return {
        "files": len(entries),
        "scripts": len(sizes),
        "templates": sum(name.startswith("templates/") for name in entries),
        "bytes": sum(len(data) for data, _ in entries.values()),
        "content_sha256": digest.hexdigest(),
        "documentation_overrides": overrides,
        "missing_documentation_overrides": [name for name in DOCUMENTS if name not in overrides],
        "script_bytes": sizes,
        "max_script_bytes": max(sizes.values()),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="absolute path to a new or empty package directory")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--docs", type=Path, default=DEFAULT_DOCS)
    args = parser.parse_args()
    try:
        report = build_package(args.source, args.output, args.docs)
    except (OSError, ValueError, KeyError) as exc:
        print(f"build failed: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
