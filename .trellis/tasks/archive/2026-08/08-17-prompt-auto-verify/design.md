# 提示词自动验证 Skill — 设计文档

## 1. 架构与边界

```
用户手动指令（"验证提示词 X"）
        │
        ▼
[SKILL: prompt-verify]  ← 位于 .agents/skills/prompt-verify/
   │  1. 读配置（base URL / 模型 / 阈值 / 样本量）
   │  2. 拉提示词 + 选样本
   ▼
ai-store-api HTTP 接口（curl 直调，无鉴权）
   ├─ POST /vfm-review-prompt/list       拉提示词
   ├─ POST /vfm-sample/list              选已复核样本
   ├─ POST /vfm-verify/verify-by-ids     跑 AI 验证
   └─ POST /vfm-review-prompt/update     更新提示词（迭代时）
```

**边界**：
- Skill 只做**编排 + 准确率计算 + 报告**，不落库新表（复用现有 vfm_debug_result）
- 不改 web 前端、不改后端代码（MVP）
- 不依赖 MCP（决策：MVP 直接 HTTP）

## 2. Skill 结构

```
.agents/skills/prompt-verify/
├── SKILL.md              # 触发词 + 执行流程说明（给 AI 读）
├── config.yaml           # base_url / model / accuracy_threshold / sample_size / max_iterations
└── references/
    └── api-contract.md   # 4 个接口的路径、参数、响应字段说明
```

SKILL.md 是核心——它是给 AI 的**流程指令**，AI 按步骤执行（curl + 计算），具体接口契约放 references/。

## 3. 数据流与接口契约

### 3.1 拉提示词
```
POST {base_url}/vfm-review-prompt/list   body: { type: "35", enabled: 1 }
→ data[].prompt / .name / .typeName
```

### 3.2 选样本（已有人工结论）
```
POST {base_url}/vfm-sample/list   body: { checkCode: "35", reviewResult: 1, pageSize: 50 }
POST {base_url}/vfm-sample/list   body: { checkCode: "35", reviewResult: 2, pageSize: 50 }
→ 合并 reviewResult∈{1,2} 的样本（排除 0 未复核 / 3 待定），取 N 条
→ 记录每条 sample 的 { id, checkImage, reviewResult } 作为"标准答案"
```

### 3.3 跑 AI 验证
```
POST {base_url}/vfm-verify/verify-by-ids   body: { ids: [sampleIds], model, promptId }
→ 每条返回 vfmCheckResult（1/2/3）写入 vfm_debug_result（自动落库）
```

### 3.4 计算准确率（Skill 本地计算）
```
accuracy = 一致条数 / 已复核且 AI 有效判定(>0) 的条数
一致 = sample.reviewResult === result.vfmCheckResult
AI 待定(3) 或失败 → 不计入分母，单独列为"无效样本"
```

### 3.5 迭代时更新提示词（半自动）
```
AI 分析差异样本（图 + 人工结论 + AI 结论 + AI 理由）→ 产出修改建议 + 新提示词
→ 展示给用户 → 用户确认后：
POST {base_url}/vfm-review-prompt/update   body: { id, prompt: 新提示词 }
→ 重新执行 3.2 → 3.4（最多 max_iterations 轮）
```

## 4. 验证循环流程（核心逻辑）

```
输入：checkCode / promptId / 模型 / 目标准确率(默认0.90) / 样本量(10→30)

┌─ Round 1: 取 10 条已复核样本 → 跑 AI → 算准确率
│
├─ accuracy ≥ 0.90 ─→ 扩样本到 30 条 → 复验
│                       ├─ 仍 ≥ 0.90 → ✅ 通过，输出报告
│                       └─ < 0.90   → 进入迭代
│
└─ accuracy < 0.90 ─→ AI 分析差异样本 → 给出修改建议+新提示词
                        → 用户确认 → update 提示词 → 重跑
                        → 重复，最多 max_iterations=3 轮
                        → 3 轮后仍未达标 → 输出"未达标"报告，停止（不强制通过）

特殊处理：
- 已复核样本不足 N 条 → 提示"样本不足，当前仅 X 条"，用可用量验证
- AI 待定/失败占比过高(>50%) → 提示模型或提示词问题，暂停
```

## 5. 配置（config.yaml 默认值）

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `base_url` | `http://localhost:3000` | 测试环境 `http://ai-store-api.aixundian` |
| `model` | `qwen3.7-plus` | 注意：本地模型 `qwen3-vl-4b-local` 在测试环境有网络问题（出网白名单），生产/测试建议用阿里云模型 |
| `accuracy_threshold` | `0.90` | 达标线 |
| `first_batch` | `10` | 首轮样本量 |
| `second_batch` | `30` | 复验样本量 |
| `max_iterations` | `3` | 迭代上限 |
| `default_prompt_id` | 无 | 用户指定或用 checkCode 当前 enabled 提示词 |

## 6. 报告输出

每个验证会话输出一份 Markdown 报告（存 `.trellis/tasks/<task>/reports/` 或用户指定路径）：

```
# 提示词验证报告 — type 35「开切未佩戴口罩」
- 提示词版本 / 模型 / 环境 / 时间
- 准确率汇总：首轮 X/Y，复验 X/Y
- 差异样本清单：样本ID / 图 / 人工结论 / AI结论 / AI理由
- 迭代历史：每轮提示词变更摘要 + 准确率变化
- 结论：✅ 通过 / ⚠️ 未达标
```

## 7. 权衡与风险

| 项 | 说明 |
|----|------|
| 无鉴权接口 | 当前 vfm 接口未加 JWT，Skill 直调可行；后续加鉴权需在 config 加 token 头 |
| 样本质量依赖人工标注 | 准确率参考值依赖已有 reviewResult，标注错误会污染验证结果 |
| 半自动迭代 | 每轮修改需用户确认，避免 AI 乱改提示词（已确认此决策） |
| 本地模型网络问题 | 测试环境访问 CSDN GPU 云被拦（前次已定位），Skill 默认用阿里云模型 |
| 无后端 stats | 准确率由 Skill 本地计算，不新增后端接口（MVP 决策） |

## 8. 回滚与可追溯

- 提示词更新走 `vfm-review-prompt/update`，历史版本保留在结果表（re-verify 会保留多版本记录）
- 每次验证结果写入 `vfm_debug_result`（含 promptId/promptName/环境/模型），可回看
- Skill 自身无状态，重跑即重验
