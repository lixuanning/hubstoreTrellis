# AI 复核功能 - 本轮改动测试要点

> 适用版本：v0.x (2026-09-02)
> 涉及后端包：`ai-store-api` / `storehub-servless` / `storehub-web`
> 涉及接口前缀：`/vfm-verify/*`、`/vfm-tag/*`、`/vfm-sample/*`、`/vfm-result/*`

---

## 0. 上线前运维事项（**必做**）

新环境 / 老环境都必须执行 SQL：

- 文件：[`ai-store-api/src/ai-recognition/sql/2025-07-25-create-vfm-tags.sql`](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/ai-recognition/sql/2025-07-25-create-vfm-tags.sql)
- 新环境：建表 + 初始化 2 个系统标签
- 老环境（vfm_tags 已存在无 is_system）：**先打开 ALTER 注释执行**，再执行 INSERT

执行后确认：
```sql
SELECT id, name, is_system FROM vfm_tags WHERE deleted = 0;
-- 期望至少 2 条：网络错误 (is_system=1)、解析失败 (is_system=1)
```

启动服务后日志中应看到：
```
[seed] 创建系统标签: name=网络错误
[seed] 创建系统标签: name=解析失败
```

---

## 1. AI 复核 3 个入口（接口抽象 + 异步化）

后端把 3 个入口统一抽到 `runReviewPipeline` → `callVisionApi` 一条链路：

| 入口 | 接口 | 行为 |
|---|---|---|
| 记录表单条复核 | `POST /vfm-verify/pipeline` | 同步：写 sample → 跑 LLM → 写 result → 回调（缺省不回调） |
| 记录表批量导入 | `POST /vfm-verify/pipeline-batch` | **异步** 2 段式：主接口同步写 sample 后立即返回，后台跑 LLM + 写 result + 回调 |
| 样本表批量复核 | `POST /vfm-verify/verify-by-ids` | **异步**：主接口立即返回，后台跑 |
| 结果表重新复核 | `POST /vfm-verify/re-verify` | **异步**：主接口立即返回，后台跑 |

**统一行为**：
- 默认模型：`qwen3.5-plus`（接口未传 `model` 时）
- 提示词解析：4 级 fallback
  1. 显式 `promptId` 入参
  2. 同 `checkCode` 下 `enabled=1` 的提示词
  3. 同 `checkCode` 下任一提示词（id ASC）
  4. 内置 fallback 模板
- 跑完会更新：`vfm_results.vfm_name` / `vfm_code` / `update_time` 随当时所用模型刷新
- `vfm_check_date = sample.create_time`（与数据来源对齐，不取 LLM 调用时间）

### 测试用例

#### T1.1 单条同步 pipeline（同步场景）

```bash
curl -X POST http://localhost:3000/vfm-verify/pipeline \
  -H "Content-Type: application/json" \
  -d '{
    "sampleCode": "TEST_PIPELINE_001",
    "areaCode": "AREA_001",
    "checkCode": "CHECK_001",
    "checkImage": "https://example.com/xxx.jpg"
  }'
```

- [ ] 返回 `{success:true, data:{sample:{...}, result:{...}, review:{isValid, confidence, reason}}}`
- [ ] `vfm_samples` 新增/覆盖一条
- [ ] `vfm_results` 新增/覆盖一条，`vfmName='qwen3.5-plus'`，`vfmCode='qwen3.5-plus'`
- [ ] `vfm_results.update_time` = 当前时间（不是历史 create_time）

> ⚠️ **重要：`/vfm-verify/pipeline-batch` 已加白名单免签**（对内批量入口），可直接 curl 调用，不需要 aixd 签名头。其它 vfm-* 接口都需带 `aixd: <signature>` 头。

#### T1.2 批量 pipeline-batch（异步场景，200 条+，**白名单免签**）

```bash
curl -X POST http://localhost:3000/vfm-verify/pipeline-batch \
  -H "Content-Type: application/json" \
  -d '{
    "samples": [<200 条 dto>],
    "batchCallbackUrl": "https://your-callback.test/cb"
  }'
```

