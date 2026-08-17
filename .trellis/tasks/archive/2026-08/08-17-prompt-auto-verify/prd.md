# 提示词自动验证 Skill 设计

## Goal

将"人工在平台上生成提示词 → 跑分类数据 → 人工对比结论差异 → 修改提示词"的流程自动化。通过一个可复用的 Skill，自动完成"跑数 → 算准确率 → 分级验证 → 低准确率迭代修改提示词"的闭环，减少人工介入。

## 用户价值

- 提示词验证从"人工逐条对比"变为"自动跑数 + 自动算准确率 + 自动迭代"
- 同一流程可在团队内复用（Skill 形态）
- 每次验证结果可追溯（落库到 vfm_debug_result）

## 背景与已确认事实

### 后端已有能力（ai-store-api/src/ai-recognition/）

| 模块 | 已有接口 | 用途 |
|------|---------|------|
| vfm-verify | `verify-by-ids` / `re-verify` / `models` / `rules` | 按样本批量跑 AI / 按结果重跑 / 模型列表 / 检查项 |
| vfm-review-prompt | `list` / `create` / `update` / `remove` / `detail` | 提示词 CRUD（同 type 下 enabled 互斥） |
| vfm-sample | `list`（reviewResult 筛选）/ `update` | 样本查询 + 人工复核结论 |
| vfm-result | `list`（联表，含 `aiConclusionDifferent` 筛选）/ `tag` | 结果查询，已计算结论是否不同 |
| vfm-tag | `list` / `create` / `update` / `remove` | 标签管理 |

- vfm 接口**无 JWT 鉴权**（ai-recognition 下无 UseGuards，app.module 无全局守卫）→ Skill 可直接 curl
- 结论对比语义：人工 `review_result`（0 未复核/1 是/2 否/3 待定）vs AI `vfm_check_result`（1 是/2 否/3 待定）
- 准确率口径：排除人工待定(3)；AI 无有效判定(>0)不计入分母

### 前端现状（storehub-web/src/views/universal/aiRecognition/）

- 4 个 Tab：样本数据审核 / 审核记录 / 提示词设置 / 标签管理
- 审核记录页已有"结论是否不同"筛选 + 红色高亮
- **无准确率汇总** → 准确率由 Skill 本地计算

## Requirements

- R1: Skill 按 checkCode + 提示词选取已有人工结论的样本（reviewResult ∈ {1,2}）
- R2: Skill 调用 verify-by-ids 跑数（可指定模型、提示词）
- R3: Skill 本地计算准确率，输出差异样本清单（样本ID/图/人工结论/AI结论/AI理由）
- R4: 分级验证：首轮 10 条，≥90% 扩到 30 条复验
- R5: 低准确率迭代：AI 分析差异样本 → 修改建议 + 新提示词 → **用户确认后** update 重跑，≤3 轮
- R6: 每会话输出 Markdown 报告（准确率、差异清单、迭代历史、结论）
- R7: 手动触发（用户指令"验证提示词 X"）

## Acceptance Criteria

- [ ] 输入 checkCode + 提示词，Skill 自动选取已复核样本并跑数
- [ ] 输出准确率 + 差异样本清单（可定位具体哪条判错）
- [ ] ≥90% 自动扩样本到 30 条复验；<90% 进入迭代（用户确认后 update）
- [ ] 迭代 ≤3 轮，未达标输出"未达标"报告并停止
- [ ] 验证结果写入 vfm_debug_result，可追溯
- [ ] 已复核样本不足时给出明确提示

## 关键决策

| 决策 | 结论 | 理由 |
|------|------|------|
| 自动化边界 | 半自动（AI 建议 → 用户确认 → update） | 提示词改动风险高；符合"AI 提议、用户决定"原则 |
| 触发方式 | 手动指令 | 简单可控、不耗额度 |
| 后端交互 | MVP 不做 MCP，Skill 直接 curl HTTP | 接口已齐全、无鉴权，零新增基础设施 |
| 迭代上限 | 3 轮 | 避免无限循环 |
| 后端改动 | 零改动 | 复用现有接口，准确率本地算 |

## Out of Scope

- 样本的人工标注（依赖已有 reviewResult ∈ {1,2} 的样本）
- 修改 web 前端页面（不新增统计 UI）
- MCP server 开发（后续团队复用再评估）
- 模型调优 / 训练

## 风险与延迟项

- 样本质量依赖人工标注：reviewResult 标注错误会污染准确率
- 本地模型 `qwen3-vl-4b-local` 在测试环境有出网问题（已定位），Skill 默认用阿里云模型
- 后端后续若加鉴权，需在 config.yaml 补充 token 头

## 产物

- prd.md（本文档）
- design.md：架构、数据流、验证循环、配置、报告格式
- implement.md：实现清单、验证命令、风险回滚点
