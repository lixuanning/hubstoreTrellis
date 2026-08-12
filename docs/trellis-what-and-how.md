# Trellis 是什么 & 怎么用

> 写给 StoreHub 团队的 Trellis 使用指南

---

## 一句话理解

**Trellis 不是给"人"操作的，是给"AI"读的工程化规范体系。**

你不需要学命令、不需要背流程。你依然是正常和 AI 对话提需求，AI 会自动读 Trellis 的配置来理解你的项目、遵守你的规范、按你的工作流执行。

---

## 三种角色的视角

| | 以前（没有 Trellis） | 现在（有 Trellis） |
|---|---|---|
| **你（人）** | 跟 AI 说"帮我改小程序首页" | **一模一样**，继续正常对话 |
| **AI** | 凭记忆猜你的项目结构，经常搞错 | 自动读 `.trellis/spec/`，准确知道 4 个仓库的关系和规范 |
| **Trellis** | 不存在 | 在后台提供 spec 文件、工作流指引、任务记录 |

---

## 它到底是什么

```
.trellis/
├── spec/          ← 项目"说明书"。AI 每次对话自动读取；踩坑后沉淀新规则到这里
├── tasks/         ← 任务档案。只在明确说"创建 Trellis 任务"时生成；日常对话不产生
├── workspace/     ← 个人日志。本项目不启用（有 spec 就够了，流水没意义）
├── workflow.md    ← 开发流程。Trellis 自动维护，不需要手动改
└── config.yaml    ← 基础配置。初始化后基本不改
```

| 目录 | 谁来维护 | 什么时候变 |
|------|---------|-----------|
| `spec/` | AI 主动 + 用户确认 | ① 初始化时 AI 扫描项目自动提取规则</br>② 开发中 AI 觉得值得沉淀的主动提议</br>③ 用户说"加入 spec"一句话触发</br>**用户最终决定是否保留** |
| `tasks/` | AI（你说"创建任务"后） | 走 Plan → Execute → Finish 流程时 |
| `workspace/` | 不启用 | 不变（只有一份种子里程碑记录） |
| `workflow.md` | Trellis CLI | `trellis update` 时自动刷新 |
| `config.yaml` | 初始化时手动设一次 | 基本不变 |

你可以把它理解为：

- **对 AI 来说是 GPS** — 知道项目有哪些模块、接口怎么写、格式是什么
- **对你来说是黑盒** — 不需要关心内部细节，正常对话就行
- **对团队来说是共享规则** — 一个人维护好 spec，所有人的 AI 都能受益

---

## 实际对话中的表现

以刚才的"小程序首页新增 API"为例：

| 环节 | Trellis 在做什么 | 你看到了什么 |
|------|-----------------|-------------|
| 你提需求 | - | "小程序首页要加个接口调用" |
| 创建确认 | workflow.md 的 no_task 规则触发 | AI 问"要创建 Trellis 任务吗？" |
| 写 PRD | AI 把需求写到 `tasks/08-11/prd.md` | AI 列出了涉及 3 端的改动清单 |
| 实现 | AI 自动读 `spec/guides/architecture-overview.md`<br>知道了 uniapp 三层架构、ai 返回格式 | AI 按规范在 3 端正确写了代码 |
| 自检 | AI 读 `spec/ai-store-api/backend/index.md`<br>知道了 `curl :3000` 验证格式 | AI 自动 curl 验证、发现问题、修正 |

**你全程只是说"是""确认"，AI 按 Trellis 的规则把所有事做了。**

---

## 你需要做的事

### 日常开发（你做的）

```
1. 正常跟 AI 对话提需求
2. AI 问"是否创建任务"时回答"是"
3. AI 给出 PRD 时看一眼，确认就回"确认"
4. 后续一切 AI 自动完成
```

### 维护规范（偶尔做）

spec 的维护有三种触发方式，按主动性递进：

#### ① AI 主动扫描初始化

在对接新项目或新仓库时，AI 会主动扫描代码提取已有规则写到 spec。不需要你提醒。

```
"帮我看看这个仓库有哪些编码规范，初始化到 spec 里"
→ AI 扫描代码 → 提取模式 → 写入 spec
```

#### ② AI 主动提议（新增）