- [ ] 主接口**秒级返回**（< 1s）`{accepted:true, count:200, sampleIds:[...]}`
- [ ] 即使客户端断开，后端日志继续输出 `[pipeline-batch:BG:PROGRESS] N/200`
- [ ] `vfm_results` 表持续被更新（200 条全部落库）
- [ ] `vfm_results.update_time` 全部是最新
- [ ] 回调：当前未实现回调发送，仅日志 `TODO: callback`（**测试不需要验证回调成功**）

#### T1.3 样本表批量复核 verify-by-ids（异步场景）

```bash
curl -X POST http://localhost:3000/vfm-verify/verify-by-ids \
  -H "Content-Type: application/json" \
  -d '{"ids": [101, 102, 103], "model": "qwen3-vl-plus", "promptId": 7}'
```

- [ ] 主接口立即返回 `{accepted:true, count:3}`
- [ ] 后台日志：`[verifyByIds:BG:START] 共 3 条`
- [ ] 完成后 `vfm_results` 中对应 sampleId 的记录 `vfmName='qwen3-vl-plus'`
- [ ] 入参 `promptId=7` 被尊重（日志可见 `promptId=7`）

#### T1.4 结果表重新复核 re-verify（异步场景）

```bash
curl -X POST http://localhost:3000/vfm-verify/re-verify \
  -H "Content-Type: application/json" \
  -d '{"ids": [201, 202], "model": "qwen3-vl-plus", "promptId": 23}'
```

- [ ] 主接口立即返回 `{accepted:true, count:2}`
- [ ] 2 条 `vfm_results` 各自更新（**不是合并成 1 条**）
- [ ] `promptId=23` 被尊重（**注意：** 之前传 23 实际用了别的 promptId，本轮已修复）

#### T1.5 大数据量不超时（回归）

- [ ] 1000 条 `pipeline-batch`：主接口 < 1s 返回
- [ ] 1000 条 `re-verify`：主接口 < 1s 返回
- [ ] 后端日志显示并发 5 / 节流 500ms 正常推进

---

## 2. 服务端提示词约束移除

> 之前服务端会拼接强制规则（"必须输出 JSON、必须包含 isValid/confidence/reason"），已全部移除。完全靠前端提示词管理控制。

### 测试用例

#### T2.1 提示词为空时 fallback

- [ ] `review_prompts` 中 `checkCode='CHECK_001'` 没有记录
- [ ] 调用 `/vfm-verify/pipeline` 仍然能跑通（用内置 fallback 模板）
- [ ] fallback 模板**只包含** "本次审核信息"（检查项类型 + 图片地址），不包含任何"必须返回 JSON"之类强制规则

#### T2.2 自定义提示词原样透传

- [ ] 在 `review_prompts` 写一条：`checkCode='CHECK_001'`, `content='你是一个收银台检查员，请看图判断收银台是否整洁'`（无任何格式约束）
- [ ] 调用 `/vfm-verify/verify-by-ids` 时传入该 promptId
- [ ] 后端日志输出 `prompt=你是一个收银台检查员...`（**未做任何拼接**）

---

## 3. AI 输出解析失败兼容

> 之前：AI 返回非预期结果（自然语言、缺字段、JSON 不完整）→ 不落库。
> 现在：AI 解析失败也必须落库，标记 `errorType='PARSE_ERROR'`，自动打"解析失败"系统标签。

### 测试用例

#### T3.1 正常 JSON 输出（json_schema strict 生效后）

- [ ] 调 `/vfm-verify/pipeline` 跑通任意 prompt
- [ ] 后端日志可见 payload 含 `response_format.json_schema` 字段
- [ ] AI 返回**纯 JSON**（无 ```json``` 围栏、无自然语言前缀）
- [ ] `vfm_results.is_valid` / `confidence` / `reason` 正常落库
- [ ] **不再**自动打"解析失败"标签（除非真的失败）

#### T3.2 异常 AI 输出（边界 case）

- [ ] 模拟 AI 返回纯自然语言（可通过临时改 prompt 强制 model 输出自然语言）
- [ ] 期望：`vfm_results` 仍然新增一条记录
- [ ] `is_valid=false`, `confidence=0`, `reason='解析失败: ...'`
- [ ] `error_type='PARSE_ERROR'`
- [ ] `raw_response` 字段保留原始输出（截断到 1900 字符）
- [ ] 自动打"解析失败"系统标签（看 `vfm_results.tag_ids` 含该 id）

