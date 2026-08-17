---
name: prompt-verify
description: "自动验证 AI 巡店审核提示词的准确性：基于需求生成新提示词（如 ai-122）并记住 id，按 checkCode 查已复核样本（resultList 联表）→ 按新 promptId 用 reVerifyByIds 重跑（必须带鉴权头）→ 用 aiConclusionDifferent 算准确率，≥90% 自动扩到 30 条复验，低准确率时 AI 改写新提示词（reviewPromptUpdate）重跑（最多 3 轮），输出 Markdown 报告。不修改、不查找任何现有提示词。必须知道：AI 复核是【二次确认】（isValid=true=确认违规，false=推翻）。当用户说「验证提示词」「验证 type/检查项 122」「跑下 XX 检查项的准确率」时使用。"
---

# 提示词自动验证

模拟 web 平台 ModelDebug 的用户操作：**新建**一个 AI 生成的提示词 → 拿它去跑已复核样本 → 用后端算好的"结论是否不同"算准确率 → 低准确率就**改写这个新建的**继续重跑。**不动任何现有提示词**。

## 触发

用户指令中出现以下任一意图即触发：

- 「验证提示词」「验证 type 122」「验证检查项 122」
- 「跑下 XX 检查项的准确率」「帮我把 122 测一下」

## 前置

1. 读 `config.yaml`：`base_url` / `model` / `accuracy_threshold`(0.90) / `first_batch`(10) / `second_batch`(30) / `max_iterations`(3)
2. 接口契约见 `references/api-contract.md`，**所有调用前先读它**

## 业务语义（必读 — 二次确认模型）

> **AI 复核功能是二次确认**：本地小模型先判定"违规" → 大模型 AI 复核确认/推翻。
> - `isValid=true`  ⇔ 确认违规（未佩戴一次性手套）
> - `isValid=false` ⇔ 推翻（合规/已佩戴）

提示词必须明确写出这个语义，否则 AI 会把"未佩戴"判为 isValid=false（反向错误）。

## 执行流程

### Step 1 解析输入

- `checkCode`（必填，如 `122`）
- `typeName`（检查项名称，如 `开切未佩戴手套`）—— 用户没说则先查 resultList 任意一条拿 `checkName`
- `promptName` 约定 = `ai-<checkCode>`（如 `ai-122`）

### Step 2 起草新提示词（不创建，先在内存里生成）

**必须包含三段**：

```
## 任务背景
本地小模型已先行判定图中存在「<checkName>」违规。
**当前任务是【二次确认】**：对本地小模型的违规判定结果做复核。

## 二次确认语义（重要）
- isValid=true  ⇔ 确认本地模型判断正确（确实违规/未佩戴）
- isValid=false ⇔ 推翻本地模型判断（合规/已佩戴）—— 必须有明确证据

## 审核标准
...（按业务补充）
```

**不要查现有提示词**。

### Step 3 创建新提示词（拿 id）

走 servless 代理路径 `POST /aiRecognition/reviewPromptCreate`（**不是 ai-store-api 的原生 /vfm-review-prompt/create**），必须带鉴权头。

返回 `data.id` 记为 `promptId`，本会话唯一标识。

### Step 4 拉已复核样本（取 N 条）

走 servless `POST /aiRecognition/resultList`（不是 ai-store-api 原生路径），按 `checkCode` + `reviewResult`（1 或 2）分两次拉，按 sampleId 去重。

- 数量不足 `first_batch` → 用全部可用 + 提示
- 优先均衡：1/2 结论轮询取数
- 优先选 reviewResult=1（违规）+ reviewResult=2（合规），各占一半

### Step 5 用新 promptId 重跑

走 servless `POST /aiRecognition/reVerifyByIds`：

```
{
  "ids": [...vfmResultId字符串数组],
  "model": "<model>",
  "promptId": "<新建id字符串>"
}
```

**注意**：`ids` 和 `promptId` 必须是字符串（前端传的是字符串，不是数字）。

**性能与超时**：
- 单条 ~3s，10 条 ~32s，30 条 ~60s
- 网关 60s 限制：30 条会超时（503），**分批跑（建议 15 条/批）**

### Step 6 计算准确率

response.data.data 是数组，每条含 `sample.reviewResult`（人工标准答案）和 `result.isValid`（AI 判定）：

```
人工 reviewResult: 1 = 违规, 2 = 合规
AI isValid:        true = 违规（与人工 1 一致）, false = 合规（与人工 2 一致）
一致性: reviewResult === (isValid ? 1 : 2)
```

```
有效条数 = success=true 且 result.isValid 非空
不同条数 = Σ 不一致
accuracy = (有效条数 - 不同条数) / 有效条数
```

### Step 7 分级判断

```
accuracy >= 0.90
├─ 本轮是 first_batch(10) → 扩到 second_batch(30)：
│     Step 4 重取 30 条（**分 2 批 15 条跑**避免网关超时）→ Step 5 → Step 6
│     ├─ 复验仍 >= 0.90 → ✅ 通过
│     └─ 复验 < 0.90   → 进入 Step 8 迭代
└─ accuracy < 0.90 → 进入 Step 8 迭代
```

### Step 8 低准确率迭代（半自动，≤ max_iterations 轮）

每轮：

1. AI 分析差异样本（看图 + 人工结论 + AI 结论 + AI 理由）→ 归纳错判模式
2. 产出：**改写建议** + **完整的新提示词**（保持二次确认语义三段结构）
3. 向用户展示改写说明 + 新提示词，**必须等待用户确认**
4. 确认后**只**更新本会话创建的那个 promptId：

```
POST /aiRecognition/reviewPromptUpdate   body: { id: promptId, prompt: "..." }
```

5. 回到 Step 4 → Step 7。**不需要新建 promptId**，同一 id 反复 update 即可，`(sampleId, promptId)` 唯一 upsert 覆盖旧结果

- 达到 `max_iterations`(3) 轮仍 < 0.90 → 输出「⚠️ 未达标」报告并停止
- **任何时候都不得修改其他提示词**

### Step 9 输出报告

```markdown
# 提示词验证报告 — type 122「开切未佩戴手套」
- 新建提示词 ID / 名称：<promptId> / ai-122
- 模型 / 环境 / 时间
- 业务语义提示：AI 复核 = 二次确认（isValid=true=确认违规）
- 准确率汇总：每轮 first_batch / 复验
- 差异样本清单：sampleCode / 人工结论 / AI结论 / AI理由
- 迭代历史：每轮提示词变更摘要 + 准确率变化
- 结论：✅ 通过（≥90%） / ⚠️ 未达标
```

报告保存到 `.trellis/tasks/<task>/reports/` 或用户指定路径。

## 注意（关键沉淀）

- **永远只动本会话创建的那个 promptId**（`ai-<checkCode>`），不动任何现有提示词
- **同一 promptId 复用**：`update` 后重跑会自动 upsert 覆盖旧结果，**不要新建**
- **网关超时**：30 条会 503，**分批跑（15 条/批）**
- **ids 和 promptId 必须是字符串**（前端传字符串）
- **必须走 servless 代理路径 `/aiRecognition/...`**，不是 ai-store-api 原生 `/vfm-.../`，且必须带鉴权头
- 后端会自动追加 `## 本次审核信息` 和 `## 输出格式要求` 到 prompt，**不要在 prompt 里重复写**
- 模型：默认 `qwen3-vl-plus`；`qwen3-vl-4b-local` 测试环境有出网白名单问题
- 跑数慢（10 条 ~32s/批），进度要主动反馈用户
