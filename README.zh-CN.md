# Kevin’s Daily Skills

[English](README.md) · [简体中文](README.zh-CN.md)

我在日常工作中使用并持续改进的 AI Agent Skills：多 agent 协作、代码审核，以及从项目经验中整理出来的可复用工作流程。

每个 skill 都放在 `skills/` 下的独立目录中，可以单独安装。目前先分享一个软件项目调度中枢，之后会逐步加入其他成熟的工作流程。

## Skills 目录

| Skill | 解决什么问题 | 使用入口 |
| --- | --- | --- |
| **`coordinator-review-drive`** | 通过本机 coding harness 把一个主目标推进到可检查的完成状态：结合能力与额度分配任务，凭证据审核交付，发现推进卡住，并记录经验供后续任务参考。 | [使用说明](skills/coordinator-review-drive/README.md) · [完整示例](docs/examples/coordinator-review-drive.md) |

## 安装一个 skill

使用 [Skills CLI](https://github.com/vercel-labs/skills)：

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --skill coordinator-review-drive
```

也可以先查看仓库内的技能列表：

```bash
npx skills add KEVINCHEN625/KevinDaily-skills --list
```

安装器会让你选择目标 agent。全局安装、手动安装和运行环境要求见[安装指南](docs/installation.md)。

## 第一个 skill：审核推进调度中枢

**Coordinator Review Drive** 让一个 agent 担任项目主控，组织其他 agents 承担开发、调查、测试与独立审核。

它包含以下环节：

- **发现环境：**先检查常见本地 CLI 的位置、版本和配置是否存在，再分配任务。
- **分配任务：**结合已确认的模型、任务难度、额度和过去表现，选择执行者与审核者。
- **一个主目标，限制并行数量：**每项工作标明主线或支线；同时最多 2 项支线、共 6 项，支线运行时主线不能空闲。
- **并行推进：**独立任务使用不同 worktree，每条任务线都有经过校验的任务卡和单独的输出目录；每条任务线在独立进程组中运行，并由一个 waiter 等待结果。
- **卡住检测与解卡流程：**运行台账发现连续两次页面测试失败、同一阻塞反复出现，或目标 12 小时没有进展时，强制在下一次页面测试前完成六步：一次收齐全部阻塞、预判后续路径、检验共同前提、全路径回放、削减支线、带选项升级给用户。
- **先回放，再页面测试：**用低成本的全路径回放一次找出全部阻塞；预检确认端口上实际运行的是哪份代码、读取实例日志，没有通过回放就拒绝页面测试。
- **可信的汇报：**任务卡和回复遵循可校验的契约（逐项回答、命令及其原始输出、修复前的失败证据）；审核发现必须附带证明，一次覆盖路径矩阵的每一行，并统计之前漏掉的问题。
- **安全操作：**提交后证明提交确实发生；只有全部检查通过且没有测试在运行时才合并；只停止指定的任务线；只在受保护的根目录内删除计算得到的路径。
- **持续记录：**一个 `HANDOFF.md` 续接文件，加上决策、运行台账、模型分工和经验，便于在上下文压缩和新会话后接续。

例如，可以这样开始：

```text
请使用 coordinator-review-drive 担任这个项目的审核推进主控。
目标：完成已经确认的功能，并按照验收标准验证结果。
先检查可用 harness，确认模型分工与额度预算，再拆分独立任务并行推进。
合并前审核每项改动，记录各模型擅长什么、出现过什么问题，以及后续怎样分配任务。
```

这个 skill 提供流程指令和执行适配脚本。主控需要能够读写文件、执行本地 shell 命令；你选择使用的 worker CLI 及其账号也需要事先安装和配置。安装 skill 本身不会安装这些 harness，也不会提供对应的订阅额度。

### 当前随包提供的 harness 适配

| Harness | 已包含的适配脚本 |
| --- | --- |
| Codex CLI | 任务执行、命名会话续接，以及可选的浏览器测试入口 |
| Claude Code | Headless 任务执行，可选命名会话续接 |
| ZCode | 审核、小范围编辑执行，以及依赖 macOS 的测试执行器 |
| DeepSeek Harness（`dsh`） | Headless 任务执行、provider/model 配置、有限次数的上游错误重试 |
| 其他 harness | 可以扩展二进制发现列表；实际执行需要对应适配器 |

**发现 CLI 不等于已确认账号和模型可用，也不等于已经适配所有 harness。** 工作流程会在正式派发前确认这些条件。模型经验来自具体项目的实际表现，不是通用排行榜，也不涉及训练模型。

2.0.0 版借鉴并注明出处的思路来自 Lauren Tan 的 [pstack](https://github.com/cursor/plugins/tree/main/pstack) 和 [Matt Pocock 的 skills](https://github.com/mattpocock/skills)，两者均为 MIT 许可。详见该 skill 的[来源说明](skills/coordinator-review-drive/references/SOURCES.md)和[第三方声明](skills/coordinator-review-drive/THIRD_PARTY_NOTICES.md)。

## 仓库组织

| 路径 | 用途 |
| --- | --- |
| `skills/<skill-name>/SKILL.md` | Agent 读取的技能入口与流程指令 |
| `skills/<skill-name>/scripts/` | 随该 skill 一起分发的执行脚本 |
| `skills/<skill-name>/templates/` | 任务卡、审核表和项目记录模板 |
| `skills/<skill-name>/references/` | 按触发条件读取的详细流程说明 |
| `skills/coordinator-review-drive/PLAYBOOK.md` | 给非 Claude Code agent 的简短说明 |
| `docs/installation.md` | 安装方式、依赖和适配范围 |
| `docs/examples/` | 具体使用示例 |

项目运行日志、会话 ID、额度快照和生成的任务记录放在仓库之外。调度中枢会使用独立的 goal 目录保存这些工作状态。

## 参与改进

新增 skill、改进适配器或反馈可复现问题，请参考 [CONTRIBUTING.md](CONTRIBUTING.md)。欢迎分享具体任务、失败条件和验证结果，让改进建立在可检查的证据上。
