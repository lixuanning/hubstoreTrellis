# Trellis 集成实验文档

> **实验日期**: 2026-08-11  
> **实验者**: lidie  
> **功能**: 探索 Trellis 在 StoreHub monorepo 的适用性  
> **目的**: 验证 Trellis 是否能为团队 AI 编码提供统一的规范管理，并产出可复现的推广文档

---

## 1. 背景与目标

### 1.1 项目背景

StoreHub 是一个包含 4 个子项目的 monorepo：

| 子项目 | 技术栈 | 目录 | 功能 |
|--------|--------|------|------|
| ai-store-api | NestJS 7.x + TypeORM + MySQL | `ai-store-api/` | AI 识别/核验后端 |
| storehub-servless | 腾讯云 SCF + Express | `storehub-servless/` | Node.js 中间件网关 |
| storehub-uniapp | UniApp + Vue 3 + wot-ui | `storehub-uniapp/` | 企业微信小程序 |
| storehub-web | Vue 3 + Vite + Vant | `storehub-web/` | H5 webview 页面 |

**核心调用链路**: uniapp → serverless → ai + 25+ 第三方后端服务

### 1.2 核心痛点

- AI 无法准确理解 4 个仓库的关系和调用链路
- 同一功能需求需要跨 3-4 个端实现，AI 经常只改一端
- 响应格式约定分散在各个 env-config 中，AI 不理解其含义导致返回格式错误
- 各端 API 调用规范不统一（uniapp 三层、web 两层、serverless 文件路由）

### 1.3 实验目标

1. 在 StoreHub monorepo 根目录安装并初始化 Trellis
2. 将现有项目知识（project_memory.md）迁移为 Trellis spec
3. 验证 Trellis 的 monorepo 模式是否能正确管理 4 个子项目
4. 产出可团队推广的步骤文档

---

## 2. 环境准备

### 2.1 前置条件

| 工具 | 要求 | 实际 | 状态 |
|------|------|------|------|
| Node.js | 18+ | v20.19.3 (nvm) | ✅ |
| Python | 3.9+ | 3.12.2 (Homebrew) | ✅ |
| npm | - | 已安装 | ✅ |

### 2.2 安装步骤

```bash
# Step 1: 全局安装 Trellis CLI
npm install -g @mindfoldhq/trellis@latest

# 验证安装
trellis --version
# 输出: 0.6.14
```

---

## 3. 初始化配置

### 3.1 执行 init

```bash
cd /Users/lidie/a-code/a-pgy/storehub
trellis init -u lidie --trae
```

### 3.2 交互式选项

```
👤 Developer: lidie

🔍 Detected monorepo packages:
   - store-message2-service (ai-store-api) [fullstack]
   - serverless-project (storehub-servless) [fullstack]
   - storehub-uniapp (storehub-uniapp) [frontend]
   - mobile-project (storehub-web) [frontend]

? Enable monorepo mode? Yes
? Spec source for each package: From scratch (Trellis default)
```

> **注意**: Trellis 从各子项目的 `package.json` 读取包名（`name` 字段），可能不是目录名。

### 3.3 生成产物

```
.trellis/
├── agents/            # Sub-agent 定义
├── scripts/           # Python 脚本（task.py, get_context.py 等）
├── spec/              # 规范目录（按 package + layer 分层）
├── tasks/             # 任务目录（含 00-bootstrap-guidelines 引导任务）
├── workspace/lidie/   # 个人工作区（journal 日志）
├── config.yaml        # Trellis 配置
├── workflow.md        # 开发工作流定义
└── .developer         # 开发者身份（gitignored）
```

---

## 4. 初始化后修正

Trellis 自动检测存在两个问题需要手动修正：

### 4.1 包名修正

Trellis 从 `package.json` 的 `name` 字段读取包名，导致 spec 目录名与实际项目不匹配：

| 自动检测名 | 实际目录名 | 修正后 |
|-----------|-----------|--------|
| `store-message2-service` | `ai-store-api` | `ai-store-api` |
| `serverless-project` | `storehub-servless` | `storehub-servless` |
| `mobile-project` | `storehub-web` | `storehub-web` |
| `storehub-uniapp` | `storehub-uniapp` | 无需修正 |

