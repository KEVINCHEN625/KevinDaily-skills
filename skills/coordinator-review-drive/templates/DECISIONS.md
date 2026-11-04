# DECISIONS — <GOAL TITLE>

<!--
Format rules (delete this comment block in a real goal if you like):
- One entry per decision, numbered D-001, D-002, … never renumbered, never deleted. Append only.
- Heading: "## D-NNN <one-line result-first title>（<who>，<date>）"
    who = 主控 / coordinator (your ruling) | 用户 / user (quote the user's words verbatim) | 主控裁决 for key designs.
- Write in the user's language, plain and readable: short bullets, no internal jargon dumps, numbers with units.
- Typical body (use only what applies):
    - 事实 / Facts: what happened, via which real path, with IDs and counters; what did NOT change.
    - 定性 / Severity: P0 (data loss/safety) · P1 (blocks the user / dead end / trust) · P2 · P3.
    - 根因 / Root cause: file:line; mark CONFIRMED vs 推断/INFERRED (待证实).
    - 裁决 / Ruling: the decided direction as constraints (what must hold, what is forbidden).
    - 分派 / Dispatch: executor session, worktree/branch @base, what to run; then second review, retest.
    - 验收 / Acceptance: the observable pass criteria.
- Follow-ups to an earlier entry are appended as a bullet under the newest entry:
    "- D-NNN 补充 / follow-up: <result> (diff stat; tests pass/fail with IDs; commit sha)".
- Record honestly: a hang is HANG, a sandbox-denied test is NOT RUN, inherited failures are listed by ID.
- User instructions that change how you work get their own entry with the user's words quoted.
-->

## D-001 环境与模型确认（用户确认，<YYYY-MM-DD>）
- 探测（scripts/probe-agents.sh）：<binaries and versions>；未读取任何凭据。
- 用户确认可用：<agent → model → account/quota notes>；不可用或受限：<…>。
- 分工（详见 ALLOCATION.md）：主实施 <…>；快速执行 <…>；必审二审 <…>；关键设计交叉审 <…>；疑难子 agent <…>；主控 <…>。
- 授权范围：push/部署 <否/仅本地测试实例>；真实模型调用 <范围/上限>；用户数据 <不上传>。

## D-002 <example> 某功能保存后刷新丢失：先抓真实请求再修（主控，<YYYY-MM-DD>）
- 事实：真实页面编辑摘要并保存，提示“已保存”、版本号 +1，刷新后改动丢失（PUT 200，两次复现）。
- 定性：P1，数据丢失。
- 裁决：先在真实层取证（PUT body、DB 前后对比），确认是前端未带上改动还是服务端改写，再修；测试不得固化未证实的前提。
- 分派：<session>，工作树 <lane>（基于 <sha>），RED 先行；完成后二审，再真实页面复测。
- D-002 补充：<result>。
