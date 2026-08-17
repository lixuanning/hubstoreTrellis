# ai-store-api / storehub-servless 接口契约（vfm 模块）

> **Skill 实际调用的是 storehub-servless 网关代理路径（带鉴权头），不是 ai-store-api 原生路径**。
> - 测试环境域名：`https://storehub-servless.bgms.tencent-test.pagoda.com.cn`
> - 前端走 `web-storehub` 反向代理到 servless
> - servless 再转发到 ai-store-api
>
> 所有接口 `POST`，`Content-Type: application/json`，统一返回 `{ code, message, data: ... }`。

## 必带鉴权头

| 头 | 值 | 备注 |
|---|---|---|
| `is-new-sma-view` | `true` | |
| `x-position-type` | `jt-test` | 测试环境 |
| `x-client-platform` | `h5` | web 平台 |
| `x-client-ajax` | `1` | ajax 标识 |
| `x-qwmp-token` | `<登录token>` | 必须从浏览器复制 |
| `Cache-Control` | `no-Cache` | |
| `User-Agent` | Mozilla/5.0 Chrome | |
| `Referer` | `https://storehub-web.fea-static.tencent-test.pagoda.com.cn/` | |

> `x-qwmp-token` 是一次会话有效（约 2 小时），过期需重新从浏览器拿。

---

## 正确流程一览（模拟 web 平台 ModelDebug）

```
1. POST /aiRecognition/reviewPromptCreate    新建提示词（name=ai-<checkCode>），拿 promptId
2. POST /aiRecognition/resultList            按 checkCode 拉已复核样本（联表，含 vfmResultId / reviewResult / vfmCheckResult / aiConclusionDifferent）
3. POST /aiRecognition/reVerifyByIds         按 vfmResultId 列表重跑，指定 promptId=<新建>，覆盖写入 vfm_debug_result
4. POST /aiRecognition/resultList            再查（vfmResultId 已带最新 isValid 逻辑结果）
5. accuracy = 1 - 不同数/有效判定数
```

> **不要走 ai-store-api 原生路径** `/vfm-review-prompt/create` 等——前端走的是 servless 代理，且原生路径上有 vfm 模块未加权限校验的 dev 限制。

---

## 1. 提示词管理（servless 代理路径）

### 1.1 新建（核心）
```
POST {base_url}/aiRecognition/reviewPromptCreate
```

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `type` | string | 是 | 检查项编码（如 `"122"`） |
| `typeName` | string | 是 | 检查项名称（如 `"开切未佩戴手套"`） |
| `name` | string | 否 | 提示词名称，约定 `ai-<checkCode>` |
| `prompt` | string | 是 | 完整提示词（**必须含"二次确认语义"三段**，见 SKILL.md） |
| `enabled` | number | 否 | 0/1；新建不传（默认 0），不启用 |

**返回** `data` 为新建记录（含 `id`），**记住这个 promptId**——后续所有验证都只针对这个 id。

### 1.2 更新（迭代修改用）
```
POST {base_url}/aiRecognition/reviewPromptUpdate
body: { id: promptId, prompt: "..." }
```

只改本会话创建的那个 id，**不要动现有任何提示词**。`vfm-verify` 按 `(sampleId, promptId)` 唯一 upsert，可反复 update 提示词后重跑覆盖旧结果，**不需要新建**。

### 1.3 列表 / 详情 / 删除
- `/aiRecognition/reviewPromptList` body: `{ type, enabled }`
- `/aiRecognition/reviewPromptDetail` body: `{ id }`
- `/aiRecognition/reviewPromptRemove` body: `{ id }`

---

## 2. 联表结果查询（vfm-result）

### 2.1 resultList
```
POST {base_url}/aiRecognition/resultList
```

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `checkCode` | string | 否 | 检查项编码 |
| `reviewResult` | number | 否 | 0 未复核 / 1 是 / 2 否 / 3 待定（**只支持单值**） |
| `vfmCheckResult` | number | 否 | 0 无 / 1 是 / 2 否 / 3 待定 |
| `aiConclusionDifferent` | number | 否 | 0 一致 / 1 不一致（后端按 reviewResult≠0 且 vfmCheckResult>0 算） |
| `promptId` | string | 否 | 过滤特定提示词的结果（**字符串**） |
| `page` / `pageSize` | number | 否 | 默认 1 / 10 |

**返回** `data: { list, total }`，`list[]` 关键字段：

