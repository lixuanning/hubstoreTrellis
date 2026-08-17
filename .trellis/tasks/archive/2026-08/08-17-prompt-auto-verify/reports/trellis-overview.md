# Trellis 推广文档 — 基于「提示词自动验证 Skill」案例

> 一个具体案例，把 Trellis 的所有组件跑一遍，看它们在真实工程里各自承担什么。

## 1. Trellis 是什么

Trellis 是 StoreHub 团队采用的一组 AI 协作规约 + 脚本工具集，目的是让 AI 在多人、多包、多周时间尺度上**保持一致性**。它通过：

- **沉淀项目知识**到 `.trellis/spec/`
- **沉淀跨项目流程**到 `.trae/skills/`（或 `.agents/skills/`）
- **沉淀每次任务**到 `.trellis/tasks/<MM-DD-name>/`
- **三阶段工作流**（Plan → Execute → Finish）确保每一步都有产出、有审核

解决的核心问题：
- AI 不知道项目用什么状态管理库 → spec 提前声明
- AI 不知道如何调用本项目的接口 → 业务说明写进 spec 或 skill
- AI 跑完任务不知道下一步 → workflow + per-turn breadcrumb 强制流转
- 多次会话后经验丢失 → task artifacts + workspace journal 持续累积

---

## 2. 案例：提示词自动验证 Skill（08-17）

### 业务背景

web 平台 AI 复核功能需要"人工生成提示词 → 跑分类数据 → 对比结论差异 → 修改提示词"全流程自动化，做成一个可复用 Skill。

5 轮迭代历程：

| 轮 | 准确率 | 关键学习 |
|---|---|---|
| R1 | 0% | AI 反向判（未含二次确认语义）|
| R2 | 100% | 加二次确认语义 |
| R3 | 75% | 阈值过严 |
| R4 | **85%** ✅ | 放宽合规（一只手在画外/动作非开切/半透明覆盖）|
| R5 | 70% | 过度放宽，反向错误 |

最终：Round 4 85% 接受为最终态，3 条业务主观差异已沉淀。

### 任务目录

`.trellis/tasks/08-17-prompt-auto-verify/` —— Trellis 任务产物的"容器"。

---

## 3. Trellis 各组件在案例中的作用

### 3.1 `.trellis/tasks/08-17-prompt-auto-verify/` — 任务容器

**作用**：每次 AI 协作任务有独立目录，所有产物（PRD、设计、实施、报告）落在这里。

**本任务产物**：

| 文件 | 作用 |
|---|---|
| `task.json` | 任务元数据（slug、status、创建时间）|
| `prd.md` | **需求**：Goal / Requirements R1-R7 / Acceptance Criteria / 关键决策 |
| `design.md` | **技术设计**：架构图 / 数据流 / 验证循环 / 配置 / 风险 |
| `implement.md` | **实施清单**：有序步骤 + 验证命令 + 风险回滚点 |
| `implement.jsonl` | 子代理 implement 阶段注入的 spec/research 清单 |
| `check.jsonl` | 子代理 check 阶段注入的清单 |
| `reports/round-1.md` ~ `round-5.md` + `final.md` | 每轮迭代记录 + 最终汇总 |

**为什么这样组织**：所有任务产物可追溯、可复盘；新人接手任务只需看这个目录，不用读完整聊天记录。

---

### 3.2 `.trellis/spec/` — 项目知识

**作用**：项目特定的事实性知识（包结构、状态管理、API 风格、错误处理）。**自动注入**到 AI 工作流。

```
.trellis/spec/
├── ai-store-api/backend/        # 后端代码规范
│   ├── index.md                  # 入口（Pre-Development Checklist + Quality Check）
│   ├── directory-structure.md
│   ├── error-handling.md
│   ├── database-guidelines.md
│   ├── logging-guidelines.md
│   └── quality-guidelines.md
├── storehub-servless/backend/   # 另一个后端包的规范
├── storehub-uniapp/frontend/    # 小程序
├── storehub-web/frontend/       # web
└── guides/                      # 跨包思考指南
    ├── architecture-overview.md
    ├── code-reuse-thinking-guide.md
    └── cross-layer-thinking-guide.md
```