#### T3.3 网络/HTTP 错误（边界 case）

- [ ] 临时把 `ALIYUN_API_KEY` 改成无效值
- [ ] 调用 `/vfm-verify/pipeline` 仍然落库
- [ ] `error_type='NETWORK_ERROR'`
- [ ] 自动打"网络错误"系统标签

---

## 4. 系统标签（网络错误 / 解析失败）

> 标签管理表新增 `is_system` 字段，2 个系统标签（`网络错误`、`解析失败`）在 `onModuleInit` 启动时幂等 seed。
> 跨环境用 `name` 匹配，不用 `id`（生产环境 id 可能不同）。

### 测试用例

#### T4.1 启动初始化

- [ ] 全新环境：服务启动后 `vfm_tags` 表有 `网络错误` / `解析失败` 两条，`is_system=1`
- [ ] 重复启动：不会重复插入（idempotent，日志只首次输出 `[seed] 创建系统标签`）
- [ ] 兼容老数据：若历史有同名普通标签，会被升级为 `is_system=1`

#### T4.2 前端列表展示

- [ ] 标签管理页面打开后，**网络错误 / 解析失败 显示在最前面**（按 `is_system DESC, create_time DESC` 排序）
- [ ] 系统标签样式：橙色描边 + 黄色背景 + "系统"角标
- [ ] **"编辑" / "删除" 按钮置灰不可点**（hover 提示「系统标签不允许修改」）

#### T4.3 接口保护

| 操作 | 系统标签 | 普通标签 |
|---|---|---|
| `POST /vfm-tag/create` 同名 | ✅ 允许 | ✅ 允许 |
| `POST /vfm-tag/update` 修改名称 | ❌ 返回 400 "系统标签不允许修改" | ✅ 允许 |
| `POST /vfm-tag/remove` 删除 | ❌ 返回 400 "系统标签不允许删除" | ✅ 允许 |

#### T4.4 系统标签联动（关键回归）

- [ ] 一条样本 AI 解析失败 → 自动打"解析失败"标签
- [ ] 再次复核同一条样本，**这次成功** → 重新计算 tagIds 时先清掉"解析失败"，**不会残留**
- [ ] 用户手动打的其他普通标签保留

---

## 5. json_schema 强约束（最新改动）

> 对齐 Java 参考实现：所有走 DashScope / OpenAI 兼容接口的模型都强制 `response_format.json_schema.strict=true`。
> 涵盖：qwen3.5-plus / qwen3.7-plus / qwen3-vl-plus / qwen3-vl-max / qwen-vl-plus / qwen-vl-max / qwen3.6-flash。
> 本地模型 `qwen3-vl-4b-local` 不走此端点，不受此约束。

### 测试用例

#### T5.1 各模型都能跑通

依次用以下模型各跑 1 条样本，期望全部成功：
- [ ] `qwen3.5-plus`（默认）
- [ ] `qwen3.7-plus`
- [ ] `qwen3-vl-plus`
- [ ] `qwen-vl-plus`
- [ ] `qwen3.6-flash`

#### T5.2 响应是纯 JSON

- [ ] 后端日志中 `rawResponse` 字段是 `{...}` 纯 JSON 字符串（不是 ```json\n{...}\n``` 形式）
- [ ] 之前用 qwen3-vl-plus 容易触发的"自然语言前缀"现象消失
- [ ] 「解析失败」系统标签的命中数下降

#### T5.3 失败兜底

- [ ] 如果某个模型不支持 `response_format.json_schema`，Aliyun 返回 400
- [ ] 走 `NETWORK_ERROR` 兜底，**仍然落库**（`error_type='NETWORK_ERROR'`）
- [ ] `rawResponse` 保留 400 错误详情
- [ ] 自动打"网络错误"系统标签
- [ ] 当前已配置 7 个模型都测试通过，不需要再调整 schema

---

## 5.5 aixd 签名鉴权（vfm-* 新增）

> **目的**：防止 vfm-* 接口被任意系统直接调用。`pipeline-batch` 是内部批量入口，已加白名单免签；其它 vfm-* 接口都需 `aixd: <md5签名>` 头。
> **实现**：`AixdMiddleware`（ai-store-api/src/common/middleware/aixd.middleware.ts），挂载在 `vfm*` 路由。失败码 `80000100`。

