# Contributing

Thank you for helping improve Kevin’s Daily Skills. Useful contributions make a recurring task easier to perform, explain the conditions in which they work, and keep the skill practical to maintain.

## Report an issue

Include the skill name, operating system, harness and CLI version, and the smallest steps that reproduce the problem. Describe the expected result and the observed result. For a model-related issue, distinguish the requested model from the model the harness actually reported.

Use sanitized excerpts when logs are necessary. Keep credentials, private project files, personal account details, and generated session state out of issues and pull requests.

## Add a skill

1. Create `skills/<skill-name>/` with a `SKILL.md` entry point. Use a lowercase, hyphen-separated name and the same value in the file’s `name` frontmatter.
2. Explain what the skill does and when an agent should use it in `description`. Make the core workflow understandable without installing unrelated skills.
3. Keep required resources inside the skill directory. Put executable helpers in `scripts/`; use `references/`, `assets/`, or `templates/` when those resources serve the workflow.
4. Document dependencies, supported adapters, and any platform-specific behavior in the skill’s guide. Distinguish implemented support from planned support.
5. Add a practical example and update the catalogs in both root READMEs. Preserve the same names and links across languages.
6. Identify the origin of adapted material and preserve applicable attribution and licensing information.

Avoid generic catch-all skills when a clearly defined task would be easier to trigger and validate. Repository-wide documentation belongs at the root or under `docs/`, rather than being copied into every skill.

## Change an existing skill

Keep changes focused on the reported problem. Preserve the skill name, wrapper arguments, and output-file contracts unless the change deliberately updates them. If behavior or installation changes, update the relevant guide and the root changelog with the migration impact.

For `coordinator-review-drive`, keep the following material consistent:

| Change | Review alongside it |
| --- | --- |
| Coordinator behavior | `SKILL.md`, the matching file in `references/`, and relevant templates (`PLAYBOOK.md` only points to `SKILL.md`) |
| Wrapper arguments or outputs | Script header, skill README, `references/SCRIPTS.md`, `references/DISPATCH.md`, and lane monitoring |
| A new harness adapter | Discovery list, installation requirements, harness coverage tables, and an offline test |
| Model allocation guidance | `references/ROUTING.md`, `ALLOCATION.md` and `AGENT-LESSONS.md` templates; retain the conditions behind observations |
| An idea adapted from another project | `references/SOURCES.md` and, for a new upstream, `THIRD_PARTY_NOTICES.md` with its license text |
| Installation paths | Root READMEs, `docs/installation.md`, and the skill guide |

## Verify the change

From the repository root, run:

```bash
python3 scripts/validate_skills.py
python3 -m unittest discover -s tests -v
```

Check Markdown links, required frontmatter, JSON templates, and the syntax of modified scripts. For executable changes, exercise the behavior that could regress using a temporary project and stub CLIs where possible.

The coordinator wrappers expose `CRD_CODEX_BIN`, `CRD_CLAUDE_BIN`, `CRD_ZCODE_BIN`, and `CRD_DSH_BIN` for alternate executables. These make it possible to verify dispatch arguments and output markers without contacting a model provider.

Report exactly what you verified. An offline stub test establishes local wrapper behavior; it does not establish compatibility with a current provider account, an actual model, or every operating system. Real-provider tests should be explicitly authorized and identified separately.

## Open a pull request

Explain the concrete problem, the resulting behavior, and the evidence used to verify it. Mention changes to dependencies, platform assumptions, permissions, or output formats when relevant. Update the English and Chinese overview if the change affects what users can install or expect.
