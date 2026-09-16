<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

<!-- AI-COLLAB:START -->
# AI 协作协议（人工维护 · trellis update 不会覆盖本节）

**最高原则：大功能 / 新功能 / 需调研 → 慢而全；简单调整 / 简单改动 → 快而准。**
流程重量由「本次改动的影响面」决定，不由任务大小决定。

## 1. 改动分级（每轮动手前先判定）

| 级别 | 判定 | 处理方式 |
| --- | --- | --- |
| 微调 | 单文件 · 纯样式/文案/常量/间距 · 一行式 bug | **直接改 → 结束**。不建任务、不写文档、不 dispatch 子代理、不跑全量类型检查 |
| 常规 | 1–3 个文件 · 逻辑改动 | 直接改 + 改动文件跑 `eslint`。不写文档 |
| 重活 | 跨端/跨包 · 接口/类型/数据流 · 新功能 · 需求模糊 | 走完整 Trellis 流程（prd/design/implement + 子代理 + 全量校验 + Review gate） |

- 任务处于 `in_progress` **不等于**每一轮都要跑完整流程。
- 拿不准时按**更轻一级**处理，先给出可看的结果，不满意再升级。

## 2. 提问协议
- 需要澄清时**一次性批量问**：用 AskUserQuestion 一轮把所有待确认项列全，**禁止一轮一问**。
- 能靠读代码/文档得出结论的，不要问用户。

## 3. 探索协议
- 先 `Grep` 精准定位，再 `Read` 目标片段。**禁止整文件读大文件来"找东西"**。
- 接口请求/响应结构这类黑盒信息，**一次性索要「真实请求 + 真实响应」**，不要靠猜 + 反复试错。

## 4. 响应协议
- 每批工具调用前用**一行文字**说明正在做什么，**禁止长时间静默连发工具**。
- 收尾只说三件事：改了哪些文件、验证了什么、还剩什么待确认。不复述过程。

## 5. 校验分级
| 改动面 | 校验 |
| --- | --- |
| 纯样式/文案/常量 | 不跑，或仅 `npx eslint <file>` |
| 逻辑（`.ts`/`.vue`） | `npx eslint <changed files>` |
| 接口/类型/跨包 | `npx vue-tsc -b` |

## 6. 任务粒度
- 主体交付完成即 `task.py finish`，不拖到收尾。
- 后续 UI 微调**不塞回老任务**，也**不新开任务**。
<!-- AI-COLLAB:END -->
