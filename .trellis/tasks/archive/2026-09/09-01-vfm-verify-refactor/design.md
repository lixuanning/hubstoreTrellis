# Design — vfm-verify 重构

## 架构目标

把 4 个验证方法（`verifySample` / `verifyBatch` / `verifyByIds` / `reVerifyByIds`）共有的"调 LLM"和"写 result"逻辑抽出来，让前端用的 2 个接口（`pipeline` / `re-verify`）共用同一份核心实现。

## 模块/类结构

### `VfmVerifyService`（重构）

私有方法（新增）：

```ts
/**
 * LLM 调用抽象层：解 prompt → 拼完整 prompt → 调阿里云百炼 → 解析结果
 * 不写库，纯计算。返回结构化结果供调用方决定如何落库。
 */
private async runReviewPipeline(
  sample: VfmSampleEntity,
  model?: string,
  promptId?: number,
): Promise<{
  result: VfmVerifyResult;
  prompt: string;
  promptId: number | null;
  promptName: string;
  source: string;
}>

/**
 * 结果表写入抽象层：按 sampleId + promptId 查已有 → 有则覆盖 / 无则新建
 * 保留原 id / createTime / vfmCheckEnv / vfmCheckPromptVersion / vfmName / vfmCode / vfmVersion
 */
private async saveResultEntity(params: {
  sample: VfmSampleEntity;
  verifyResult: VfmVerifyResult;
  selectedModel: string;
  prompt: string;
  promptId: number | null;
  promptName: string;
  isReVerify: boolean;
}): Promise<VfmResultEntity>
```

公开方法（调整）：

- `verifySample` / `verifyBatch` — 保留兼容，标记 `@deprecated`
- `verifyByIds` — 内部调用 `runReviewPipeline` + `saveResultEntity`（保持原 `verifyByIds` 行为：sampleId+promptId upsert）
- `reVerifyByIds` — 内部调用 `runReviewPipeline` + `saveResultEntity({ isReVerify: true })`
- `pipeline(dto)` — **新增**，组合 `vfmSampleService.createOrUpdate` + `runReviewPipeline` + `saveResultEntity` + 回调

### `VfmVerifyController`（新增 endpoint）

```ts
@Post('pipeline')
async pipeline(
  @Body() body: PipelineDto,
): Promise<ResponseDto<{ sample, result, review }>>
```

### DTO（新增）

`PipelineDto` = `CreateVfmSampleDto` + `{ model?, promptId?, callbackUrl? }`

## 数据流

### `POST /vfm-verify/pipeline`（记录表复核一体化）

```
client → POST /vfm-verify/pipeline { sampleCode, storeCode, ..., callbackUrl? }
  ↓
controller.pipeline(dto)
  ↓
1. sample = vfmSampleService.createOrUpdate(dto)            ← 已抽象
  ↓
2. { result, prompt, promptId, promptName } = runReviewPipeline(sample, dto.model, dto.promptId)
  ↓
3. resultEntity = saveResultEntity({ sample, verifyResult: result, ..., isReVerify: false })
  ↓
4. if (dto.callbackUrl) fireAndForget(callback, { result, sampleCode })   ← 暂时仅 log
  ↓
5. return { status: 200, data: { sample, result: resultEntity, review: result } }
```

### `POST /vfm-verify/re-verify`（结果再次复核）

```
client → POST /vfm-verify/re-verify { ids: [resultId1, ...], model? }
  ↓
controller.reVerify(body)
  ↓
for each resultId:
  resultEntity = find result by id
  sample = find sample by resultEntity.sampleId
  { result, prompt, promptId, promptName } = runReviewPipeline(sample, model, promptId)
  saveResultEntity({ ..., isReVerify: true })                  ← 按 sampleId+promptId upsert
```

## 关键设计决策

### D1: 抽 `runReviewPipeline` 而非 `callVisionApi`
- `callVisionApi` 已经是最底层（HTTP 调阿里云），不再抽
- 真正重复的是「解 prompt + 构完整 prompt + 调 API + 解析」这整段
- 抽完所有验证方法共享同一段 LLM 逻辑，修改提示词策略只改一处

### D2: 抽 `saveResultEntity` 用参数对象（不用多参数重载）
- 5+ 个参数，重载难维护
- 参数对象未来加字段不破坏调用点

### D3: `defaultModel` 显式赋值，不依赖数组顺序
- 防止后人调整 `modelConfigs` 顺序时静默改变默认
- 显式 `this.defaultModel = 'qwen3.5-plus'`

### D4: pipeline 走 DB 提示词（与 `verifyByIds` 一致），不走 `reviewConfigService.buildPrompt`
- 前端调试平台已有 prompt 选择器，pipeline 不需要再内置硬编码 prompt
- 与 `verifyByIds` 路径一致，避免出现两种 prompt 策略并存

### D5: 回调用 fire-and-forget
- 不阻塞主流程
- 失败仅 log，不影响接口返回
- 当前阶段不实现 POST 调用，仅打 TODO log + 记录 `callbackUrl`

### D6: 旧接口保留 + @deprecated
- 不破坏现有调用方
- 下个迭代清理

## 兼容性与回滚

### 兼容
- 所有现有 endpoint 行为不变（除 `defaultModel`）
- 现有 4 个 controller 端点 URL / 入参 / 出参全部保留
- 新 `pipeline` 是纯增量

### 回滚
- 单 PR，可直接 `git revert`
- 没有数据迁移、没有表结构变更

## 风险

| 风险 | 缓解 |
|------|------|
| 提示词策略切换导致结果差异 | pipeline 走 DB 提示词，与 `verifyByIds` 一致；旧 4 接口行为不变 |
| 默认模型变更影响未传 model 的调用 | 仅影响传 `model: undefined` 的调用方，行为可预期（之前默认 qwen3.7-plus，现在 qwen3.5-plus） |
| 回调地址错误导致主流程阻塞 | fire-and-forget，try/catch + log |
| 重构后行为与原代码不等价 | 单元测试不可用，依赖 curl 回归验证 4 个旧接口 |
