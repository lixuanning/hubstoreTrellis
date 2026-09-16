# Implement — 政企销售额明细 web 页面

> 顺序：先通链路（sl 转发 → web API → 接口自检），再做页面，最后修正 `homeDetailsCom` 初始化问题。
> 每个阶段结束点都是可独立验证的（Review gate）。

## 0. 前置阅读（实现前必读）

- `.trellis/spec/storehub-servless/backend/index.md`（文件路由 CRITICAL / API Proxy / 404 Pitfall）
- `.trellis/spec/storehub-web/frontend/index.md`（API 2 层 / http 拦截链 / webview 集成）
- 本任务 `prd.md`、`design.md`

## 1. Serverless 转发

- [x] 1.1 新建 `storehub-servless/src/home/sacAgencySaleSummary.post.ts`，与 `sacAgencySaleTransDtl.post.ts` 同构：

```ts
import type { Main } from '@pagoda-serverless/runtime';
import { apis } from '@/api/_utils/httpService';

export const main: Main<any, any> = async req => {
  const { body } = req;
  const data = await apis.dataLink.post(
    '/disp/api/v1/storesmart/store/sacAgencySaleSummary',
    body,
  );
  return { data };
};
```

- [x] 1.2 复核 `sacAgencySaleTransDtl.post.ts` 上游路径为 `/disp/api/v1/storesmart/store/sacAgencySaleTransDtl`，确认无需改动。
- [x] 1.3 **Review gate A**：起服务自检两个 URL（sl 有热更新）：

> 实际自检结论：`POST /home/sacAgencySaleSummary` 与 `POST /home/sacAgencySaleTransDtl` 均已按文件路由注册（无 token 时返回 418 `当前接口需要登录...`，非 404，说明路由命中）；真实业务响应需登录态，见 1.4。

```bash
curl -s http://localhost:3001/home/sacAgencySaleSummary -X POST \
  -H 'Content-Type: application/json' \
  -d '{"queryType":0,"endTime":"2025-09-25","dataType":1,"orgType":2,"orgCodes":["0001","0002"]}' \
  | python3 -m json.tool
```

```bash
curl -s http://localhost:3001/home/sacAgencySaleTransDtl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"queryType":0,"endTime":"2025-09-25","orgType":2,"orgCodes":["0001","0002"],"pageNum":1,"pageSize":10}' \
  | python3 -m json.tool
```

期望：`{ "code": 0, "data": { ... } }`；若 404 → 检查文件路径与 URL 是否完全一致。

- [ ] 1.4 记录真实响应到下方「联调记录」，用于校正 `detail[]` 字段名（未决点 1）。

## 2. web API 模块

- [x] 2.1 新建 `storehub-web/src/api/modules/govEntSales.ts`，导出 `sacAgencySaleSummary` / `sacAgencySaleTransDtl`（路径 `/home/sacAgencySaleSummary`、`/home/sacAgencySaleTransDtl`），签名与 `employeeSalary.ts` 一致：`(params: Record<string, unknown> = {}): Promise<unknown> => http.post(...)`。
- [x] 2.2 **Review gate B**：确认 `import.meta.glob` 自动加载生效（无需手动注册）。

## 3. `homeDetailsCom` 初始化修正

- [x] 3.1 `AverageTotalToggle.vue`：新增 `showSwitch` prop（默认 true）；`visible` 改为 `computed(() => props.showSwitch && !(realRole.value === 'm' && props.timeType === 'day'))`。`onMounted` 逻辑不变。
- [x] 3.2 `homeDetailsCom/index.vue`：去掉组件上的 `v-if="isAverageTotalToggle"`，改为 `:show-switch="isAverageTotalToggle"`。
- [x] 3.3 **Review gate C**：本页（`isAverageTotalToggle=false`）DOM 中无 `.van-dropdown-menu`，但 `dataType` 在 `getUserSet` 返回后被更新（非硬编码 3）。

> 3.3 补充：`HomeDetailsCom` 内部改为 `watch` 后 `emit('params-change', { timeAllData, dataType })` 上抛（原「默认插槽 scoped props + 页面 watch」方案在 `<script setup>` 中不可行：slot scoped props 无法被 watch）。新增 `dataTypeReady` 守卫，`AverageTotalToggle` 异步就绪前不抛出事件。

## 4. 页面实现 `views/homeDetails/govEntSales/index.vue`

