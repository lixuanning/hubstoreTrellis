# 执行计划 — timeAllData 字段输出对齐

> 前置：R1（custom 回显）已在规划期完成并验证，本阶段从其之后开始。
> 每步完成后跑验证命令；**每个提交点独立可回滚**（禁止 `--amend`）。

## 0. 准备

- [ ] 确认分支：`storehub-web`（独立 git repo，当前 `test_v2.1.12`）。
- [ ] 记录基线：`cd storehub-web && npx vue-tsc --noEmit -p tsconfig.app.json`（应退出码 0）。
- [ ] 复读基准：[research/timealldata-field-alignment.md](./research/timealldata-field-alignment.md) §1 差异表。

## 1. 单一 `day` 派生重构（R2 / R3 / R4）

- [ ] 在 `index.vue` 新增 `resolvePrimaryDay(tab)`，复刻源 L39-57 的 `day` 选择。
- [ ] 新增由 `day` 派生 `dayData/weekData/weekDisplayText/monthData/monthDisplayText/timeText(base)` 的逻辑（复刻源 L59-68 + L97-104 clamp）。
- [ ] 改造 `stringifyTimeAllData`：用新派生替换 `computeDayData/computeWeekData/computeMonthData` 的独立取值。
- [ ] date tab：`type` 由 `'date'` 改 `'day'`；`isToday = diff===0`。
- [ ] week/month/festival/custom：`isToday` 恒 `false`（移除全局计算）。
- **验证**：`npx vue-tsc --noEmit -p tsconfig.app.json` + node 脚本逐字段比对 AC2/AC3/AC4。
- **回滚点 1**：仅 `stringifyTimeAllData` 相关改动。

## 2. week tab `timeText` 对齐（R5）

- [ ] week tab `timeText` 改为 `[startDate,endDate].map(v=>dayjs(v).format('MM.DD')).join('-')`。
- **验证**：AC3（`timeText` 形如 `09.08-09.14`）。
- **回滚点 2**：独立小改。

## 3. 业务周换算对齐（R6）

- [ ] 新增 `getDateWeek(date, startOffset=4)` 复刻 `util-dayjs.ts` 的 `getWeekInfo`（周四起始）。
- [ ] `resolvePrimaryDay` 派生 `weekData/weekDisplayText` 时改用 `getDateWeek(day, 4)`。
- [ ] week tab：优先在 `weekColumns` 中按 `'YYYY-WW'` 命中 → `weekData=endDate`、`weekDisplayText=simpleLabel ?? label`。
- [ ] `businessWeekString` 与 `getYearWeekNumber` 同步改用新算法（保持一致口径）。
- **验证**：对同一日期，`businessWeekString` 与源 `getDateWeek().week` 一致；week tab 命中列表时取业务标签。
- **回滚点 3**：周算法独立，可单独 revert。
- ⚠️ **需业务确认**：web 侧 `weekRequest` 是否总能提供业务周表。

## 4. 回显链路按位解析（R7）

- [ ] `syncFromTimeAllData` L838-846：`cacheModel.custom = [cd.leftBegin ?? null, cd.leftEnd ?? null]`，`subcustom = [cd.rightBegin ?? null, cd.rightEnd ?? null]`（保留位置，不再 `.filter(Boolean)`）。
- [ ] 校验 `fillDefaultForEmptyTabs` / `switchSubTab` 对含 `null` 的 4 元素数组不误判。
- **验证**：`leftEnd` 缺失 + `rightBegin` 有值时，回显位置不漂移。
- **回滚点 4**：独立小改。

## 5. 其它缺口（R8，需业务确认后决定是否纳入）

- [ ] `next()/prev()`：评估是否补 `emitTimeAllData()`（对齐源翻页后刷新）。
- [ ] custom 缺值 `timeText/showText` 的 guard 语义评审（保留 guard 更安全，需业务确认）。

## 6. 终检（对照 AC1-AC9）

- [ ] AC1 custom 入口单值/双值/四值回显正常（无 `请选择`）。
- [ ] AC2-AC6 各 tab 输出逐字段核对（node 脚本打印 + 人工对照差异表）。
- [ ] AC7 非 custom/festival 的 `customData` 五项全 `undefined`。
- [ ] AC8 差异表 §1 中 ❌/⚠️ 项全部消除或经业务豁免并记录。
- [ ] AC9 `cd storehub-web && npx vue-tsc --noEmit -p tsconfig.app.json && npx eslint src/components/calendar-v2` 通过。

## 附：验证命令

```bash
cd /Users/lidie/a-code/a-pgy/storehub/storehub-web
npx vue-tsc --noEmit -p tsconfig.app.json
npx eslint src/components/calendar-v2
```

## 附：交付物（allowlist）

- `storehub-web/src/components/calendar-v2/index.vue`
- `storehub-web/src/components/calendar-v2/utils.ts`（仅在需要新增 `getDateWeek` 时）

**不得改动**：`types.ts`、子组件对外事件、`govEntSales/index.vue`、`storehub-uniapp/**`。
