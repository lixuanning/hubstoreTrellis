# vfm-verify 重构：抽 LLM 调用 + DB 写入，新增 pipeline 一体化接口

## Goal

把 `VfmVerifyService` 里散落的 4 个验证方法（`verifySample` / `verifyBatch` / `verifyByIds` / `reVerifyByIds`）共有的核心步骤抽出来：① LLM 调用（buildPrompt + callVisionApi）② 结果表写入/更新（按 sampleId+promptId upsert）。前端实际只用 2 个接口——基于记录表（sample）的复核、基于结果表（result）的再次复核——其他 3 个保留兼容。

## 背景

### 现状
- `verifySample` / `verifyByIds` / `reVerifyByIds` 各自重复实现了"读样本 → 构 prompt → 调 LLM → 写 result"
- `verifySample` 走 `reviewConfigService.buildPrompt`（单一提示词源）
- `verifyByIds` / `reVerifyByIds` 走 `resolvePrompt + buildFullPrompt`（DB 提示词 + 动态信息）
- 4 个方法字段拼装、结果表写入逻辑高度重复

### 问题
- 修改一处逻辑需要同步改多处，容易漏
- 调试平台基于前端选模型、接口触发无模型选择场景下默认走数组首位 `qwen3.7-plus`，不符合预期
- 没有"接收入参 → 写入记录表 → 跑复核 → 写入结果表 → 回调"的一体化接口，对接方需要先调 `/vfm-sample/create` 再调 `/vfm-verify/*`

## Requirements

### 功能需求

1. **抽象 LLM 调用层**
   - 抽出私有方法 `runReviewPipeline(sample, model?, promptId?)`，内部完成 `resolvePrompt` + `buildFullPrompt` + `callVisionApi`，返回 `{ result, prompt, promptId, promptName, source }`，不写库
2. **抽象结果表写入层**
   - 抽出私有方法 `saveResultEntity({ sample, verifyResult, selectedModel, prompt, promptId, promptName, isReVerify })`，按 `sampleId+promptId` 查已有记录做 upsert，覆盖保留原 `id` / `createTime` / `vfm_*` 关联字段
3. **改默认模型**
   - `defaultModel` 显式设为 `'qwen3.5-plus'`，不再依赖 `modelConfigs[0]`
   - 在 `modelConfigs` 中给 `qwen3.5-plus` 加注释说明这是默认模型
4. **新增 `POST /vfm-verify/pipeline`（记录表复核一体化接口）**
   - 入参：`CreateVfmSampleDto`（含 sampleCode、门店/检查项/图片等）+ 可选 `model` + 可选 `promptId` + 可选 `callbackUrl`
   - 流程：
     1. 调 `vfmSampleService.createOrUpdate` 写 sample（按 sampleCode 唯一键 upsert）
     2. 读回最新 sample
     3. 调 `runReviewPipeline` 跑复核
     4. 调 `saveResultEntity` 写 result
     5. 触发回调（`callbackUrl` 非空时 POST `result` + `sampleCode`，目前放空仅 TODO log）
   - 返回：`ResponseDto<{ sample, result, review }>`
5. **重构 `POST /vfm-verify/re-verify`（结果再次复核）**
   - 入参不变：`{ ids: number[]; model?; promptId? }`
   - 内部调用 `runReviewPipeline` + `saveResultEntity({ isReVerify: true })`
   - 行为：按 resultId 拿 sample，调 LLM，按 `sampleId+promptId` upsert 结果（不生成新 resultId）
6. **保留兼容**
   - `verifySample` / `verifyBatch` / `verifyByIds` 暂保留，标记 `@deprecated` 指向新接口；下个迭代可移除
   - `models` / `rules` / `prompts` 元数据接口保持不变

### 非功能需求

- 行为等价：重构后 4 个旧接口的响应字段、写入逻辑与重构前完全一致（除默认模型变化）
- 错误处理：单条失败不影响 batch 内其他样本
- 日志：每条样本的 prompt 解析源、模型、是否 upsert 都打 log

## Acceptance Criteria

- [ ] `VfmVerifyService` 新增 `runReviewPipeline` 和 `saveResultEntity` 私有方法
- [ ] `verifyByIds` / `reVerifyByIds` 改用新抽象（不再有重复的 prompt 构建和 result 写入代码）
- [ ] `defaultModel = 'qwen3.5-plus'`，且在 `modelConfigs` 中标注
- [ ] 新接口 `POST /vfm-verify/pipeline` 已注册到 swagger
- [ ] curl 验证 `pipeline`：写入 sample → 跑复核 → 写 result 全链路成功
- [ ] curl 验证 `re-verify`：传 resultId 列表，跑完后 `sampleId+promptId` 唯一记录被覆盖
- [ ] curl 验证 `models` 接口返回的 `qwen3.5-plus` 描述含「默认」字样
- [ ] `api-docs.md` 同步更新

## Notes

- 旧的 `verifySample` 走 `reviewConfigService.buildPrompt`，新的 `pipeline` 走 `resolvePrompt + buildFullPrompt`。两个提示词源并存，pipeline 用 DB 优先（与 `verifyByIds` 一致）
- 回调接口暂不放空实现，仅打 TODO log 和结构化字段，避免无 callbackUrl 时不报错
- 这次不删旧接口，避免影响其他调用方；后续可在迭代中清理
