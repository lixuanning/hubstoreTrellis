# calendar-v2 自定义回显修复 + timeAllData 字段输出对齐旧组件

## Goal

让 web 重构版 `calendar-v2` 产出的 `timeAllData` 业务对象，**逐字段**与企业微信小程序旧组件
（`storehub-uniapp` 的 `wd-calendar-v2` + `use-calendar-v2` + `defineTimeDataConfig`）的输出**完全一致**，
并修复 custom（自定义）入口回显「请选择」的 Bug。

`timeAllData` 是后续业务流转的唯一契约，字段语义偏差会直接导致下游取数错误。

## Background

- 旧组件真源：`storehub-uniapp/src/pages-home/hooks/utils.ts` 的 `defineTimeDataConfig`（L25-217）。
- web 实现：`storehub-web/src/components/calendar-v2/index.vue` 的 `stringifyTimeAllData`（L1119-1297）。
- 逐字段差异基准见 [research/timealldata-field-alignment.md](./research/timealldata-field-alignment.md)。
- 唯一消费方：`storehub-web/src/views/homeDetails/govEntSales/index.vue`（`v-model:time-all-data`）。
- 上游重构 spec：`.trellis/tasks/09-08-calendar-v2-web-refactor-v3/spec.md`。

## Requirements

### R1（已修复，纳入验收）custom 入口回显
- custom tab 入口文案在「仅选到 1 个值」「选满主选区」「主选区+对比区」时都不得回落为 `请选择`。
- 门槛对齐源 `defineCalendarDisplayFormat`：过滤非法值后 `length === 0` 才为空。

### R2（核心）次级日期字段改为围绕「当前 tab 主值 `day`」派生
对齐源结构性行为：`dayData / weekData / weekDisplayText / monthData / monthDisplayText / timeText`
全部由同一个 `day` 派生，而非分别取自各 tab 缓存。

- date tab：`day` = 选中日期。
- week tab：`day` = 今天（`dayjs()`）。
- month tab：`day` = 选中月（`values[0]`）。
- custom tab：`day` = `values[0]`（= `leftBegin`）。
- festival tab：`day` = `values[2]`（= 节中）。

### R3 `type` 字段值对齐
- date tab 输出 `type: 'day'`（当前错误输出 `'date'`）。
- week/month/custom 保持 `'week'`/`'month'`/`'custom'`；festival 归一 `'custom'`。

### R4 `isToday` 语义对齐
- 仅 date tab 可能为 `true`（`diff === 0`）；week/month/festival/custom 恒 `false`。

### R5 `timeText` 对齐
- week tab 输出 `MM.DD-MM.DD`（旧组件为连字符，非 `YYYY年第NN周`）。
- date=`MM-DD`；month=`YYYY年MM月`；custom/festival=`MM.DD~MM.DD`。

### R6 业务周换算对齐（**已确认纳入本次实现**）
- 对齐源 `getDateWeek(..., offsetWeek=4)` 的业务周算法（周四起始 / ISO 口径）。
- week tab 若命中业务周表，`weekData/weekDisplayText/timeText` 采用业务周返回值。

### R7 回显链路按位解析
- `syncFromTimeAllData` 解析 `customData` → `custom/subcustom` 时保留数组位置语义（禁用 `.filter(Boolean)` 造成的错位）。

### R8 其它已识别缺口（**已确认：补 emit + 保留 guard**）
- `next()/prev()` 翻页后**需**同步 emit `update:timeAllData`（对齐源 `setValue` 行为）。
- custom 缺值场景保留有效性 guard，不产出 `Invalid Date` 脏值（不逐字节复刻源的无 guard 行为）。

## Constraints

- 不改动 `timeAllData` 的字段名与类型（`types.ts` 的 `TimeAllData`）。
- `apiTimeParams` 的 `queryType/isChoseCustom/isWeekAlign` 语义不得变更（已一致）。
- 不改动 festival 已通过验收的回显与输出。
- 仅在 `storehub-web/src/components/calendar-v2/` 内改动。
- 不引入新依赖；沿用 dayjs / lodash-es。

## Acceptance Criteria

- [ ] **AC1** custom 入口在单值/双值/四值场景均正确回显（不出现 `请选择`）。
- [ ] **AC2** date tab：选 `YYYY-MM-DD` 后 `dayData=该日`、`weekData=该日所在业务周结束日`、`monthData=该日所在月最后一天`、`monthDisplayText=该月`、`timeText=MM-DD`、`type='day'`、`isToday` 按 `diff===0`。
- [ ] **AC3** week tab：`dayData=今天`、`monthData=今天所在月最后一天`、`timeText=MM.DD-MM.DD`、`isToday=false`、`type='week'`、`weekData=选中周结束日(clamp 昨天)`。
- [ ] **AC4** month tab：`dayData=选中月首日`、`timeText=monthDisplayText`、`isToday=false`、`type='month'`。
- [ ] **AC5** custom tab：`dayData=leftBegin`、`type='custom'`、`apiTimeParams.{beginTime,endTime,customBeginTime,customEndTime,queryType=4,isChoseCustom=1,isWeekAlign=0}` 与源一致。
- [ ] **AC6** festival tab：输出与现状保持一致（`type='custom'`、`dayData=节中`、四项 customData、`timeText=MM.DD~MM.DD`），不得回归。
- [ ] **AC7** 除 custom/festival 外，`customData` 五项均为 `undefined`。
- [ ] **AC8** 同一时刻对同一 tab + 同一选中值，逐字段与旧组件 `defineTimeDataConfig` 输出一致（差异表 §1 中标 ❌/⚠️ 项全部消除或经业务明确豁免）。
- [ ] **AC9** `vue-tsc --noEmit` 与 eslint 通过；无新增类型错误。

## Out of Scope

- 其它页面/组件的接入改造。
- 旧组件（uniapp）侧的任何改动。