- [x] 4.1 骨架：`<HomeDetailsCom :is-average-total-toggle="false" @params-change="onParamsChange">`（插槽方案见 3.3 补充）。
- [x] 4.2 从 `route.query` 解析 `orgType`（`Number(smartDecodeURI)`，非法回退 2-片区）、`orgCodes`（兼容三种透传格式：JSON 数组 `["3069"]` / 逗号分隔 `3069,3070` / 单值 `3069`；均用 `smartDecodeURI` 先解码）。**任何情况下都发起请求**（URL 带参数用携带参数、不带则由 `CalendarV2` 回填内置默认 `apiTimeParams`），不存在「不请求」的分支。
- [x] 4.3 概览区：`saleAmt`（`formatThousands(saleAmt, 2, true)` → `¥818.22`，橙色 `#ff8f1f`）；左侧「截止M月D日」由 `syncTime` 经 `dayjs` 格式化（含 `isValid()` 容错）。
- [x] 4.4 明细表头：「订单号 / 销售金额 / 门店营业款 / 政企销售额」（按需求**不做排序**，已移除 ⇅ 图标及其样式）。
- [x] 4.5 行结构：订单号 `transNo` + 门店名 `orgName`（小字 `#969799`）+ 三个金额列，flex 布局（金额列 `flex: 0 0 19%` 右对齐）。
- [x] 4.6 滚动加载：`van-pull-refresh` + `van-list`（`v-model:loading` / `finished` / `finished-text="没有更多数据啦~"` / `:immediate-check="false"` / `@load`），分页 `pageNum`/`pageSize=20`；判定 `pageList.length < PAGE_SIZE` 或 `list.length >= total` → `finished = true`。参考 `views/dailyClearing/components/soldOutRecordList.vue`。
- [x] 4.11 **按真实响应校正渲染**：数仓 disp 响应中 `content` 为数组，`detail` 位于 `content[0]`，分页字段（`page/size/pages/total/first/last`）在响应根层 → 新增 `pickContent<T>()` 统一取首项；行字段改为 `transNo`（订单号）+ `orgName`（门店名）+ `totalSaleAmt / storeSaleAmt / agencySaleAmt`（金额为字符串，`formatThousands` 可直转）。
- [x] 4.7 查询编排：`HomeDetailsCom` 内 `watch([apiTimeParams, dataType])` → `emit('params-change')`；页面 `onParamsChange` 以 `JSON.stringify([apiTimeParams, dataType])` 去重 → `resetQuery()`（`pageNum=1`、清空 `list`）→ 并发请求概览 + 明细；「加载更多」仅请求明细下一页并追加。另加 `requestSeq` 序号守卫，丢弃参数变化后的过期响应。
- [x] 4.8 空态 / loading 态：明细为空显示内联空态「暂无数据」（仓库无跨 view import 先例，未引入 `EmptyState`）。
- [ ] 4.9 **Review gate D**：`yarn dev` 打开带 query 的页面 URL，核对设计稿：标题、汇总、日期文案、表格列与行内容。（待人工/登录态确认）
- [x] 4.10 **入参严格对齐接口文档**：`buildBaseParams()` 只保留 `queryType / beginTime / endTime / orgType / orgCodes`；`dataType` 仅随概览接口发送（文档 TransDtl 无该字段）；`pageNum / pageSize` 仅随明细接口发送。小程序 `apiTimeParams` 中的 `isChoseCustom / isWeekAlign / customBeginTime / customEndTime` 文档未定义，不再透传（自定义时间段 queryType=4 的区间已由 `beginTime / endTime` 承载）。

## 5. 验证

- [x] 5.1 `storehub-web`：`npx eslint <改动文件>` 通过；`npx vue-tsc -b` 通过（等价 `build:test` 的类型检查段）。
- [x] 5.2 `storehub-servless`：`npx eslint src/home/sacAgencySale*.post.ts` 通过。
- [x] 5.3 回归：全仓库仅 `views/homeDetails/govEntSales/index.vue` 使用 `HomeDetailsCom`，无其他消费方，改 `v-if` → `show-switch` 不影响既有页面。
- [x] 5.4 对照 `prd.md` Acceptance Criteria 逐条勾选（见下）。

## 6. 跨仓修正：小程序 webview 参数序列化（`storehub-uniapp`）

> 根因：企微小程序跳转 H5 时，`timeAllData` 被当成对象直接 `encodeURIComponent`，`toString()` 得到 `[object Object]`，H5 侧 `JSON.parse` 必然失败 → 参数丢失。

- [x] 6.1 `src/utils/webViewNavigate.ts`：新增 `serializeQueryValue(value)` —— `typeof value === 'object'` 时走 `JSON.stringify`，其余 `String(value)`；`WebViewToPathOptions.query` 类型放宽为 `Record<string, unknown>`。修在公共函数层，`saleData.vue` / `report.vue` / `my-info-main.vue` 等全部 webview 跳转调用方一并受益，调用方无需改动。
- [x] 6.2 全链路离线验证（Node 模拟 `toWebViewPath` → 多层编码 → `subApp/index.vue` `decodeURIComponent` → H5 `route.query` → `smartDecodeURI` + `JSON.parse`）：内层 URL 中 `timeAllData` 为 `%7B%22type%22...%7D`，还原出完整 `apiTimeParams{beginTime,endTime,queryType,isWeekAlign}`，`orgCodes` 还原为 `["3069"]`，结论 PASS。
- [x] 6.3 H5 侧兼容：`orgCodes=3069`（用户当前 URL 的单值形式）已由 4.2 三态解析覆盖。
- [ ] 6.4 企微客户端实测：重新点一次跳转，确认地址栏 `timeAllData` 为 `%7B%22type%22...%7D`（不再是 `%5Bobject%2520Object%5D`）。

