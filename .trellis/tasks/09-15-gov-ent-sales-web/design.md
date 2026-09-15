# Design — 政企销售额明细 web 页面

## 1. 边界与涉及仓库

| 仓库 | 变更 | 说明 |
| --- | --- | --- |
| `storehub-servless` | 新增 `src/home/sacAgencySaleSummary.post.ts`（+ 可选 `.doc.ts`）；按需补齐 `sacAgencySaleTransDtl.post.ts` | 数仓转发层，对外暴露 `POST /home/<action>` |
| `storehub-web` | 新增 `src/api/modules/govEntSales.ts`；重写 `src/views/homeDetails/govEntSales/index.vue`；修正 `src/components/homeDetailsCom/index.vue` | API 层 + 页面 |

不改动：`storehub-uniapp`（透传已具备）、`ai-store-api`。

## 2. 契约

### 2.1 Serverless（对外 URL 与文件路径必须一致）

| 文件 | URL | 上游 |
| --- | --- | --- |
| `src/home/sacAgencySaleSummary.post.ts` | `POST /home/sacAgencySaleSummary` | `apis.dataLink.post('/disp/api/v1/storesmart/store/sacAgencySaleSummary', body)` |
| `src/home/sacAgencySaleTransDtl.post.ts`（已存在） | `POST /home/sacAgencySaleTransDtl` | `apis.dataLink.post('/disp/api/v1/storesmart/store/sacAgencySaleTransDtl', body)` |

- `dataLink` 已在 `src/api/env-config/dataLink.ts` 配好：`resSuccessCode=20000` / `resCodeKey='code'` / `resDataKey='content'` / `resMessageKey='message'`，`httpService` 成功后返回 `content`；`setup.ts` transformer 再包成 `{ ...result, code: 0, data: result?.data }`。
  → 因此 sl 的最终响应体为 `{ code: 0, data: <数仓 content> }`，web 侧只需读 `data`。
- 参照 `getHotSaleSingle.post.ts` 的完整范式决定是否补 `.doc.ts`（Body/Response 校验模型 + `permission`）。**本任务倾向与已有 `sacAgencySaleTransDtl.post.ts` 保持极简一致**（不加 `permission`，因为数仓接口本身无用户级权限校验需求）；若上游要求校验再补 `.doc.ts`。

Request（两接口共有，明细多 `pageNum`/`pageSize`）：

```ts
interface BaseBody {
  queryType?: number;   // 0按日 1按周 2按月 3按年 4自定义
  beginTime?: string;   // yyyy-MM-dd
  endTime?: string;     // yyyy-MM-dd
  orgType: number;      // 1区域 2片区 3门店（必填）
  orgCodes: string[];   // 必填
}
// Summary 额外：dataType?: number (1店日均 2累计)
// TransDtl 额外：pageNum?: number; pageSize?: number
```

Response（web 侧拿到的形态）：

```ts
// /home/sacAgencySaleSummary
{ code: 0, data: { saleAmt: number; gustCnt: number; syncTime: string } }

// /home/sacAgencySaleTransDtl
{ code: 0, data: {
  syncTime: string;
  detail: TransDtlRow[];
  orgCode: string; orgName: string;
  totalSaleAmt: number; storeSaleAmt: number; agencySaleAmt: number;
  page: number; size: number; pages: number; total: number;
  first: boolean; last: boolean;
} }
```

### 2.2 web API 层

新增 `storehub-web/src/api/modules/govEntSales.ts`（`import.meta.glob` 自动聚合为 `modules.govEntSales`）：

```ts
import http from '@/api/http';

export const sacAgencySaleSummary = (params: Record<string, unknown> = {}): Promise<unknown> =>
  http.post('/home/sacAgencySaleSummary', params);

export const sacAgencySaleTransDtl = (params: Record<string, unknown> = {}): Promise<unknown> =>
  http.post('/home/sacAgencySaleTransDtl', params);
```

- `http.ts` 请求拦截：注入 `x-qwmp-token` / `x-position-type`，`handleEmptyParams` 自动剔除 `undefined/null/''`（`beginTime` 非自定义时可不传）。
- 响应拦截：`code===0` 返回 `{...data, code}`，故页面 `await sacAgencySaleSummary(...)` 直接得到 `{ saleAmt, gustCnt, syncTime, code }`。

## 3. 数据流

```
小程序 saleData.vue
  → toWebViewPath({ path: '/homeDetails/govEntSales',
                    query: { timeAllData, roleType, orgType, orgCodes } })   // 逐项 encodeURIComponent
  → web route.query
      ├─ timeAllData → JSON.parse(smartDecodeURI(raw)) → TimeAllData      （HomeDetailsCom 已实现）
      ├─ orgType    → Number(smartDecodeURI(query.orgType))
      └─ orgCodes   → JSON.parse(smartDecodeURI(query.orgCodes))          （数组）
  → buildQuery()：{ ...apiTimeParams(queryType/beginTime/endTime), orgType, orgCodes, dataType }
      ├─ 概览  POST /home/sacAgencySaleSummary   → saleAmt / gustCnt / syncTime
      └─ 明细  POST /home/sacAgencySaleTransDtl → detail[] / total / pages ...（分页）
  → 渲染：汇总卡 + 「截止M月D日」+ 明细表（van-list 滚动加载）
```