修正操作：
1. 修改 `.trellis/config.yaml` 中的 `packages` 键名
2. 重命名 `.trellis/spec/` 下的目录

```bash
mv .trellis/spec/store-message2-service .trellis/spec/ai-store-api
mv .trellis/spec/serverless-project .trellis/spec/storehub-servless
mv .trellis/spec/mobile-project .trellis/spec/storehub-web
```

### 4.2 多余的 spec layer

`ai-store-api` 和 `storehub-servless` 被检测为 `fullstack`，生成了不需要的 `frontend/` 目录。直接删除：

```bash
rm -rf .trellis/spec/ai-store-api/frontend
rm -rf .trellis/spec/storehub-servless/frontend
```

### 4.3 迁移现有规范

将 `project_memory.md` 中的架构知识迁移到 Trellis 的 spec 体系：

| 迁移内容 | Trellis 目标位置 | 说明 |
|---------|-----------------|------|
| 调用链路 + 响应格式 | `.trellis/spec/guides/architecture-overview.md` | 新增，所有包的前置阅读 |
| uniapp API 三层架构 | `.trellis/spec/storehub-uniapp/frontend/index.md` | APIS → Service → Page |
| web API 两层架构 | `.trellis/spec/storehub-web/frontend/index.md` | modules/http.ts 模式 |
| serverless 文件路由 | `.trellis/spec/storehub-servless/backend/index.md` | 路径=路由，.post.ts=POST |
| ai 响应格式 | `.trellis/spec/ai-store-api/backend/index.md` | { status, data } 约束 |
| 自检 curl 流程 | 各 backend/ index.md | 修改后必验证 |

---

## 5. 当前状态

### 5.1 已完成的 spec

| 文件 | 状态 | 内容 |
|------|------|------|
| `.trellis/spec/guides/architecture-overview.md` | ✅ 已填充 | 完整架构、调用链、响应格式、API 约定、自检流程 |
| `.trellis/spec/ai-store-api/backend/index.md` | ✅ 已填充 | NestJS 响应格式、注解、模块结构、自检命令 |
| `.trellis/spec/storehub-servless/backend/index.md` | ✅ 已填充 | 文件路由、代理模式、env-config 约定、自检命令 |
| `.trellis/spec/storehub-uniapp/frontend/index.md` | ✅ 已填充 | 三层架构、wot-ui、禁止 dev/build、条件编译 |
| `.trellis/spec/storehub-web/frontend/index.md` | ✅ 已填充 | 两层架构、axios 拦截器链、webview 集成 |

### 5.2 待填充的详细 spec

各包的子指南（directory-structure.md、component-guidelines 等）仍为占位状态，后续按需从代码中提取填充。

### 5.3 生成的 AGENTS.md

Trellis 在仓库根目录自动生成了 `AGENTS.md`，引导 AI 读取 `.trellis/` 下的规范。该文件与 `.trae/rules/project_rules.md` 互补：
- `AGENTS.md` → 指向 Trellis spec 体系
- `.trae/rules/project_rules.md` → uniapp 专属开发规则

---

## 6. 评估结论

### 6.1 适配度

| 维度 | 评分 | 说明 |
|------|------|------|
| Monorepo 支持 | ⭐⭐⭐⭐ | 原生支持，但包名需手动修正 |
| 跨端 spec 管理 | ⭐⭐⭐⭐ | spec 按 package/layer 分层清晰 |
| 团队推广 | ⭐⭐⭐⭐⭐ | git 版本化 spec + journal 日志，可直接复用 |
| 学习成本 | ⭐⭐⭐ | 需要理解 Trellis 的三阶段工作流（Plan→Execute→Finish） |

### 6.2 与现有工具的互补

| 工具 | 作用域 | 与 Trellis 关系 |
|------|--------|----------------|
| `.trae/rules/project_rules.md` | uniapp 专属 | 互补 — Trellis spec 是全局，rules 是 uniapp 特有 |
| `project_memory.md` | 全局上下文 | 已迁移到 Trellis spec 体系 |
| Coding CI | 分支/MR 管理 | 无冲突，Trellis 管编码规范 |

