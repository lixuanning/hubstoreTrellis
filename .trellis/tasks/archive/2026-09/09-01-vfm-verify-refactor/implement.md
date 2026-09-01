# Implement — vfm-verify 重构

## 步骤

### 1. 抽 LLM 调用公共方法

文件：`vfm-verify.service.ts`

- 复制 `verifyByIds` 中的 `resolvePrompt` + `buildFullPrompt` 组合到新方法 `runReviewPipeline`
- 返回结构：`{ result: VfmVerifyResult, prompt: string, promptId: number|null, promptName: string, source: string }`
- 不写库

### 2. 抽结果表写入公共方法

文件：`vfm-verify.service.ts`

- 新增 `saveResultEntity(params)`
- 按 `sampleId + promptId + deleted=0` 查已有 → 覆盖；无则新建
- 字段映射与原 `verifyByIds` 中 `targetEntity` 构造一致

### 3. 改默认模型

文件：`vfm-verify.service.ts`

- `this.defaultModel = 'qwen3.5-plus'`（显式赋值）
- 在 `modelConfigs` 中 `qwen3.5-plus` 加注释：「** 默认模型，接口未传 model 时使用」

### 4. 重构 `verifyByIds` 和 `reVerifyByIds`

- 两个方法主体都改为：循环 → `runReviewPipeline` → `saveResultEntity`
- 删除方法内 copy-paste 的 prompt 构建和 result 写入代码
- 行为完全等价（除 `isReVerify` 标志）

### 5. 标记旧接口 `@deprecated`

- `verifySample` / `verifyBatch` 加 JSDoc `@deprecated` 指向 `/vfm-verify/pipeline`
- `verifyByIds` 加 JSDoc `@deprecated` 指向 `/vfm-verify/pipeline`（行为相似）

### 6. 新增 `POST /vfm-verify/pipeline`

文件：
- `vfm-verify.service.ts` — 新增 `pipeline(dto)` 方法
- `vfm-verify.controller.ts` — 新增 `@Post('pipeline')` 端点
- `vfm-verify/dto/pipeline.dto.ts` — 新增 DTO（继承 CreateVfmSampleDto + 可选 model/promptId/callbackUrl）

流程：
```
1. sample = vfmSampleService.createOrUpdate(dto)
2. { result, prompt, promptId, promptName } = runReviewPipeline(sample, dto.model, dto.promptId)
3. resultEntity = saveResultEntity({ sample, verifyResult: result, selectedModel, prompt, promptId, promptName, isReVerify: false })
4. if dto.callbackUrl: 异步触发（暂 TODO log，不实际 POST）
5. return { sample, result: resultEntity, review: result }
```

注意：循环中已有 setTimeout 500ms 防限流，pipeline 单次调用不需要 batch 间隔。

### 7. 依赖注入调整

- `VfmVerifyService` 需要注入 `VfmSampleService`（用于 pipeline 调 createOrUpdate）
- `VfmSampleService` 必须在 `VfmSampleModule` 中 exports（已 exports ✅）
- `VfmVerifyModule` 需 import `VfmSampleModule`（如果还没有的话）

### 8. 更新 `api-docs.md`

文件：`vfm-verify/api-docs.md`

- 在「接口列表」新增 4.5 或编号 8：`POST /vfm-verify/pipeline` 完整章节
- 在「接口列表」新增 9：`POST /vfm-verify/re-verify` 完整章节（之前是第 4 节，挪到末尾）
- 顶部「核心业务规则」补充「默认模型」说明

### 9. 验证

```bash
# 编译/类型检查
cd ai-store-api && npx tsc --noEmit

# curl 验证 pipeline
curl -X POST http://localhost:3000/vfm-verify/pipeline \
  -H "Content-Type: application/json" \
  -d '{ ... }'

# curl 验证 re-verify
curl -X POST http://localhost:3000/vfm-verify/re-verify \
  -H "Content-Type: application/json" \
  -d '{ "ids": [...], "model": "qwen3.5-plus" }'

# curl 验证默认模型
curl -X POST http://localhost:3000/vfm-verify/models
```

### 10. 提交

- 检查 dirty
- 单 commit：`refactor(vfm-verify): 抽 LLM/DB 抽象层 + 新增 pipeline 一体化接口`
- 包含：service / controller / dto / api-docs.md
- 不 push

## 验证 gate

- [ ] `tsc --noEmit` 通过
- [ ] swagger 列出新 pipeline 端点
- [ ] `models` 接口返回的 qwen3.5-plus 含「默认」字样
- [ ] pipeline 接口 curl 成功（返回 sample + result + review）
- [ ] re-verify 接口 curl 成功（结果表记录被覆盖，不是新增）
- [ ] api-docs.md 已更新

## 备注

- 这次不删旧接口
- 回调地址实现是后续任务，本次仅打 TODO log