**本任务里用到的**：
- `ai-store-api/backend/index.md`：理解 vfm-verify 后端实现
- `ai-store-api/backend/directory-structure.md`：知道 service/dto/entity 怎么组织
- `guides/code-reuse-thinking-guide.md`：避免重复造轮子

**自动注入机制**：通过 `.trellis/agents/implement.md` 和 `.trellis/agents/check.md` 子代理 + `trellis-before-dev` skill，进入代码编辑前自动读取相关包规范。

---

### 3.3 `.trae/skills/` — 跨项目复用流程

**作用**：项目无关的"怎么做"知识。**按需调用**（用户说"验证提示词"才触发 prompt-verify）。

```
.trae/skills/
├── prompt-verify/               # 本任务新增！
│   ├── SKILL.md                  # 触发词 + 执行流程
│   ├── config.yaml               # base_url / 阈值 / 批大小 / 鉴权头
│   └── references/
│       └── api-contract.md       # 接口契约
├── trellis-brainstorm/          # 阶段 1：需求探索
├── trellis-before-dev/          # 阶段 2：开发前读 spec
├── trellis-check/               # 阶段 2.2：质量检查
├── trellis-update-spec/         # 阶段 3.3：沉淀 spec
├── trellis-break-loop/          # 阶段 3.2：调试复盘
├── trellis-spec-bootstrap/      # 初始化 spec
├── trellis-session-insight/     # 跨会话记忆
├── trellis-meta/                # Trellis 架构自定义
└── trellis-channel/             # 多 agent 协作
```

**本任务产出的 Skill**（`prompt-verify/`）：

| 文件 | 作用 |
|---|---|
| `SKILL.md` | 触发词（"验证 type 122"）+ 9 步流程（建提示词→拉样本→reVerify→算准确率→分级→迭代→报告）|
| `config.yaml` | base_url、batch_size=15（避免 503）、鉴权头（x-qwmp-token 等）|
| `references/api-contract.md` | servless 代理路径 + 二次确认语义 + 字段类型（字符串 id）+ 后端 findByIds Bug 沉淀 |

**与 spec 的关键区别**：

| 维度 | `.trellis/spec/` | `.trae/skills/` |
|---|---|---|
| 范围 | 项目特定 | 跨项目可复用 |
| 形态 | 事实性知识（声明）| 流程性知识（指令）|
| 注入方式 | 自动（before-dev 时）| 按需（用户触发）|
| 例子 | "本项目用 Pinia" | "如何验证提示词" |
| 谁来写 | AI 写并持续更新 | AI 写并可在多项目复用 |

---

### 3.4 `.trellis/workflow.md` — 三阶段规约

**作用**：定义 AI 在每个时刻应该做什么。**核心哲学**：
- "Plan before code"（先想清楚再写）
- "Specs injected, not remembered"（知识从文件注入，不靠记忆）
- "Persist everything"（研究、决策、教训全落文件）
- "Incremental development"（一次一个任务）
- "Capture learnings"（任务后把新知识写回 spec）

**三阶段**：

```
Phase 1: Plan    → 创建任务 + 写 prd.md/design.md/implement.md + 启动
Phase 2: Execute → 实现（implement agent）+ 质量检查（check agent）+ 回滚
Phase 3: Finish  → 复盘 + 更新 spec + 提交
```

**本任务跑过**：
- Phase 1：建任务（task.py create）→ 写 prd/design/implement → 多次让用户审批
- Phase 2：实施（4 个文件 + 后端 findByIds 修复）
- Phase 3：5 轮验证报告 + 沉淀 spec + 沉淀 skill