`dataType` 链路：`AverageTotalToggle` `onMounted` → `getUserSet().averageOrTotal` → `resolveDefault()` → `emit('update:modelValue', value)` → `HomeDetailsCom.dataType` → `watch` 后 `emit('params-change', { timeAllData, dataType })` → 页面用于概览接口（映射为接口口径 `1-店日均 / 2-累计`）。

## 4. 关键设计决策与权衡

### 4.1 `AverageTotalToggle` 的 `v-if` 修正（必须）

现状：`<AverageTotalToggle v-model="dataType" ... v-if="isAverageTotalToggle" />`。
问题：本页 `isAverageTotalToggle=false` → 组件不挂载 → `onMounted` 不执行 → `dataType` 停留在 `ref(3)` 硬编码值，概览接口拿不到用户设置的初始值。

方案（保持组件单行、改动最小）：始终渲染组件、由组件自身隐藏 UI。

- 把 `v-if="isAverageTotalToggle"` 从组件上移到组件**内部的可见性判断**：给 `AverageTotalToggle` 增加 `hideSwitch`（或 `showSwitch`）prop，`visible = computed(() => showSwitch && !(realRole === 'm' && timeType === 'day'))`。
- `HomeDetailsCom` 传 `:show-switch="isAverageTotalToggle"`，`onMounted` 照常执行并 `emit` 初始值，只是 `van-dropdown-menu` 不渲染。

> 备选：在 `HomeDetailsCom` 里用 `v-show`/CSS 隐藏。但 `v-show` 仍会渲染 DOM 且 Vant 可能产生布局占位，且语义不如 prop 清晰。采用 prop 方案。

### 4.2 隐藏 UI 时的初始值来源

仍由 `AverageTotalToggle.resolveDefault()` 决定（依赖 `store.userCurrentRole.dateRange` + `getUserSet().averageOrTotal`），页面不重复推导，避免两处逻辑漂移。

### 4.3 日期与查询参数（实施时修正）

- 页面不自建日历，复用 `HomeDetailsCom` 的 `CalendarV2`。**原方案「默认插槽 scoped 参数 + 页面 `watch`」经实施验证不可行**：slot scoped props 在页面 `<script setup>` 中是渲染期临时值，无法被 `watch` 捕获。
- 实际方案：`HomeDetailsCom` 内部 `watch([() => timeAllData.value?.apiTimeParams, dataType], { deep: true, immediate: true, flush: 'post' })` → `emit('params-change', { timeAllData, dataType })`；页面监听该事件。
  - 加 `dataTypeReady` 守卫：`AverageTotalToggle` 在 `onMounted` 中异步取 `getUserSet()` 后才给出真实默认值，就绪前不抛事件，避免用占位值发起错误请求。
  - 页面侧以 `JSON.stringify([apiTimeParams, dataType])` 作签名去重（日历初始化回填 + Toggle 就绪可能各 emit 一次）。
- 页面收到事件后重置分页为 1、清空列表、并发请求概览 + 明细首页；另用 `requestSeq` 序号守卫丢弃参数变化后的过期响应。
- 明细「加载更多」只追加，不改 `pageNum` 以外的参数。

### 4.4 表格结构

设计稿为「表头一行 + 每行两行文本（订单号 / 门店名）」，用 CSS Grid 或 flex 行实现而非 `<table>`，便于移动端自适应与 `van-list` 拼接：

```
[订单号 (+⇅)  |  销售金额  |  门店营业款  |  政企销售额]
[orderNo                       totalSaleAmt  storeSaleAmt  agencySaleAmt]
[门店名（小字、次要色）]
```

- `⇅` 仅为静态样式（Out of Scope 已说明不做排序）。

### 4.5 金额与时间格式化

- 金额：`toFixed(2)`，汇总区保留两位小数（`¥818.22`）。
- `syncTime` → 「截止M月D日」：`dayjs(syncTime).format('M月D日')`，注意 `syncTime` 可能是 `YYYY-MM-DD HH:mm:ss` 或时间戳，实现需做容错（非法值时不显示或回退原文）。

### 4.6 兼容性与回滚

- 纯新增 sl 文件 + web 新增模块，不改老接口 → 回滚只需还原页面文件与 `homeDetailsCom`（或 revert 提交）。
- `sacAgencySaleTransDtl.post.ts` 若补齐 `.doc.ts`，需确认 `enableBodyValidate`（`setup.ts` 已开启）不会因字段缺失导致 400 —— 优先保持极简、不引入校验。

## 5. 未决点

1. `detail[]` 每行字段名：文档未标注层级，暂定 `orderNo` / `totalSaleAmt` / `storeSaleAmt` / `agencySaleAmt`，门店名可能为 `orgName` 或 `storeName`。**实现时先按假设写，联调 phase 用 curl 真实响应校正。**
2. `/home/sacAgencySaleSummary` 是否需要 `permission`：倾向不需要；若上游/网关要求，参照 `getHotSaleSingle.post.ts` 补 `dataLinkPermissionChecker`。
3. `queryType=3`（按年）：web `calendar-v2/types.ts` 的 `ApiTimeParams.queryType` 类型为 `0|1|2|4`，不含 3。若日历可能产出 3，需要在本页做类型断言/映射；否则忽略。