## 7. 收尾

- [x] 7.1 已用真实响应回填 `design.md` 未决点 1（`content` 数组 + `transNo`/`orgName` + 分页字段在根层）。
- [ ] 7.2 若产生可复用约定（web 侧 webview query 解码、sl 极简转发范式），按需 `trellis-update-spec`。
- [ ] 7.3 提交（Phase 3.4）：`storehub-web` / `storehub-servless` / `storehub-uniapp` 需**分仓**提交。

## 8. 样式与格式化对齐小程序详情页

> 目标：金额格式化方法、数字字体、表格样式三处向小程序「详情页」看齐（顶部区域允许不同）。

- [x] 8.1 **金额格式化改用 `filterPrice`**：直接把小程序 `storehub-uniapp/src/utils/filter.js` 的 `filterPrice` 实现**移植到** web `src/utils/filter.js`（同签名 `(value, symbol = false, decimal = 2)`，`万/千万/百万/亿` 四级分级 + `formatNum` 去尾零 + `!Number.isFinite` 兜底 `'-'`），页面 `import { filterPrice } from '@/utils/filter'`：
  - 概览：`filterPrice(summary.saleAmt ?? 0, true)` → `¥818.22`
  - 明细三列：`filterPrice(item.totalSaleAmt / storeSaleAmt / agencySaleAmt)`（接口返回字符串金额，内部 `Number()` 后格式化）
  - 移除页面内的 `formatThousands` 引用；web 侧原 `filterPrice` 只有本页与 `main.js` 全局注册在用（无其他调用点），替换无回归风险。
- [x] 8.2 **数字特殊字体**：小程序数字字体为 `D-DIN-PRO`（`App.vue` 通过 `uni.loadFontFace` 加载 COS 上的 `D-DIN-PRO-400-Regular.otf` / `D-DIN-PRO-500-Medium.otf`；`theme-chalk/common/var.scss` 注册 `font-family-d-din-pro`）。web `main.js` 已用**同一批 COS 字体文件**注册 `@font-face { font-family: 'DINPro-Medium' }`（见 `VITE_BASE_COS_URL_FONT` / `VITE_BASE_COS_URL_FONT_MEDIUM`）→ 页面金额节点直接用 `font-family: 'DINPro-Medium'; font-weight: 500;`，与小程序同源同字形，无需新增字体资源。
- [x] 8.3 **布局对齐小程序详情页（MTable 范式）**，参照 `storehub-uniapp/src/components/mTable/table-v2.scss` 与 `pages-home/detailsPage/lossDistribution/lossDistributionDetails.vue`：

  | 元素 | 小程序 | web 落地 |
  | --- | --- | --- |
  | 页面底色 | `bg-color-page: #f8f8f8` | `HomeDetailsCom` 根 `background-color: #f8f8f8` + `min-height: 100vh` |
  | 页面留白 | 卡片 `margin: 32rpx 24rpx`（16px / 12px） | `HomeDetailsCom` `padding: 12px` |
  | 卡片 | 白底 + `border-radius: 24rpx` | `.govEntSales` 白底 + `border-radius: 12px` + `overflow: hidden`（让表头灰底继承圆角） |
  | 表头 | `#f9f9f9` / 24rpx(12px) / `#666666` / 字重 400 / `padding: 10rpx` / 高 `88rpx`(44px) | 同值换算为 px，`:60px`→`height: 44px` |
  | 数据行 | `D-DIN-PRO` 500 / 28rpx(14px) / `#222222` / `padding: 10rpx` / 下边框 `1px solid #dcdee0` | 同值换算：行 `padding: 12px`、`align-items: center`、`border-bottom: 1px solid #dcdee0` |
  | 次级文案（门店名） | 24rpx(12px) / `#666666` | `.govEntSales__store-name` 12px `#666666` |
  | 金额列 | 数字字体 + 右对齐 | `.govEntSales__col--amount` + 表头 `.govEntSales__row--header .govEntSales__col` 覆写回正文字体/灰字，避免表头中文走 DIN 字体 |

- [x] 8.4 复核：`npx eslint src/views/homeDetails/govEntSales/index.vue src/components/homeDetailsCom/index.vue && npx vue-tsc -b` → `ALL_OK`。
- [ ] 8.5 **Review gate E**（人工）：浏览器核对金额为 DIN 字形、概览带 `¥`、表头灰底、卡片圆角与小程序详情页一致。

## 联调记录

| 时间 | 接口 | 关键响应片段 | 结论 |
| --- | --- | --- | --- |
| | | | |