**per-turn breadcrumb**（关键设计）：
- 每个用户消息都附一个 `<workflow-state>` 标记，告诉 AI 当前在哪个阶段
- 由 `.trellis/scripts/inject-workflow-state.py` 自动读取并注入
- 状态机：`no_task` → `planning` → `in_progress` → `completed`

---

### 3.5 `.trellis/agents/` — 子代理定义

**作用**：定义"实现"和"检查"子代理的 prompt 模板。

```
.trellis/agents/
├── implement.md   # trellis-implement 子代理：读 task artifacts + spec + research → 写代码
└── check.md       # trellis-check 子代理：读 spec + 任务 artifacts → 审查/修复
```

**为什么需要子代理**：
- 隔离上下文（实现子代理和主会话不互相污染）
- 强制注入 spec（避免 AI 凭记忆写代码）
- 可并行（多任务同时跑）

**本任务**：本任务比较小（4 个文件 + 1 个后端修复），所以**没有 dispatch 子代理**，而是主会话直接编辑。Task 工具的 `subagent_type=general-purpose_task` 也可承载。

---

### 3.6 `.trellis/scripts/` — CLI 工具集

**作用**：用 Python 脚本管理 Trellis 自身（任务、上下文、会话）。

```
.trellis/scripts/
├── task.py           # 任务生命周期（create/start/finish/archive/list）
├── get_context.py    # 取 spec / phase / 全局上下文
├── init_developer.py # 初始化开发者身份
├── add_session.py    # 记录会话
└── common/           # 工具模块
```

**本任务用过的**：
- `task.py create`：建任务
- `task.py start`：进入实现阶段
- `task.py finish` / `archive`：归档
- `add_session.py --title ... --summary ...`：记录工作日志到 `.trellis/workspace/lidie/`

**注意**：本任务在中文环境跑通，未必全程走 task.py CLI（受 terminal 长度限制），但 task.json 仍存在并被 Trellis 框架识别。

---

### 3.7 `.trellis/workspace/<developer>/` — 个人工作日志

**作用**：每个开发者有独立目录，记录所有会话。

```
.trellis/workspace/lidie/
├── index.md            # 总览（总 session 数、最近活跃）
└── journal-1.md        # 每次会话一条（最多 2000 行）
```

**本任务**：在 `journal-1.md` 里有 "提示词自动验证 Skill 5 轮迭代 + 沉淀" 摘要。

**为什么需要**：跨会话记忆——AI 这次忘了，下次还能从 journal 找回"上次怎么做的"。

---

### 3.8 `.trellis/releases/<version>/` — 版本发布

**作用**：QA 写的测试用例、版本验收清单。

**本任务**：未涉及（新功能不在 release 周期内）。

---

## 4. Trellis 的一次完整生命周期（以本案例）

```
1. 用户提出需求
   "做提示词自动验证的 Skill"
   ↓
2. AI 进入 Phase 1（Planning）
   - task.py create "提示词自动验证 Skill 设计" --slug prompt-auto-verify
   - 创建 .trellis/tasks/08-17-prompt-auto-verify/
   ↓
3. 探索需求（trellis-brainstorm skill）
   - AskUserQuestion 多次确认（自动化边界、触发方式、MCP 方案）
   - 同步更新 prd.md
   ↓
4. 写完三件套
   - prd.md（需求、AC、关键决策）
   - design.md（架构、数据流、风险）
   - implement.md（实施清单）
   ↓
5. 用户审批（NotifyUser）
   ↓
6. 进入 Phase 2（Execute）
   - 创建 .trae/skills/prompt-verify/ 目录
   - 写 SKILL.md / config.yaml / api-contract.md
   - 修复后端 findByIds Bug（3 处）
   ↓
7. Phase 2.2 质量检查（trellis-check）
   - 实施冒烟验证（接口连通、跑数）
   ↓
8. 用户继续："验证 122"
   - 触发 prompt-verify skill
   - 5 轮迭代 + 报告
   ↓
9. Phase 3（Finish）
   - reports/round-1.md ~ round-5.md + final.md
   - 沉淀 spec（如有新增规范）
   - 提交
   ↓
10. /trellis:finish-work 收尾
    - task archive
    - journal 添加
```

