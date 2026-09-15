# 政企销售额明细 web 页面（含 serverless 两个接口转发）

## Goal

在 `storehub-web` 实现「政企销售额明细」页面（`/homeDetails/govEntSales`），供小程序通过 webview 打开。
页面数据来自数仓两个接口，需在 `storehub-servless` 新增/补齐转发，web 端通过 sl 域名调用。

## Background

- 页面由小程序 `pages-home` 的「销售额(政企)」卡片跳转进入，跳转时通过 `toWebViewPath` 透传 `timeAllData` / `roleType` / `orgType` / `orgCodes`。
- 数仓接口（`{{url}}v1/storesmart/store/...`）不能由 web 直连，必须经 `storehub-servless`（dataLink）转发。
- 已有样板：`storehub-servless/src/home/sacAgencySaleTransDtl.post.ts`（明细转发，仅 20 行）。
- 接口入参风格与小程序 home 一致（`queryType` / `beginTime` / `endTime` / `orgType` / `orgCodes` / `dataType`）。

## Requirements

### 功能

1. **页面骨架**：复用 `HomeDetailsCom` 容器（提供日历 `CalendarV2` + `timeAllData` 业务对象 + 默认插槽 scoped `data-type`），页面标题「政企销售额明细」。
2. **接口转发（serverless）**：两个接口都提供 sl 转发，URL 与文件路径严格一致：
   - `POST /home/sacAgencySaleSummary` → `/disp/api/v1/storesmart/store/sacAgencySaleSummary`（**需新建**）
   - `POST /home/sacAgencySaleTransDtl` → `/disp/api/v1/storesmart/store/sacAgencySaleTransDtl`（**已存在**，按需补齐模型/权限）
3. **汇总区**：展示概览接口 `saleAmt`（销售额(政企)，橙色强调）、`gustCnt`（来客数/订单数）。
4. **日期文案**：左侧「截止M月D日」取**概览接口 `syncTime`**（非本地时间）。
5. **日期切换**：使用 `HomeDetailsCom` 内 `CalendarV2` 的 `timeAllData.apiTimeParams` 驱动查询（`queryType` / `beginTime` / `endTime`）。
6. **小票明细表格**：列固定为「订单号 / 销售金额 / 门店营业款 / 政企销售额」；订单号单元格下方显示门店名。
7. **滚动加载更多**：明细列表分页（`pageNum` / `pageSize`），触底加载下一页，加载完显示「没有更多数据啦~」。
8. **不做排序**：表头排序图标仅样式，不实现排序交互。

### 入参来源

| 接口字段 | 来源 |
| --- | --- |
| `queryType` | `timeAllData.apiTimeParams.queryType`（0按日/1按周/2按月/3按年/4自定义） |
| `beginTime` | `timeAllData.apiTimeParams.beginTime`（自定义时启用） |
| `endTime` | `timeAllData.apiTimeParams.endTime` |
| `orgType` | webview query `orgType`（1区域/2片区/3门店，**必填**） |
| `orgCodes` | webview query `orgCodes`（数组，**必填**） |
| `dataType` | 仅概览接口需要；取 `getUserSet().averageOrTotal` 推导的初始值（1店日均/2累计），**由 `AverageTotalToggle` 初始化逻辑提供** |
| `pageNum` / `pageSize` | 仅明细接口；分页状态 |

### 约束

1. query 值来自 `toWebViewPath` 的逐项 `encodeURIComponent`，web 侧必须用 `smartDecodeURI` 解码（`timeAllData` 为 JSON 字符串需 `JSON.parse`）。
2. **不展示「日均/累计」切换 UI，但仍必须获取并使用接口查询到的初始默认值**。当前 `homeDetailsCom/index.vue` 用 `v-if="isAverageTotalToggle"` 控制 `AverageTotalToggle`，会导致组件不挂载、`onMounted` 不执行、拿不到初始值 —— 必须修正为「隐藏 UI 但仍完成初始化」。
3. 遵循 web 端 2 层 API 模式（`src/api/modules/*.ts` + `http.ts` 拦截器），不在页面直接调 axios。
4. 保持项目现有代码风格（Vue3 `<script setup>` + TS、Vant 4、less），避免 `any`。
5. 三端 URL 路径字符串必须完全一致，避免 serverless 404。

## Out of Scope

- 「日均/累计」切换 UI 的展示（本页不展示）。
- 表头排序功能。
- 小程序侧页面改造（透传已具备，仅消费）。

## Acceptance Criteria

> 状态：代码层面已全部落地；`curl` 与页面渲染两项需**登录态**才能拿到真实业务响应，尚未验证（见 `implement.md` 联调记录）。

- [ ] `curl -s http://localhost:3001/home/sacAgencySaleSummary -X POST -H 'Content-Type: application/json' -d '{...}'` 返回 `{ "code": 0, "data": {...} }`（含 `saleAmt`/`gustCnt`/`syncTime`）。—— 路由已验证命中（非 404）；无 token 时返回 418 登录提示，待登录态复验。
- [ ] `curl` 同一方式校验 `/home/sacAgencySaleTransDtl` 返回 `{ "code": 0, "data": { "detail": [...], ... } }`。—— 同上。
- [ ] 打开 `/homeDetails/govEntSales?timeAllData=...&orgType=...&orgCodes=...` 页面能渲染标题、汇总区、日期文案、表格。—— 待人工确认（Review gate D）。
- [ ] 「截止M月D日」文案与概览接口 `syncTime` 一致。—— 已按 `dayjs(syncTime).format('M月D日')` 实现，待联调复验。
- [ ] 切换日历日期后，两个接口按新 `apiTimeParams` 重新请求，页面数据同步刷新。—— 已实现（`params-change` + 签名去重 + `resetQuery` 并发请求）。
- [ ] 明细列表滚动到底部自动加载下一页，数据用尽后显示「没有更多数据啦~」。—— 已实现（`van-list` + `finished-text` + `pageSize=10`）。
- [ ] 页面不出现「日均/累计」下拉；但概览请求携带的 `dataType` 等于 `getUserSet().averageOrTotal` 推导出的初始值（≠ 硬编码 3）。—— 已实现（`show-switch=false` 仅隐藏 UI，`AverageTotalToggle.onMounted` 仍初始化 `dataType`；映射接口口径 `dataType === 3 ? 2 : 1`）。
- [x] `yarn lint` / `yarn build:test`（各仓库）无新增错误。—— `storehub-web`：`npx eslint` + `npx vue-tsc -b` 均通过；`storehub-servless`：`npx eslint` 通过。

## Notes

- 接口字段层级以 `接口文档.txt` 缩进为准：概览 `content.{saleAmt,gustCnt,syncTime}`；明细 `content.{syncTime,detail,orgCode,orgName,totalSaleAmt,storeSaleAmt,agencySaleAmt,page,size,pages,total,first,last}`。
- **未决点**：`detail[]` 数组内每行字段名文档未单独标注，实现按 `orderNo` / `totalSaleAmt` / `storeSaleAmt` / `agencySaleAmt` / 门店名（`orgName` 或 `storeName`）假定，联调时需确认并回填 `design.md`。