开发过程中，AI 发现某个模式、踩坑、或值得固化的知识时，**会主动问你**：

```
AI: "刚才这个问题是因为 XXX 造成的。我建议把它写入 spec，以后就能自动避免了。要保留吗？"
→ 你说"保留" → 写入
→ 你说"不用" → 跳过
```

**你不会被默默地塞规则，也不会漏掉有价值的经验。**

#### ③ 你一句话触发

当你明确发现规律性错误时，直接告诉我：

```
"把这条规则加到 spec 里"
→ AI 写入，以后不会再犯
```

**当前已沉淀的规则示例**：

| 规则 | 存放位置 | 来源 |
|------|---------|------|
| 三端 API 路径必须完全一致（文件名 = 路径） | `storehub-servless/backend/index.md` | 404 踩坑 |
| wd-popup 底部安全区三段式方案 | `storehub-uniapp/frontend/index.md` | TabBar 遮挡 |
| 登录白名单：临时加 → curl 验证 → 删除 | `storehub-servless/backend/index.md` | 401 踩坑 |
| 中文注释 + commit 不自动 push | 各包 `quality-guidelines.md` | 团队共识 |

---

## SDD 三阶段闭环

Trellis 的核心工作流叫 SDD（Spec-Driven Development）：

```
S (Spec)           → Phase 1: 读规范、写 PRD，确定"好的代码长什么样"
D (Development)    → Phase 2: 按规范写代码 + lint/type-check/curl 自检
D (Drive back)     → Phase 3: 本次踩的坑写回规范，下次自动更聪明
```

第二个 D 是闭环的关键——不是"测试"或"部署"，而是**把经验写回 spec 让下一次对话自动更聪明**。

---

## 记忆与知识管理

项目遵循 **"项目级沉淀优先，个人流水不存"** 原则。

| 存什么 | 位置 | 为什么 |
|--------|------|--------|
| 规范、架构、踩坑清单 | `.trellis/spec/` | 团队共享、AI 自动读取、长期有效 |
| 任务 PRD、设计决策 | `.trellis/tasks/` | 版本化、可追溯 |
| ~~个人操作流水~~ | `.trellis/workspace/journal-*.md` | **不激活**：对话含噪音、信息已沉淀在 spec、费 token |

未来团队其他人打开项目，AI 读完 `spec/` 就能理解全貌，不需要翻阅任何人的操作流水。

---

## 编码规范执行

除 Trellis 原生规范外，项目补充了两条自定义规则：

1. **中文注释** — 文件头、复杂逻辑、非直观样式必须用中文注释（团队协作需求）
2. **Commit ≠ Push** — 提交只到本地，需要明确说"推送"才 push。方便随时 `git reset` 回退

---

## 关键文件地图

| 想知道的事 | 看这个文件 |
|-----------|-----------|
| 项目整体架构 | `.trellis/spec/guides/architecture-overview.md` |
| ai 后端怎么写接口 | `.trellis/spec/ai-store-api/backend/index.md` |
| serverless 怎么代理 | `.trellis/spec/storehub-servless/backend/index.md` |
| 小程序 API 怎么调 | `.trellis/spec/storehub-uniapp/frontend/index.md` |
| web H5 怎么写 | `.trellis/spec/storehub-web/frontend/index.md` |

---

## 常见误解澄清

| 误解 | 真相 |
|------|------|
| "我要学一堆 trellis 命令" | 不需要，对话中 AI 会自己调 `task.py create/start` |
| "它改变了我写代码的方式" | 不改变，你仍然正常写代码 |
| "它只支持特定 IDE" | 支持 20+ 个平台，包括 Trae、Cursor、Claude Code |
| "它是另一个 CI 工具" | 不是，它是给 AI 读的规范，不是给人操作的流程工具 |

---

## 总结

你之前说它是"工程化的 rules"——这个理解完全正确。它就是把你脑子里的项目规范写成文件，让每个 AI 对话都自动遵循。

**以前：** 每次新对话都要重新告诉 AI "我们有 4 个仓库，uniapp 不能直接调 ai，返回格式是 { status, data }..."

**现在：** AI 打开对话 → 自动读 Trellis → 已经知道一切 → 直接开始干活。