---

## 5. 复用与推广要点

### 5.1 对其他项目/团队的复用

| 组件 | 复用方式 |
|---|---|
| `.trellis/workflow.md` | 直接复用（Trellis 核心）|
| `.trellis/scripts/` | 直接复用 |
| `.trae/skills/trellis-*/` | 直接复用（Trellis 内置 skill）|
| `.trae/skills/prompt-verify/` | **可跨项目复用**（已抽离业务封装在 references/api-contract.md）|
| `.trellis/spec/` | 每个项目自己写，参考 bootstrap skill |
| `.trellis/tasks/` | 项目本地，不复用 |

### 5.2 新建 Skill 的标准流程

1. 在 trellis-brainstorm 里明确"这个 Skill 解决什么问题"
2. 写 SKILL.md（触发词 + 流程步骤 + 关键约束）
3. config.yaml（可配置项）
4. references/ 目录放业务契约、模板、错误码
5. 跑一遍真实场景验证（冒烟测试）
6. 在 spec 里加一条"何时使用本 Skill"
7. 团队分享 → 收集反馈迭代

### 5.3 写新 spec 的判定

- **写到 spec** 的：项目特定事实、跨包约定、API 风格、错误处理规范
- **写到 skill** 的：跨项目可复用流程、复杂操作步骤、决策树
- **写到 task** 的：本次任务的临时产物（不要污染 spec/skill）
- **写到 journal** 的：会话级别的经验、调试过程、用户反馈

### 5.4 避免的陷阱

| 陷阱 | 应对 |
|---|---|
| spec 写成"代码复制" | spec 只写约定，不复制实现 |
| skill 写成"项目特定" | skill 应该是跨项目可复用，业务封装在 references/ |
| task 不写 prd | 即使小任务也写 prd.md，方便后续追溯 |
| 修改完不同步 spec | Phase 3.3 强制要求 |
| 一次性把任务全做完 | 增量开发，每步有产出 |

---

## 6. 一句话总结

> **Trellis = workflow（规约） + spec（项目事实） + skill（流程知识） + task（任务容器） + agents（子代理） + scripts（CLI 工具）**
>
> 每样东西各管一摊，合起来让 AI 在多周、多人、多项目的尺度上保持一致。

---

## 7. 关键文件位置速查

| 想看什么 | 路径 |
|---|---|
| Trellis 核心规约 | [`.trellis/workflow.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/workflow.md) |
| 项目后端规范 | [`.trellis/spec/ai-store-api/backend/`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/spec/ai-store-api/backend/) |
| 项目前端规范 | [`.trellis/spec/storehub-web/frontend/`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/spec/storehub-web/frontend/) |
| 本任务的 PRD | [`.trellis/tasks/08-17-prompt-auto-verify/prd.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/tasks/08-17-prompt-auto-verify/prd.md) |
| 本任务的设计 | [`.trellis/tasks/08-17-prompt-auto-verify/design.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/tasks/08-17-prompt-auto-verify/design.md) |
| 本任务的实施清单 | [`.trellis/tasks/08-17-prompt-auto-verify/implement.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/tasks/08-17-prompt-auto-verify/implement.md) |
| 本任务最终报告 | [`.trellis/tasks/08-17-prompt-auto-verify/reports/final.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/tasks/08-17-prompt-auto-verify/reports/final.md) |
| 产出的新 Skill | [`.trae/skills/prompt-verify/`](file:///Users/lidie/a-code/a-pgy/storehub/.trae/skills/prompt-verify/) |
| 个人工作日志 | [`.trellis/workspace/lidie/journal-1.md`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/workspace/lidie/journal-1.md) |
| Trellis CLI | [`.trellis/scripts/task.py`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/scripts/task.py) |
| 子代理模板 | [`.trellis/agents/`](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/agents/) |
