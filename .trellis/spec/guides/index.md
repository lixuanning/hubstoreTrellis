# Thinking Guides

> **Purpose**: Expand your thinking to catch things you might not have considered.

---

## Why Thinking Guides?

**Most bugs and tech debt come from "didn't think of that"**, not from lack of skill:

- Didn't think about what happens at layer boundaries → cross-layer bugs
- Didn't think about code patterns repeating → duplicated code everywhere
- Didn't think about edge cases → runtime errors
- Didn't think about future maintainers → unreadable code

These guides help you **ask the right questions before coding**.

---

## Available Guides

| Guide | Purpose | When to Use |
|-------|---------|-------------|
| [Architecture Overview](./architecture-overview.md) | Project architecture, call chain, response format | **ALWAYS — before any code** |
| [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md) | Identify patterns and reduce duplication | When you notice repeated patterns |
| [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md) | Think through data flow across layers | Features spanning multiple layers |

---

## Quick Reference: Thinking Triggers

### When to Think About Cross-Layer Issues

- [ ] Feature touches 3+ layers (API, Service, Component, Database)
- [ ] Data format changes between layers
- [ ] Multiple consumers need the same data
- [ ] You're not sure where to put some logic
- [ ] You are adding an event kind, JSONL record, RPC payload, or config field
- [ ] UI / command code starts casting raw payload fields directly

→ Read [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md)

### When to Think About Code Reuse

- [ ] You're writing similar code to something that exists
- [ ] You see the same pattern repeated 3+ times
- [ ] You're adding a new field to multiple places
- [ ] **You're modifying any constant or config**
- [ ] **You're creating a new utility/helper function** ← Search first!
- [ ] Two files read the same untyped payload field with local casts
- [ ] Multiple branches update the same derived state from `kind` / `action`

→ Read [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md)

### When Verifying AI Cross-Review Results

- [ ] Reviewer claims "user input can be malicious" → Check the actual data source (internal manifest? user config? external API?)
- [ ] Reviewer flags "missing validation" → Is the data from a trusted internal source?
- [ ] Reviewer says "behavior change" → Read the code comments — is it intentional design?
- [ ] Reviewer identifies a "bug" in test → Mentally delete the feature being tested — does the test still pass? If yes → tautological test

**Common AI reviewer false-positive patterns**:
1. **Trust boundary confusion**: Treating internal data (bundled JSON manifests) as untrusted external input
2. **Ignoring design comments**: Flagging intentional behavior documented in code comments as bugs
3. **Variable misreading**: Not tracing a variable to its actual definition (e.g., Map keyed by path vs name)

**Verification rule**: Every CRITICAL/WARNING finding must be verified against the actual code before prioritizing. Budget ~35% false-positive rate for AI reviews.

---

## Pre-Modification Rule (CRITICAL)

> **Before changing ANY value, ALWAYS search first!**

```bash
# Search for the value you're about to change
grep -r "value_to_change" .
```

This single habit prevents most "forgot to update X" bugs.

---

## How to Use This Directory

1. **Before coding**: Skim the relevant thinking guide
2. **During coding**: If something feels repetitive or complex, check the guides
3. **After bugs**: Add new insights to the relevant guide (learn from mistakes)

---

## SDD Workflow

Trellis SDD (Spec-Driven Development) works in two layers:

### Task-Level (Daily Development)

| Phase | Artifacts | Who Provides |
|-------|-----------|--------------|
| Plan | `prd.md` | AI + PM |
| Plan | `design.md` (complex tasks) | AI |
| Plan | `implement.md` (complex tasks) | AI |
| Execute | Code + lint + type-check + curl | AI |

Tasks are small and frequent — a single feature may span 5-10 tasks. Code-level quality (lint, type-check, curl self-check) is covered in Phase 2.2.

### Version-Level (Pre-Release)

| Step | Artifacts | Who Provides |
|------|-----------|--------------|
| Phase 3.1 | `.trellis/releases/<version>/test-cases.md` | **QA** |
| Phase 3.1 | Walk through every scenario, verify all smoke tests pass | AI |

`test-cases.md` is **version-level**, not task-level. QA writes it once per version, AI runs it once before the release commit. Daily task development does not touch it.

---

## 记忆与知识管理设计

本项目的 AI 知识管理遵循**"项目级沉淀优先，个人流水不存"**原则。

### 两层架构

| 层级 | 位置 | 粒度 | 是否激活 | 理由 |
|------|------|------|----------|------|
| **项目知识库（核心）** | `.trellis/spec/` + `.trellis/tasks/` | 规范、架构、任务 PRD | ✅ 激活 | 团队共享、长期有效、AI 每次对话自动读取 |
| **个人开发日志（可选）** | `.trellis/workspace/<name>/journal-*.md` | 每次对话的操作流水 | ❌ 不激活 | 见下方决策分析 |

### 为什么不激活个人 journal

**Trellis 的 journal 设计初衷**是给没有 spec 体系的普通项目当"对话流水账"，防止 AI 在跨会话时丢失上下文。

本项目的实际情况完全不同：

1. **信息已沉淀** — 每条有效决策都写入了 `spec/`（TabBar 安全区、404 Pitfall、Response 归一化、三层 API……），journal 只是在重复存储
2. **对话含噪音** — 真实的 AI 对话中不可避免有试错、反复修正、撤回，流水账记录这些没有意义
3. **Token 成本** — journal 行数越多，AI 每次初始化越慢；去重筛选、维护成本高于沉淀的收益
4. **多成员扩展** — 未来团队其他人打开项目，读 `spec/` 就能理解全貌，不需要翻阅每个人的操作流水

### 多成员协作时的 AI 规范体系

当团队扩展时，每个新开发者只需要：

```
打开项目 → AI 自动读取 .trellis/spec/ → 当场理解：
  ├── 4 仓库架构与调用链路       (architecture-overview.md)
  ├── 本仓库的编码规范与踩坑清单  (spec/<package>/index.md)
  ├── 当前进行中的任务与 PRD      (tasks/<task>/)
  └── 跨包通用的思维检查清单      (guides/code-reuse/ cross-layer/)
```

**不需要**：翻阅张三上周的 journal、同步李四的操作记录。

### 唯一保留的种子记录

[workspace/lidie/journal-1.md](../../workspace/lidie/journal-1.md) 只保留一份实验期里程碑摘要（< 20 行），作为新人快速了解"这个项目最近在做什么方向"的入口。日常不再维护。

---

## Contributing

Found a new "didn't think of that" moment? Add it to the relevant guide.

---

**Core Principle**: 30 minutes of thinking saves 3 hours of debugging.
