# 提示词验证报告 — type 122「开切未佩戴手套」

- **新建提示词 ID / 名称**：21 / ai-122
- **模型**：qwen3-vl-plus
- **环境**：测试（storehub-servless.bgms.tencent-test.pagoda.com.cn）
- **时间**：2026-08-17 03:21 (CST)
- **调用**：`POST /aiRecognition/reVerifyByIds`

## 准确率汇总

| 阶段 | 有效条数 | 一致 | 准确率 | 阈值 | 结论 |
|---|---|---|---|---|---|
| 首轮 10 条 | 10 | **0** | **0.00%** | 90% | ❌ 未达标 |

## 差异样本清单（10/10 全部不一致）

10 条样本中：
- **人工 reviewResult=1（= 违规/未佩戴）**：10 条
- **AI isValid=false（= 合规/已佩戴）**：10 条
- 人工与 AI **方向相反** — 每条都判反

| sampleCode | 人工 | AI | AI 理由摘要 |
|---|---|---|---|
| dfce3ff4…-1 | 1 | false | 双手裸露未佩戴手套 |
| dfce3ff4…-1 | 1 | false | 双手裸露未佩戴手套 |
| dfce3ff4…-1 | 1 | false | 右手裸露、左手背裸露无覆盖 |
| d374bacf…-1 | 1 | false | 双手裸露未戴手套 |
| fe305864…-1 | 1 | false | 双手裸露未覆盖（指尖到手腕） |
| 0dbadbc6…-1 | 1 | false | 双手裸露、砧板上开切 |
| 0b3c7843…-1 | 1 | false | 双手裸露无任何覆盖物 |
| db4bdf9a…-1 | 1 | false | 双手裸露、位于开切区域 |
| 45f56ef2…-1 | 1 | false | 双手从指尖到手腕完全裸露 |
| b3d088de…-1 | 1 | false | 双手裸露、砧板上方操作 |

## 结论与诊断

⚠️ **未达标（0%）**。问题不在 AI 视觉判断 — AI 实际看图正确识别了"员工裸露、未戴手套"。

**问题在提示词语义方向**：
- 平台 `vfm_debug_result.vfmCheckResult` 语义是 **1=是/违规，2=否/合规**
- AI 输出 `isValid=true` 对应"是违规"（未戴），`isValid=false` 对应"否/合规"（已戴）
- 我起草的 ai-122 提示词里写"判断员工是否正确佩戴"→ AI 把"未佩戴"识别为"不正确→isValid=false"——AI 严格按字面理解，但**平台期望 isValid=true 才是违规**
- 与 `人工 reviewResult=1（违规）` 全部相反，导致 100% 不一致

## 后续建议（迭代 Round 1）

修改 ai-122 提示词（id=21），明确语义方向：

```
## 审核标准
**任务**：判断图中员工是否【违规】（未佩戴一次性手套）。
**输出 isValid 取值**：
- isValid=true  ⇔ 员工违规（未戴一次性手套）
- isValid=false ⇔ 员工合规（已正确佩戴手套）
```

更新提示词后用 vfm-review-prompt/update 改 id=21，**重新跑同一批 10 条**。