| 字段 | 含义 |
|---|---|
| `id` | vfm_debug_result.id（**作为 reVerifyByIds 的入参**） |
| `sampleId` | vfm_debug_sample.id |
| `sampleCode` | 样本编码 |
| `checkCode` / `checkName` / `checkImage` | 检查项 + 图片 |
| `reviewResult` | 人工标准答案：1 是 / 2 否 / 0 未复核 |
| `vfmCheckResult` | AI 判定：1 是 / 2 否 / 0 无 / 3 待定 |
| `aiConclusionDifferent` | 后端算好：0 一致 / 1 不一致 |
| `vfmCheckReason` | AI 理由 |
| `vfmCheckCredibility` | 置信度字符串 |
| `promptId` / `promptName` | 该条结果用过的提示词 |

### 2.2 计算准确率（Skill 本地算）
```
取 resultList 过滤后结果：
  有效条数 = data.total
  不同条数 = Σ aiConclusionDifferent == 1
  accuracy = (有效条数 - 不同条数) / 有效条数
```

---

## 3. 验证

### 3.1 reVerifyByIds
```
POST {base_url}/aiRecognition/reVerifyByIds
```

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `ids` | string[] | 是 | **字符串**数组（vfmResultId 列表） |
| `model` | string | 否 | 默认后端第一模型（如 `qwen3-vl-plus`） |
| `promptId` | string | 是 | **字符串**（新建的 promptId），触发按新提示词重算 |

**性能与超时**：
- 单条 ~3s，10 条 ~32s，30 条 ~60s
- 网关 60s 限制：30 条会 503，**分批跑（15 条/批）**

**返回** `data.data: VfmVerifyResponse[]`（注意是嵌套），每条：
```json
{
  "success": true,
  "result": {
    "isValid": true,         // 二次确认：true=确认违规, false=推翻
    "confidence": 0.95,
    "reason": "...",
    "errorType": "未佩戴一次性手套",
    "model": "qwen3-vl-plus",
    "duration": 2684,
    "promptTokens": 2784,
    "completionTokens": 67,
    "totalTokens": 2851
  },
  "sample": {
    "id": "20149",           // 注意：字符串
    "sampleCode": "...",
    "checkImage": "...",
    "reviewResult": 1,        // 1=违规(是), 2=合规(否)
    ...
  }
}
```

### 3.2 结论映射（**二次确认语义**）

| 人工 reviewResult | AI isValid | 一致 | 含义 |
|---|---|---|---|
| 1（违规） | true | ✅ | AI 确认本地模型违规判断 |
| 2（合规） | false | ✅ | AI 推翻本地模型违规判断 |
| 1（违规） | false | ❌ | AI 错判为合规 |
| 2（合规） | true | ❌ | AI 错判为违规 |
| 0（未复核） | 任意 | 排除 |  |
| 任意 | 失败 | 排除 | success=false |

---

## 4. 关键发现（沉淀）

### 4.1 后端 findByIds Bug
ai-store-api `vfm-verify.service.ts:598 / :844` 原代码用 `Repository.findByIds(ids, { where: { deleted: 0 } })`，TypeORM 0.2.25 上 options 形参不生效——`/vfm-verify/verify-by-ids` 和 `/vfm-verify/re-verify` 直接调用均失败。

**修复**（已并入仓库 `vfm-verify.service.ts`）：
- `verifyByIds`: `this.vfmSampleRepository.find({ where: { id: In(sampleIds), deleted: 0 } })`
- `reVerifyByIds`: `this.vfmResultRepository.createQueryBuilder('v').where('v.id IN (:...ids)', { ids }).andWhere('v.deleted = 0').getMany()`

> **但走 servless 代理的 `/aiRecognition/reVerifyByIds` 正常**——因为 web 平台正常使用，所以 servless 路径上功能完好。

### 4.2 字段类型
- vfmResultId / sampleId / promptId 字段在 DB 中是 `bigint`，前端 list/detail 返回值是**字符串**（不是数字）
- 接口入参 `ids` / `promptId` 必须传**字符串**（前端就是这样传的）
- `result.isValid` 是 **boolean**（不是 1/2），本地计算时 `isValid ? 1 : 2` 转成 vfmCheckResult 语义

### 4.3 网关超时
servless 网关响应超过 60s 会 503（"响应超时"）。30 条一次性发会触发，**必须分批 15 条/批**。前端 web 平台是分页分批触发。
