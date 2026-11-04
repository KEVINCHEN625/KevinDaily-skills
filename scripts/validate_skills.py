#!/usr/bin/env python3
"""Validate distributable skill files without running a model or reading user configuration."""

from __future__ import annotations

import ast
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

try:
    import yaml
except ImportError:
    raise SystemExit("Install validation dependencies: python3 -m pip install -r requirements-dev.txt")


ROOT = Path(__file__).resolve().parents[1]
IGNORED = {".git", ".venv", "node_modules", "__pycache__", ".pytest_cache"}
NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
LOCAL_LINK = re.compile(r"!?\[[^\]\n]*\]\(([^\s)]+)(?:\s+[\"'][^\n]*?[\"'])?\)")


def main() -> int:
    errors: list[str] = []
    checked = {"skills": 0, "json": 0, "python": 0, "shell": 0, "links": 0}

    def error(path: Path, message: str) -> None:
        errors.append(f"{path.relative_to(ROOT)}: {message}")

    skill_files = sorted((ROOT / "skills").glob("*/SKILL.md"))
    if not skill_files:
        errors.append("skills/: no installable skills found")
    if (ROOT / "SKILL.md").exists():
        errors.append("SKILL.md: use README.md for the collection; each skill has its own SKILL.md")
    names: set[str] = set()
    for path in skill_files:
        checked["skills"] += 1
        text = path.read_text(encoding="utf-8")
        match = re.match(r"\A---\n(.*?)\n---(?:\n|\Z)", text, re.DOTALL)
        if not match:
            error(path, "missing YAML frontmatter")
            continue
        try:
            metadata = yaml.safe_load(match.group(1))
        except yaml.YAMLError as exc:
            error(path, f"invalid frontmatter: {exc}")
            continue
        if not isinstance(metadata, dict):
            error(path, "frontmatter must be a mapping")
            continue
        name = metadata.get("name")
        description = metadata.get("description")
        if not isinstance(name, str) or not 1 <= len(name) <= 64 or not NAME.fullmatch(name):
            error(path, "name must be 1–64 lowercase letters/digits separated by single hyphens")
        elif name != path.parent.name:
            error(path, "name must match the skill directory")
        elif name in names:
            error(path, "duplicate skill name")
        else:
            names.add(name)
        if not isinstance(description, str) or not 1 <= len(description.strip()) <= 1024:
            error(path, "description must contain 1–1024 characters")
        if len(text.splitlines()) > 500:
            error(path, "keep the entry point under 500 lines; move detail to referenced files")

    for path in sorted(ROOT.rglob("*")):
        relative = path.relative_to(ROOT)
        if any(part in IGNORED for part in relative.parts) or not path.is_file():
            continue
        if path.is_symlink():
            error(path, "distribution files must not depend on a local symlink")
            continue
        if path.name == ".DS_Store" or path.name.startswith("._") or "__MACOSX" in relative.parts or ".bak" in path.name:
            error(path, "archive metadata or backup file must not be published")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        try:
            if path.suffix == ".json":
                json.loads(text)
                checked["json"] += 1
            elif path.suffix in {".yml", ".yaml"}:
                yaml.safe_load(text)
            elif path.suffix == ".py":
                ast.parse(text, filename=str(relative))
                checked["python"] += 1
            elif path.suffix in {".sh", ".zsh"}:
                first_line = text.splitlines()[0] if text else ""
                shell = "bash" if "bash" in first_line else "zsh"
                binary = shutil.which(shell)
                if binary is None:
                    error(path, f"{shell} is required for syntax validation")
                    continue
                result = subprocess.run([binary, "-n", str(path)], capture_output=True, text=True, timeout=15)
                if result.returncode:
                    error(path, result.stderr.strip() or f"{shell} syntax check failed")
                else:
                    checked["shell"] += 1
        except (ValueError, SyntaxError, yaml.YAMLError, subprocess.TimeoutExpired) as exc:
            error(path, str(exc))
        if path.suffix == ".md":
            prose = re.sub(r"^```[^\n]*\n.*?^```\s*$", "", text, flags=re.MULTILINE | re.DOTALL)
            for match in LOCAL_LINK.finditer(prose):
                target = match.group(1).strip("<>")
                parsed = urlsplit(target)
                if parsed.scheme or parsed.netloc or not parsed.path:
                    continue
                local_path = (path.parent / unquote(parsed.path)).resolve()
                if not local_path.is_relative_to(ROOT):
                    error(path, f"local link leaves repository: {target}")
                elif not local_path.exists():
                    error(path, f"broken local link: {target}")
                else:
                    checked["links"] += 1

    if errors:
        for message in errors:
            print(f"ERROR {message}", file=sys.stderr)
        return 1
    print("PASS " + ", ".join(f"{count} {kind}" for kind, count in checked.items()))
    print("Offline structure, syntax and local-link checks only; no live harness was invoked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