### 6.3 建议

- **可在团队内推广**，核心价值：统一的 spec 体系 + 跨会话记忆 + git 版本化
- 推广前需要：为每个子项目填充详细的 guideline 文件（从代码中提取实际模式）
- 新成员加入只需运行 `trellis init -u <name>`，自动获得 joiner 引导任务

---

## 7. 附：关键文件清单

```
storehub/
├── .trellis/                                    # Trellis 核心
│   ├── spec/guides/architecture-overview.md     # 项目架构概览（关键）
│   ├── spec/ai-store-api/backend/index.md       # AI后端规范
│   ├── spec/storehub-servless/backend/index.md  # 中间件规范
│   ├── spec/storehub-uniapp/frontend/index.md   # 小程序规范
│   ├── spec/storehub-web/frontend/index.md      # H5规范
│   ├── tasks/00-bootstrap-guidelines/prd.md     # 引导任务
│   └── config.yaml                               # 包配置
├── AGENTS.md                                     # AI 入口文件
└── .trae/memory/projects/...project_memory.md   # 原始上下文（已迁移）
```

---

## 8. 实验深化：工程设计决策（2026-08-12 补充）

初始实验完成后，在实际使用中沉淀了以下工程设计决策：

### 8.1 SDD 闭环验证

Trellis 的 SDD（Spec-Driven Development）三阶段在实际对话中形成了完整闭环：

```
Phase 1 (Spec)  → Phase 2 (Develop) → Phase 3 (Drive back to Spec)
     ↑                                        │
     └────────────────── 下次对话 ──────────────┘
```

实验期间踩坑 → 写入 spec → 下次自动避免的实例：

| 踩坑 | 写入 spec | 效果 |
|------|----------|------|
| API 路径三端不一致 → 404 | `storehub-servless/backend/index.md` 跨端路径对齐 Pitfall | 再写接口自动对齐 |
| wd-popup bottom:0 被组件覆盖 | `storehub-uniapp/frontend/index.md` TabBar 安全区 | 再写弹窗自动留 110rpx |

### 8.2 记忆与知识管理设计

经过评估，**不激活个人 journal（每日会话流水）**，理由：

- 有效信息已在 spec 和 tasks 中沉淀
- 对话中的试错、撤回、重复信息记录没有价值
- journal 行数增长会浪费 token（AI 每次启动都读）
- 多成员扩展时 spec 是共享规范，journal 是个人流水无助于协作

详细设计见 [.trellis/spec/guides/index.md](file:///Users/lidie/a-code/a-pgy/storehub/.trellis/spec/guides/index.md) 的「记忆与知识管理设计」章节。

### 8.3 编码规范补充

在 Trellis 原生规范之外，补充了两条团队共识规则：

1. **中文注释规范** — 文件头、复杂逻辑、非直观样式必须中文注释
2. **Commit ≠ Push** — 提交默认只到本地，明确说"推送"才 push

### 8.4 测试用例设计

test-cases.md 放在版本级（`.trellis/releases/<version>/`）而非任务级：

- **日常开发（task 级）**：只做 lint/type-check/curl，不维护用例
- **提测前（version 级）**：QA 把用例放进来，AI 跑一次全量验收

### 8.5 文档体系

| 层 | 位置 | 受众 |
|---|---|---|
| AI 工程规范 | `.trellis/spec/` | AI（编码时自动注入） |
| 人类认知文档 | `docs/` | 团队成员（手动阅读） |

### 8.6 工程化配套

- `start-dev.sh` — 一键启动 4 端 dev 环境
- `mcp.config.example.json` — 6 个 MCP Server 配置模板（含 CoDesign 替代方案）
- storehub 根目录 `git init` + GitHub remote — 工程化配置独立版本控制（.gitignore 排除 4 个业务仓库）

---

## 9. 推广建议（更新）

原推广建议（6.3 节）基础上补充：

- 新人加入只需：clone storehub 工程仓库 → `cp mcp.config.example.json .trae/mcp.json` → 填入 Token → 开始对话
- 不需要培训 Trellis 命令，对话中 AI 自动处理
- spec 维护由团队共识驱动：谁发现规律性错误谁让 AI 写进 spec
