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
- [x] 4.2 从 `route.query` 解析 `orgType`（`Number(smartDecodeURI)`，非法回退 2-片区）、`orgCodes`（`JSON.parse(smartDecodeURI)`，非数组回退 `[]`）；`orgCodes` 为空时直接空态、不发请求。
- [x] 4.3 概览区：`saleAmt`（`formatThousands(saleAmt, 2, true)` → `¥818.22`，橙色 `#ff8f1f`）；左侧「截止M月D日」由 `syncTime` 经 `dayjs` 格式化（含 `isValid()` 容错）。
- [x] 4.4 明细表头：「订单号 ⇅ / 销售金额 / 门店营业款 / 政企销售额」（⇅ 为纯文本静态样式，不绑定排序）。
- [x] 4.5 行结构：订单号 + 门店名（`storeName || orgName`，小字 `#969799`）+ 三个金额列，flex 布局（金额列 `flex: 0 0 19%` 右对齐）。
- [x] 4.6 滚动加载：`van-pull-refresh` + `van-list`（`v-model:loading` / `finished` / `finished-text="没有更多数据啦~"` / `:immediate-check="false"` / `@load`），分页 `pageNum`/`pageSize=10`；判定 `pageList.length < PAGE_SIZE` 或 `list.length >= total` → `finished = true`。参考 `views/dailyClearing/components/soldOutRecordList.vue`。
- [x] 4.7 查询编排：`HomeDetailsCom` 内 `watch([apiTimeParams, dataType])` → `emit('params-change')`；页面 `onParamsChange` 以 `JSON.stringify([apiTimeParams, dataType])` 去重 → `resetQuery()`（`pageNum=1`、清空 `list`）→ 并发请求概览 + 明细；「加载更多」仅请求明细下一页并追加。另加 `requestSeq` 序号守卫，丢弃参数变化后的过期响应。
- [x] 4.8 空态 / loading 态：明细为空显示内联空态「暂无数据」（仓库无跨 view import 先例，未引入 `EmptyState`）。
- [ ] 4.9 **Review gate D**：`yarn dev` 打开带 query 的页面 URL，核对设计稿：标题、汇总、日期文案、表格列与行内容。（待人工/登录态确认）

## 5. 验证

- [x] 5.1 `storehub-web`：`npx eslint <改动文件>` 通过；`npx vue-tsc -b` 通过（等价 `build:test` 的类型检查段）。
- [x] 5.2 `storehub-servless`：`npx eslint src/home/sacAgencySale*.post.ts` 通过。
- [x] 5.3 回归：全仓库仅 `views/homeDetails/govEntSales/index.vue` 使用 `HomeDetailsCom`，无其他消费方，改 `v-if` → `show-switch` 不影响既有页面。
- [x] 5.4 对照 `prd.md` Acceptance Criteria 逐条勾选（见下）。

## 6. 收尾

- [ ] 6.1 若确认了 `detail[]` 真实字段，回填 `design.md` 未决点 1。
- [ ] 6.2 若产生可复用约定（web 侧 webview query 解码、sl 极简转发范式），按需 `trellis-update-spec`。
- [ ] 6.3 提交（Phase 3.4）。

## 联调记录

| 时间 | 接口 | 关键响应片段 | 结论 |
| --- | --- | --- | --- |
| | | | |