### 5.5.1 白名单免签（pipeline-batch）

```bash
# 直接 curl，不要任何头
curl -X POST http://localhost:3000/vfm-verify/pipeline-batch \
  -H "Content-Type: application/json" \
  -d '{"samples": [...], "batchCallbackUrl": "..."}'
```

**期望**：
- [ ] 不带 `aixd` 头也能调通（白名单生效）
- [ ] 服务端日志输出 `logai common aixd skip (whitelist): /vfm-verify/pipeline-batch`

### 5.5.2 必签接口（其它 vfm-*）

```bash
# 必须按算法计算 aixd 头，否则 80000100
# 算法见 docs/ai-vfm-verify-auth-chain.md
curl -X POST http://localhost:3000/vfm-verify/pipeline \
  -H "Content-Type: application/json" \
  -H "aixd: <md5 签名>" \
  -d '{"sampleCode": "TEST_001", ...}'
```

**期望**：
- [ ] 带正确 `aixd` 头：调通
- [ ] 不带 `aixd` 头：返回 `{status: 80000100, message: '缺少签名'}`
- [ ] 带错误 `aixd` 头：返回 `{status: 80000100, message: '签名错误'}`
- [ ] servless 转发（web/uniapp 端调用）：自动带 header（已由 servless 中间件注入）

### 5.5.3 mclz / xfdj / JWT 接口不受影响

- [ ] `/mclz/scan-record/getCosAuthorization` 仍按 mclz 签名校验（不影响）
- [ ] `/ai-verify/*` 仍按 JWT 校验（不影响）

---

## 6. 回归必检项

| 编号 | 检查项 | 期望 |
|---|---|---|
| R1 | 前端「记录表」「样本表」页面打开正常 | 不报错 |
| R2 | 记录表 `update_time` 字段 | 每次 AI 复核后更新到当前时间 |
| R3 | 记录表 `vfm_check_date` 字段 | 等于 `sample.create_time`（数据来源时间），**不**等于 AI 复核时间 |
| R4 | 记录表 `vfm_name` / `vfm_code` 字段 | 跟当时调用的模型一致（不是默认 qwen3.5-plus） |
| R5 | 提示词管理「编辑」保存后立即生效 | 后续复核使用新 prompt |
| R6 | 标签管理列表 | 系统标签置顶 + 置灰编辑/删除 |
| R7 | 调试平台 `ModelDebug.vue` 跑通任意模型 | 不报错，UI 正常显示 `accepted, count, message` toast |
| R8 | 人工复核 `ArtificialReview.vue` 批量复核 | 不报错，UI 正常显示 toast |

---

## 7. 已知小问题 / 后续 TODO

1. **callbackUrl 暂未实现真实回调发送**：pipeline / pipeline-batch 走完只会日志 `TODO: callback`，不会 HTTP POST 给对接方。等对方给地址再加。
2. **本地模型 `qwen3-vl-4b-local` 不走 json_schema**：本地服务按原 markdown 围栏解析。
3. **pipeline 同步超时风险**：`/vfm-verify/pipeline` 单条同步，长时间跑（>30s）可能被前端超时。如有大批量单条调用需求，改用 `/vfm-verify/pipeline-batch`。

---

## 8. 测试环境准备 checklist

- [ ] SQL 已执行（见 §0）
- [ ] `ali-store-api` 服务已重启（看 seed 日志）
- [ ] `storehub-web` 前端 `yarn dev` 已启动
- [ ] 阿里云 `ALIYUN_API_KEY` 已配置（测试环境用值即可）
- [ ] 至少准备 3 条不同 `checkCode` 的样本（用于验证 prompt 4 级 fallback）
- [ ] 至少准备 1 张测试图片 URL（公网可访问）

---

## 9. 测试结果记录模板

```
测试人：________   测试日期：________   测试环境：test
□ T1.1  □ T1.2  □ T1.3  □ T1.4  □ T1.5
□ T2.1  □ T2.2
□ T3.1  □ T3.2  □ T3.3
□ T4.1  □ T4.2  □ T4.3  □ T4.4
□ T5.1  □ T5.2  □ T5.3
□ R1 ~ R8

发现问题：
1. ________________________
2. ________________________
```

---

> 文档结束
