# 提示词自动验证 Skill — 实施计划

## 实现清单（有序）

- [x] 1. 创建目录 `.trae/skills/prompt-verify/`（结构见 design.md §2；目录按平台实际生效位置 `.trae/skills/`，非 `.agents/skills/`）
- [x] 2. 编写 `config.yaml`：默认值（base_url/model/0.90/10/30/3）
- [x] 3. 编写 `references/api-contract.md`：包含 `vfm-review-prompt/create` + `vfm-result/list`（联表，promptId 过滤）+ `vfm-verify/re-verify` 三个核心接口
- [x] 4. 编写 `SKILL.md`：**新流程**（基于用户纠正）—— 新建 ai-<checkCode> 提示词（不查现有）→ vfm-result/list 取 vfmResultId → re-verify 指定 promptId → 用 aiConclusionDifferent 算准确率 → 低准确率改写新建的 → ≤3 轮
- [x] 5. 冒烟：本地 `http://localhost:3000` 执行 create + 选样本两步通过；re-verify 失败（**后端 Bug**，见下）

## 冒烟结果（2026-08-17，本地 localhost:3000）

| 步骤 | 结果 |
|---|---|
| vfm-review-prompt/create | ✅ promptId=21（name=ai-122）已创建 |
| vfm-result/list 取样本（reviewResult=1,2） | ✅ 取到 10 条 vfmResultId |
| vfm-verify/re-verify（ids, model, promptId=21） | ❌ **10 条全部 success=false："验证结果记录不存在或已删除"** |
| vfm-result/list promptId=21 查询 | ❌ total=0，证实 re-verify 未写入数据 |

## 发现的后端 Bug

**位置**：`ai-store-api/src/ai-recognition/vfm-verify/vfm-verify.service.ts:844`

```ts
const results = await this.vfmResultRepository.findByIds(resultIds, {
  where: { deleted: 0 },
});
```

**问题**：TypeORM 0.2.25 中 `Repository.findByIds(ids, options)` 的 options 形参不生效 / 与 `andWhereInIds` 兼容异常——同 id 集合，`createQueryBuilder('vdr').andWhere('vdr.id IN (:...ids)', {ids})` 能查到，`findByIds` 查不到。

**影响**：`vfm-verify/re-verify` 整个接口不可用（无论 vfmResultId 是否存在，都返回"不存在"）；`vfm-verify/verify-by-ids` 走 `vfmSampleRepository.findByIds`，可能也有同类问题（但 sample id 字段下原始测试未完全确认，需独立验证）。

**修复建议**（任选其一）：
1. 改用 `In` 查询：`this.vfmResultRepository.find({ where: { id: In(resultIds), deleted: 0 } })`
2. 改用 createQueryBuilder：`qb.where('id IN (:...ids)', { ids: resultIds }).andWhere('deleted = 0').getMany()`

> 同样 `verifyByIds`（line 598）也是 `findByIds`——建议一起改。

## 当前 Skill 状态

- 流程本身（Step 1-9）已与平台 web 端 ModelDebug / PromptSettings 的操作 1:1 对齐，**不动现有提示词**
- api-contract.md 与 SKILL.md 都按新流程写完
- 冒烟卡在 re-verify（后端 Bug），未拿到准确率数据
- 修复后端 `findByIds` 后可继续跑

## 验证命令（修后端后）

```bash
# 1. 创建提示词
curl -X POST http://localhost:3000/vfm-review-prompt/create \
  -H "Content-Type: application/json" \
  -d '{"type":"122","typeName":"开切未佩戴手套","name":"ai-122","prompt":"## 审核标准\n..."}'

# 2. 拿 vfmResultId
curl -X POST http://localhost:3000/vfm-result/list \
  -H "Content-Type: application/json" \
  -d '{"checkCode":"122","reviewResult":1,"pageSize":50}'

# 3. 重跑（指定 promptId=新建 id）
curl -X POST http://localhost:3000/vfm-verify/re-verify \
  -H "Content-Type: application/json" \
  -d '{"ids":[...],"model":"qwen3.7-plus","promptId":<新建id>}'

# 4. 查准确率
curl -X POST http://localhost:3000/vfm-result/list \
  -H "Content-Type: application/json" \
  -d '{"checkCode":"122","promptId":<新建id>,"pageSize":100}'
```

## 风险点 / 回滚

| 风险 | 应对 |
|---|---|
| 后端 findByIds Bug 导致 re-verify 不可用 | 修复后端 `findByIds` 用法（见上） |
| 提示词误改 | **永远只 update 本会话 create 的 id**（SKILL.md 强调） |
| 跑数慢 | 10 条 ~5-15s/条，Skill 主动反馈进度 |
| 验证后未清理 | Step 10 询问用户是否删除新建提示词 |


## 风险点 / 回滚点

| 风险 | 应对 |
|------|------|
| vfm-sample/list 不支持 reviewResult 多值筛选 | 分两次请求（=1、=2）合并（design.md §3.2 已设计） |
| verify-by-ids 响应字段名与预期不符 | 以 vfm-result/list 联表复核为准，修正 api-contract.md |
| 测试环境访问不通 | base_url 走内部域名 `http://ai-store-api.aixundian`（本地则 localhost:3000） |
| 提示词误改 | update 前强制用户确认；结果表保留多版本可回看 |

## 完成后检查

- [ ] Skill 能被触发（用户指令 → 流程执行）
- [ ] 报告输出含：准确率、差异清单、迭代历史、结论
- [ ] 验证结果可追溯（vfm_debug_result 有新增记录）
- [ ] 与 spec（ai-store-api/ai-recognition）一致，无新增后端改动
