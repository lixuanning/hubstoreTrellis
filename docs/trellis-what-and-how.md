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
├── spec/          ← 项目的"说明书"，AI 每次对话前自动查阅
├── tasks/         ← 开发任务的记录（需求、实现细节）
├── workspace/     ← 每次对话的工作日志（跨天不会忘记）
├── workflow.md    ← 开发流程指引（Plan → Execute → Finish）
└── config.yaml    ← 子项目配置
```

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

### 维护规范（偶尔做，一天一次或更少）

```
当你发现 AI 犯了一个规律性错误时：
  → 告诉 AI "把这条规则加到 spec 里"
  → AI 自动写入 spec，以后不会再犯
```

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
