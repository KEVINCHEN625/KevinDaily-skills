# Changelog

## 2026-11-04 — Initial public collection

- Publish `coordinator-review-drive` as the first independently installable skill under `skills/`.
- Add English and Chinese repository introductions, installation guidance, a worked example and contribution guidance.
- Preserve the supplied coordination workflow, CLI adapters, review templates and author-observed lessons.
- Remove macOS archive metadata and historical backup copies from the distributable source.
- Resolve the skill location from its actual installation, remove project-specific names, and clarify implemented adapters.
- Align goal-resume instructions with the current `HANDLED` marker and correct template references.
- Use one absolute output directory per task, pass actual report paths to reviewers, and preserve full reports in final output when the harness cannot write external files.
- Add offline structure, syntax, local-link and wrapper validation, with a GitHub Actions workflow.
- Preserve valid JSON when a goal title contains quotes, backslashes or newlines.
- Prevent reused launcher output and incomplete session locks from overwriting another run.
- Correct GNU/BSD timestamp detection in lane waiters and propagate malformed/error Claude results.
- Restrict permission-override inputs, prepend the shared policy to ZCode review prompts, and check platform-specific requirements.
- Preserve existing wrapper arguments; `CRD_CODEX_EXTRA` now accepts only `-c service_tier=<tier>` and Claude permission mode accepts only `default`, `acceptEdits`, `plan` or `dontAsk`.

## Supplied skill history

- **2026-10-17:** independent review, gate comparison, quota fallback, deployment handoff and stage acceptance reports.
- **2026-10-27:** quota pacing, executor trials, process ownership and bounded browser supervision.
- **2026-11-04:** detached lane launching, one waiter per lane, explicit result markers and report handling.

These historical dates come from the uploaded skill's notes; they are not GitHub release tags.
