# 技术设计 — timeAllData 字段输出对齐

## 1. 边界

- 改动范围：`storehub-web/src/components/calendar-v2/index.vue`（主）、必要时 `utils.ts`。
- 不改：`types.ts` 字段契约、子组件（`DateTab/WeekTab/MonthTab/CustomTab/FestivalTab`）对外事件、festival 既有行为。
- 唯一消费方 `govEntSales/index.vue` 无需改动（只做 `v-model:time-all-data` 透传）。

## 2. 核心设计：引入单一 `day` 派生函数

当前 `stringifyTimeAllData` 用三个独立 helper（`computeDayData` / `computeWeekData` / `computeMonthData`）
分别读取 `cacheModel.date / week / month`，与源「单一 `day` 派生」的结构不符。

### 2.1 新增 `resolvePrimaryDay(tab): dayjs`

复刻源 `defineTimeDataConfig` L39-57 的 `day` 选择逻辑：

```
date    → cacheModel.date 的首值
week    → dayjs()（今天）
month   → cacheModel.month 的值
custom  → cacheModel.custom[0]（leftBegin）
festival→ cacheModel.festival 的节中（f[2]）
非法/缺值 → dayjs()（今天）兜底
```

### 2.2 由 `day` 派生次级字段（复刻源 L59-68 + L97-104）

| 字段 | 派生 |
|------|------|
| `dayData` | `day.format('YYYY-MM-DD')` |
| `monthData` | `day.endOf('month').format('YYYY-MM-DD')` → clamp 昨天 |
| `monthDisplayText` | `day.endOf('month').format('YYYY年MM月')` |
| `weekData` | `getDateWeek(day, 4).weekRange[1]` → clamp 昨天 |
| `weekDisplayText` | `getDateWeek(day, 4)` → `${year}年第${padZero(week)}周` |
| `timeText`（base） | `day.format('MM-DD')` |

> week tab 例外：源对 week tab 传 `undefined`，base weekData 取「今天所在周」，随后由 `case 'week'` 覆盖为选中周。

### 2.3 各 tab 覆盖（复刻源 L106-178）

- `date`：`type='day'`；`isToday = dayjs().diff(dayData,'day') === 0`；`apiTimeParams.isWeekAlign = weekAlignValue?1:0`。
- `week`：`weekData/weekDisplayText/timeText` 用选中周覆盖；`timeText = [start,end].map(MM.DD).join('-')`；`isToday` 保持 `false`；`endTime = clamp(weekData)`；`isWeekAlign=1`。
- `month`：`type='month'`；`timeText=monthDisplayText`；`isToday` 保持 `false`；`endTime=clamp(monthData)`；`isWeekAlign=0`。
- `festival`：`type='custom'`；`isToday=false`；`dayData=节中`；customData 四项；`timeText=MM.DD~MM.DD`。
- `custom`：`type='custom'`；`isToday=false`；`dayData=leftBegin`；customData 四项按位；`timeText=MM.DD~MM.DD`。

### 2.4 业务周换算（R6，可选/待确认）

- 若需完全对齐：新增 `getDateWeek(date, startOffset)` 复刻 `util-dayjs.ts` 的 `getWeekInfo`（周四起始）。
- 若 web 侧可拿到业务周表：week tab 命中时用 `find.endDate / find.simpleLabel ?? find.label / startDate-endDate`。
- 在业务确认前，先保证「同一 `day` 口径」一致，周号算法差异单独评估。

## 3. 数据流

```
父组件 v-model:time-all-data
        │
        ├─ open() → syncFromTimeAllData() → cacheModel（各 tab 缓存）
        │                                        │
        │                        resolvePrimaryDay(tab) → day
        │                                        │
        │                      派生 dayData/weekData/monthData/... 
        │                                        │
        └──── emit('update:timeAllData', out) ← stringifyTimeAllData()
```

关键点：**`cacheModel.date/week/month` 退化为「各 tab 的选中值容器」**，
不再各自充当 `dayData/weekData/monthData` 的直接来源。

## 4. 契约

- 输入：`props.timeAllData`（受控回显）、`cacheModel`（各 tab 选中值）。
- 输出：`TimeAllData`（字段名/类型不变）。
- 事件：`update:timeAllData` / `update:modelValue` / `update:tab` / `confirm` / `change`。
- 不变式：`queryType/isChoseCustom/isWeekAlign/weekCompare` 取值表（差异表 §3）不得变更。

## 5. 权衡

| 方案 | 说明 | 取舍 |
|------|------|------|
| A. 单一 `day` 派生（选） | 复刻源结构，天然自洽 | 改动 `stringifyTimeAllData` + `syncFromTimeAllData` 回显 |
| B. 保持三缓存独立，逐字段打补丁 | 改动小 | 无法根治，回显与输出仍会漂移 |

选 A：与源同构，后续维护可对照。

## 6. 兼容 / 回滚

- 兼容：字段契约不变，消费方无感；festival 行为冻结。
- 风险：
  - 回显链路 `syncFromTimeAllData` 需同步改造，否则「重新打开弹层」会把带位置语义的 customData 解析错位 → 用 R7 按位解析化解。
  - 业务周算法差异可能引起 week tab 结果微调 → R6 单独确认。
- 回滚点：`stringifyTimeAllData` / `syncFromTimeAllData` 各自独立提交，可单独 revert。

## 7. 验证策略

- 无 jsdom/vitest（`node_modules` 未安装）⇒ 采用：
  1. `npx vue-tsc --noEmit -p tsconfig.app.json`（类型）；
  2. `npx eslint src/components/calendar-v2`（规范）；
  3. node 脚本（`vite.ssrLoadModule` 或纯函数复刻）对**固定输入**逐字段打印，与源 `defineTimeDataConfig` 的语义预期比对（对照差异表 §1）。
