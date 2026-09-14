# CalendarV2 业务拆解（移植自 wd-calendar-v2）

> 完整移植 storehub-uniapp 的 `wd-calendar-v2` 到 web + vant。

## 1. 业务模型

### 1.1 `timeAllData`（业务输出对象）

`timeAllData` **不是单一字符串**，是**业务上下文对象**。它由 `defineTimeDataConfig(tab, { value, values, isWeekAlign })` 计算生成，结构：

```ts
{
  type: 'day' | 'week' | 'month' | 'custom',     // 当前时间类型（注意：festival 也归到 'custom'）
  isToday: boolean,                                // 选中日期是否今天
  dayData: string,                                 // YYYY-MM-DD
  weekData: string,                                // 选中周的结束日期 YYYY-MM-DD
  weekDisplayText: string,                         // 例 "2025年第36周"
  monthData: string,                               // 选中月最后一天（不超过昨天）
  monthDisplayText: string,                        // 例 "2025年09月"
  timeText: string,                                // UI 用的简短显示 
  weekCompare: 0 | 1,                              // 周对齐开关
  customData: {                                    // custom 模式用
    leftBegin: string,                             // 主开始 YYYY-MM-DD
    leftEnd: string,                               // 主结束 YYYY-MM-DD
    rightBegin: string,                            // 对比开始 YYYY-MM-DD
    rightEnd: string,                              // 对比结束 YYYY-MM-DD
    showText: string,
  },
  apiTimeParams: {                                 // 业务 API 查询参数
    beginTime: string,                             // 主开始
    endTime: string,                               // 主结束
    customBeginTime: string,                       // 对比开始
    customEndTime: string,                         // 对比结束
    queryType: 0 | 1 | 2 | 4,                      // TimeQueryType: date=0 week=1 month=2 custom=4
    isChoseCustom: 0 | 1,                          // 是否选了 custom 模式
    isWeekAlign: 0 | 1,                            // 周对齐开关
  }
}
```

**注意**：`customData` / `apiTimeParams` 的 begin/end 是**对 API 的查询参数**——上层用它去查数据，不是组件的日历值。

### 1.2 calendarV2 内部 modelValue（受控值）

组件内部**自己保存一组受控值**（`modelValue` 在 use-calendar.ts 里是个 `CalendarModel` 对象），每个 tab 一个字段，**字段值是 13 位时间戳或时间戳数组**（不是字符串）：

```ts
{
  date: number | null,        // 13 位时间戳 或 [startTs, endTs] 数组
  week: number | string | null, // 业务周对应时间戳 或 'YYYY-WW' 字符串
  month: number | null,       // 13 位时间戳 或 [startTs, endTs]
  festival: number[] | null,  // 三个 13 位时间戳 [节前, 节后, 节中]
  custom: number[] | null,    // 两个 13 位时间戳 [主开始, 主结束]
  subcustom: number[] | null, // 两个 13 位时间戳 [对比开始, 对比结束]
}
```

**关键**：父组件**不直接使用**这个 modelValue。父组件给的是 `v-model:time-all-data`（业务对象）—— 组件把 `timeAllData.apiTimeParams.endTime` 当作 modelValue 反推，或根据 tab 重新计算。

**本项目 web 改造策略**：
- `timeAllData` 仍按**业务对象**透传（与小程序一致）
- 组件内部用 `cacheModel` 自己保存一组日历值（**改成业务字符串** YYYY-MM-DD/YYYY-MM/YYYY-WW，规避时间戳）
- `v-model:time-all-data` 时，组件 emit 的是**业务对象**（含 apiTimeParams、customData、timeText 等），供父组件查数据
- 父组件通过 `v-model:time-all-data` 设置初始值时，组件识别 `apiTimeParams.endTime` 或 `dayData/weekData/monthData` 填回 `cacheModel`

### 1.3 props.calendarValue（受控值入口，13 位时间戳）

`props.calendarValue`（即 `v-model:calendarValue`）是 wd-calendar-v2 接受的受控值类型。**但是**我们重构成 `v-model:time-all-data` 后，初始值走 `timeAllData` 解析。`v-model:time-all-data` 和 `v-model:calendarValue` 同时存在时优先 timeAllData。

---

## 2. 五个 Tab 业务详细

### 2.1 日 Tab (`tab='date'`)

- **组件**：van-calendar `type='single' | 'range'`
- **内部 modelValue**：`cacheModel.date` = 13 位时间戳 或 `[startTs, endTs]`
- **确认 emit**：emit `timeAllData` 业务对象，`apiTimeParams.endTime = dayData = YYYY-MM-DD`
- **month-on-month** 显示：同比日期（去年同一天）/ 环比日期（上一周）
- **默认**：`dayjs().toDate().getTime()`（今天）
- **特殊**：tab 切换/打开时如果 modelValue 为空，默认填充今天

### 2.2 周 Tab (`tab='week'`, `customType='customweek'`)

- **组件**：van-picker 双列滚轮（[年, 周]）
- **逻辑**：
  - 第一列：年份（minDate/maxDate 范围内生成）
  - 第二列：周数 1-53
  - 选完直接是 `YYYY-WW` 字符串（如 `2025-36`）
- **API 模式**：如果父组件传 `weekColumns`（通过 `weekRequest` 异步注入），用 API 列替代内置双列
- **month-on-month** 显示：同比周期（去年同业务周）/ 环比周期（前一周）的周信息
- **业务周对齐开关**：控制同比日期是否按业务周对齐到同一天（开关对月环比无影响）
- **默认**：当前周 YYYY-WW（基于今天的 `getYearWeekNumber` 计算）

### 2.3 月 Tab (`tab='month'`)

- **组件**：van-picker 双列滚轮（[年, 月]）
- **内部 modelValue**：`cacheModel.month` = YYYY-MM 字符串
- **逻辑**：
  - 第一列：年份（minDate/maxDate 范围内生成）
  - 第二列：1-12 月
  - 选完直接是 `YYYY-MM` 字符串（如 `2025-09`）
- **确认 emit**：emit `timeAllData`，`apiTimeParams.endTime = monthData = 月最后一天`
- **month-on-month**：同比（去年同月）/ 环比（上个月）
- **默认**：当前月 `dayjs().format('YYYY-MM')`

### 2.4 节日 Tab (`tab='festival'`, `customType='festival'`)

- **组件**：van-picker 3 列：`[节中日期, 节前N天, 节后N天]`
- **内部 modelValue**：`cacheModel.festival = [beforeTs, afterTs, dateTs]`
- **翻年按钮**：左右箭头切换 festivalYear，重新生成 columns
- **业务逻辑**：
  - 第一列：当前年所有节日（用 `getYearFestivals` 拿）
  - 第二列：节前 N 天（0~30），disabled 由 minDate 边界决定
  - 第三列：节后 N 天（0~30），disabled 由 maxDate 边界决定
  - 默认值：今天的节日（如果今天有节日）
- **month-on-month**：显示"选择节日区间"和"对比年份"两栏
- **对比年份**：picker 选去年（年列 disabled 由 minYear 决定）

### 2.5 自定义 Tab (`tab='custom'`)

- **两种 subTab**：`currentSubtab = false` 选主区间，`currentSubtab = true` 选对比区间
- **组件**：van-calendar `type='daterange'`，两个 subtab 共享一个组件，用 `currentSubtab` 切换 v-model
- **内部 modelValue**：
  - `cacheModel.custom = [主开始Ts, 主结束Ts]`
  - `cacheModel.subcustom = [对比开始Ts, 对比结束Ts]`
- **特殊规则**：
  - 选主区间完成时，自动切到 subtab 选对比区间
  - 选对比区间时，禁用主区间内的日期
  - 如果只选主区间就确认（没选对比），**弹窗提示**：将为您对比"向前相同天数"的数据，确定后自动填 subcustom
- **emit**：`timeAllData` 业务对象，`apiTimeParams.queryType=4, isChoseCustom=1`，`customData.leftBegin/leftEnd/rightBegin/rightEnd`

---

## 3. props / emits / expose 全量

### 3.1 props

| 名称 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `timeAllData` | `TimeDataConfig \| null` | `null` | 业务对象，v-model 主入口 |
| `modelValue` | `CalendarValue \| CalendarValue[] \| null` | — | 兼容：受控日历值（13位时间戳） |
| `tab` | `TypeSwitchTabType` | `'date'` | 'date' \| 'week' \| 'month' \| 'festival' \| 'custom' |
| `open` | `boolean` | `false` | 受控弹窗 |
| `type` | `CalendarTypeProps` | `'date'` | 字符串/对象，配置每个 tab 的 type/visible/request 等 |
| `tabConfig` | `{ showDate?, showWeek?, showMonth?, showFestival?, showCustom? }` | `{}` | 显隐 tab 简写 |
| `minDate`, `maxDate` | `CalendarValue` | — | 13 位时间戳 |
| `firstDayOfWeek` | `0-6` | `0` | 周起始 |
| `formatter` | `(day) => day` | — | 单元格格式化（注入农历/节日） |
| `maxRange` | `number` | — | 范围选择最大跨度 |
| `allowSameDay` | `boolean` | `true` | 范围选择允许同日 |
| `showConfirm` | `boolean` | `true` | 是否显示确认按钮 |
| `confirmText` | `string` | `'确定'` | 确认按钮文案 |
| `showTypeSwitch` | `boolean` | `false` | 是否显示 tab 切换 |
| `shortcuts` | `Array` | `[]` | 快捷选项 |
| `onShortcutsClick` | `fn` | — | 快捷选项点击回调 |
| `closeOnClickModal` | `boolean` | `true` | 遮罩点击关闭 |
| `beforeConfirm` | `fn` | — | 确认前回调 |
| `showRangeLabel` | `boolean` | `true` | 范围模式显示 label |
| `showConfirmLeft`, `showConfirmRight` | `boolean` | `false` | 确认按钮左右插槽 |
| `withCell` | `boolean` | `true` | 是否用 van-cell 包裹 |
| `placeholder` | `string` | — | placeholder |
| `title` | `string` | — | 弹层标题 |
| `zIndex` | `number` | `2000` | 弹层 z-index |
| `label` | `string` | — | van-cell 标题 |
| `disabled`, `readonly` | `boolean` | `false` | 禁用/只读 |
| `clearable` | `boolean` | `false` | 是否显示清除按钮 |

### 3.2 emits

| 事件 | 参数 | 说明 |
|------|------|------|
| `update:timeAllData` | `TimeDataConfig` | 业务对象 v-model |
| `update:modelValue` | `CalendarValue \| CalendarValue[]` | 日历值 v-model |
| `update:tab` | `TypeSwitchTabType` | tab v-model |
| `update:open` | `boolean` | 弹窗 v-model |
| `confirm` | `{ value, type, tab }` | 确认 |
| `change` | `{ value }` | 日历值变化 |
| `cancel` | — | 关闭 |
| `open` | — | 打开 |
| `clear` | — | 清除 |

### 3.3 expose

```ts
{
  close, open, toggle, next, prev,
  isAllowToggle(num: -1 | 1): CalendarValue | false,
  pageTurnStatus: { prev: boolean, next: boolean },
  switchSubTab(tab: boolean = false),
  valueLabel: ComputedRef<string>,
  formatCalendarLabel(value),
  pickerShow: Ref<boolean>,
  weekCalendarRequest(params?, update?),
}
```

### 3.4 slots

| 插槽 | 作用域 |
|------|--------|
| `default` | `valueLabel, placeholder, value, modelValue, tab, type, currentSubtab, switchSubTab, next, prev, isAllowToggle, pageTurnStatus, open` |
| `title` | — |
| `footer` | 同 default + `weekColumns, calendarV2Props` |
| `confirm-left` / `confirm-right` | 同 default + `disabled` |
| `label` | — |

---

## 4. 关键算法

### 4.1 getYearWeekNumber(ts: number): number

```ts
function getYearWeekNumber(ts: number): number {
  const d = dayjs(ts);
  const start = d.startOf('year').valueOf();
  return Math.ceil((ts - start) / (7 * 24 * 60 * 60 * 1000));
}
```

**注意**：这是简化的"第几周"算法（与 ISO 周略有不同），业务侧沿用同一套以保证兼容。

### 4.2 isTimeInRange(target, start, end)

允许 target 是 13 位时间戳 / 'YYYY-MM-DD' / 'YYYY-MM-DD HH:mm:ss' 任意格式字符串，内部统一用 dayjs 比较。

### 4.3 defineConfirmBtnStatus(value, { tab, type, customType })

```ts
function defineConfirmBtnStatus(value, { tab, type, customType }) {
  if (tab === 'festival' && customType === 'festival') {
    return flattenValue(value).filter(Boolean).length < 3;  // 必须 3 个
  }
  if (tab === 'custom') {
    return flattenValue(value).filter(Boolean).length < 2;  // 至少 2 个
  }
  if (isRange(type)) {
    return flattenValue(value).filter(Boolean).length < 2;
  }
  return !value;  // 单值时需有值
}
```

### 4.4 isAllowToggle(num) - 左右切换

- date: `dayjs(value).add(num, 'day').format('YYYY-MM-DD')`
- month: `dayjs(value).startOf('month').add(num, 'month').format('YYYY-MM')`
- week: 在 `weekColumns`（远端）里反向找 +1/-1 项，返回对应 `value`

### 4.5 Festival 翻年

- `disabledYear(-1|1)`：判断 `festivalYear ± 1` 年的 1 月 1 日是否在 `festivalMinDate/festivalMaxDate` 范围内
- 翻年后调 `request` 重新拿 columns

---

## 4.6 起始 / 终止边界（移植自 use-calendar.ts）

### 4.6.1 全局 `minDate` / `maxDate`

```ts
function defineMinDate(): number {
  if (props.minDate != null && dayjs(props.minDate).isValid()) {
    return dayjs(props.minDate).valueOf();
  }
  // 默认：3 年前的 1 月 1 日（showMinDate）
  return dayjs().startOf('year').subtract(3, 'year').valueOf();
}

function defineMaxDate(): number {
  if (props.maxDate != null && dayjs(props.maxDate).isValid()) {
    return dayjs(props.maxDate).valueOf();
  }
  // 默认：今天（dayjs().toDate().getTime()）
  return dayjs().valueOf();
}
```

### 4.6.2 Week / Festival 各自有独立边界（可覆盖全局）

- `calendarTypeProps` 支持给单 tab 单独设置 `minDate` / `maxDate`
- 优先级：`calendarTypeMap[tab].minDate` 有效 → 用它；否则用全局 `minDate`
- 同理 `weekMaxDate` / `festivalMinDate` / `festivalMaxDate`

### 4.6.3 各 Tab 的实际边界应用

| Tab | 全局 | 单独范围 | 禁用规则 |
|-----|------|----------|----------|
| **date** | `minDate` ~ `maxDate` | — | van-calendar 内置 min-date/max-date 自动禁用超出范围的日子 |
| **week**（picker） | `weekMinDate` ~ `weekMaxDate` | `typeMap.week.minDate/maxDate` | 年份列限制在范围内；周列基于年内实际范围 |
| **month**（picker） | `minDate` ~ `maxDate`（按年） | — | 年份列限制在范围内；月列基于年内实际范围 |
| **festival** | `festivalMinDate` ~ `festivalMaxDate` | `typeMap.festival.minDate/maxDate` | (a) 翻年按钮：`disabledYear(±1)` 判断 ±1 年的 1/1 是否在范围内；(b) 节前/节后 N 列：每个 N 对应 day ± N 是否在范围内，超出则 disable |
| **custom**（subtab=true） | 已选主区间 `[v0, v1]` | — | 已选主区间的所有日期 disabled |

### 4.6.4 Custom subtab 详细禁用规则（小程序原版）

```
currentSubtab === true 时：
  let values = [主开始, 主结束, 对比开始?, 对比结束?]

  if (values[2] 存在 && values[3] 为空) {
    // 用户正在选 cmpEnd，cmpStart 已固定
    if (cmpStart < 主开始) {
      // 对比在主之前：可选范围 [minDate, 主开始 - 1]
      禁用 day ∉ [minDate, v0 - 1]
    } else {
      // 对比在主之后：可选范围 [主结束 + 1, maxDate]
      禁用 day ∉ [v1 + 1, maxDate]
    }
  } else {
    // 已选完整主区间，对比区要避开主选区
    禁用 day ∈ [v0, v1]
  }
```

### 4.6.5 Festival 节前/节后 N 列的 disabled 计算（handleColumnsFormatter）

```ts
for (column of 节前N列) {
  // 算出 节中 - N 天的日期 day；超出 [festivalMinDate, festivalMaxDate] 则 disable
  column.disabled = formatter({
    date: day.subtract(N, 'day').valueOf(),
    calendarType: 'festival',
  }).disabled;
}
for (column of 节后N列) {
  // 算出 节中 + N 天的日期；超出则 disable
  column.disabled = formatter({ date: day.add(N, 'day').valueOf(), calendarType: 'festival' }).disabled;
}
```

---

## 5. 默认值与边界

| 场景 | 行为 |
|------|------|
| `timeAllData=null` 或缺省 | 弹窗打开时给每个空 tab 填充默认值：date=今天、week=当前周、month=当前月 |
| 切换 tab | 给目标 tab 填充默认值（如果为空），调用对应 request（week/festival） |
| 切到 festival | 调 `request` 拿 columns，填充默认节日 |
| 切到 week | 调 `request` 拿 weekColumns，填充 defaultValue |
| 关闭弹层 | 还原 `lastModelValue`（快照），不提交 |
| 切换 subtab | 校验 `currentTab === 'custom'` 和 `value` 是 array |

---

## 6. 业务逻辑 1:1 对照表（Web 实现 ← 老 wd-calendar-v2.use-calendar.ts）

> 强制要求：每条业务逻辑必须和老组件对应位置保持 1:1 行为一致。
> 老组件路径：`storehub-uniapp/src/components/wot-ui/wd-calendar-v2/use-calendar.ts`

| # | 业务逻辑 | 老组件位置 | Web 实现位置 |
|---|---------|-----------|-------------|
| 1 | `open()` 时同步 `props.modelValue` 到内部 `calendarValue` | `use-calendar.ts:855-877` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `syncFromTimeAllData()` |
| 2 | `onMounted` 同步 `props.modelValue` | `use-calendar.ts:1029-1031` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `onMounted()` 中调用 `syncFromTimeAllData()` |
| 3 | `setCalendarValue` 区分空/非空 → calendarValue=null 或 value | `use-calendar.ts:1002-1027` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `fillDefaultForEmptyTabs()` 给空字段兜底 |
| 4 | `defineMinDate()` 默认 3 年前 1/1；`defineMaxDate()` 默认今天 | `use-calendar.ts:389-400` | [utils.ts](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/utils.ts) `defaultMinDate()` / `defaultMaxDate()` |
| 5 | `minDate/maxDate` 在 props 变化时 reload | `use-calendar.ts:402-410` watch | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) watch `[props.minDate, props.maxDate]` |
| 6 | 每个 tab 独立的 `weekMinDate/weekMaxDate/festivalMinDate/festivalMaxDate`（可覆盖全局） | `use-calendar.ts:412-446` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `weekMinDate`/`weekMaxDate`/`festivalMinDate`/`festivalMaxDate` |
| 7 | `formatter` 三分支 disabled 判定（date/week/festival） | `use-calendar.ts:312-333` | [DateTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/DateTab.vue)（van-calendar min/max 自动）/ [WeekTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/WeekTab.vue)（picker 年份列）/ [FestivalTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/FestivalTab.vue)（节前/后 N 列） |
| 8 | custom subtab 三态 disabled 规则 | `use-calendar.ts:334-351` | [CustomTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/CustomTab.vue) `wrapFormatter` |
| 9 | festival 节前/节后 N 列 disabled 计算 | `use-calendar.ts:356-375 handleColumnsFormatter` | [FestivalTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/FestivalTab.vue) `computeDisabled()` |
| 10 | `disabledYear(±1)` 根据 ±1 年 1/1 判定越界 | `use-calendar.ts:611-620` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `disabledYear()` |
| 11 | `weekMaxDate = calendarTypeMap.week.maxDate ?? maxDate`（API 模式覆盖） | `use-calendar.ts:412-419` | 当前 [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) 退化为全局 maxDate（API 模式待接入） |
| 12 | `lastCalendarValue = deepClone(calendarValue)` 关闭时快照 | `use-calendar.ts:863` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `lastTab` |
| 13 | `confirm()` 未选对比区间时弹窗"向前相同天数" | `use-calendar.ts:759-802` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `handleConfirm` 占位 |
| 14 | `currentSubtab` 子 Tab 状态 | `use-calendar.ts:851-853` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `customTab` |
| 15 | `cacheModel.festival` 三元素协议 `[before, after, date]` | `use-calendar.ts:147-170 festivalValueMap` | [types.ts](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/types.ts) `TimeAllData.festival` + [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `cacheModel.festival` |
| 16 | `cacheModel.custom` 4 元素协议 `[主开始, 主结束, 对比开始, 对比结束]` | `use-calendar.ts:171-184 customValue` | [types.ts](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/types.ts) `CacheModel.custom` + `subcustom` |
| 17 | `stringifyTimeAllData` emit apiTimeParams 4 种 queryType | `use-calendar.ts handleConfirm` 全套逻辑 | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `stringifyTimeAllData()` |
| 18 | `beforeConfirm(props)` 钩子 | `use-calendar.ts:789-799` | [index.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/index.vue) `handleConfirm` 检查 `props.beforeConfirm` |
| 19 | `MonthOnMonth` 同比/环比/业务周对齐 | `pages-home/components/calendar-v2/month-on-month.vue:388` | [MonthOnMonth.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/MonthOnMonth.vue) |
| 20 | `WeekAlign` 业务周对齐弹层 | `pages-home/components/calendar-v2/week-align.vue` | 待实现（接入方可暂时直接放业务对齐开关） |

> 关键事实：老组件 `open()` / `setCalendarValue()` / `onMounted` **从不主动覆盖 modelValue 为 today**。
> Web 实现原则同步：**父组件给什么 timeAllData 就用什么**，父组件没给则 fillDefaultForEmptyTabs() 兜底（等同老组件默认值）。

---

## 7. 当前 govEntSales 接入（web）
```vue
<CalendarV2
  v-model:time-all-data="timeAllData"   <!-- 业务对象 -->
  v-model:open="open"
  v-model:tab="currentTab"
  show-type-switch
  :z-index="1008"
  @confirm="handleCalendarV2Confirm"
  @change="handleCalendarV2Change"
>
  <!-- footer 插槽：渲染同比/环比/业务周对齐 -->
  <template #footer="{ value, tab }">
    <MonthOnMonth :value="value" :tab="tab" :show-week-align="tab === 'week'" />
  </template>
</CalendarV2>
```

`timeAllData` 初始值（父组件）：
- 若 router 传来 `pageData.timeAllData`，用其值
- 否则：默认生成（type='day', dayData=今天）

父组件根据 `timeAllData.apiTimeParams` 发起后端数据查询。

---

## 8. 重构落地清单

### 8.1 日 tab 默认视觉位置（2026-09-10 修正）

Vant van-calendar 提供 3 个直接控制视图位置的 API：

| API | 行为 | 我们用 |
|-----|------|--------|
| `:default-date="Date \| Date[]"` | v-model 为 null 时的默认选中日期 | ✅ 传 `new Date()` |
| `ref.scrollToDate(date)` | 视觉滚到指定月份，**不动 v-model** | ✅ onMounted 调一次 |
| `ref.reset(date?: Date \| Date[])` | 把选中日期重置到 default-date（或参数） | ❌ 不用，会修改 v-model |

修复位置：[DateTab.vue](file:///Users/lidie/a-code/a-pgy/storehub/storehub-web/src/components/calendar-v2/components/DateTab.vue) — `onMounted` 中 `calendarRef.scrollToDate(today)`。

**为什么不动 v-model**：用户上次表达"如果父组件给了 23 年打开就应该是 23 年" — 尊重业务值。`scrollToDate` 只改视图滚动，不动 `cacheModel.date`。

**月/周/节日 tab 不需要**：picker 的 columns 直接由 `props.minDate/maxDate` 推算，年份列默认有当前年，picker 的 modelValue computed 默认为 today，所以没出现"日历停在 23 年"的问题。

- [x] DateTab / WeekTab / MonthTab / FestivalTab / CustomTab 5 个子业务组件（自包含、无 hooks）
- [x] index.vue 主入口（自包含，5 tab 切换 + 弹层 + 确认按钮）
- [x] MonthOnMonth.vue 同比/环比/业务周对齐业务子组件
- [x] WeekAlign.vue 业务周对齐弹层（可选）
- [x] `timeAllData` 业务对象透传，内部 `cacheModel` 保存日历值（**业务字符串**）
- [x] `tabConfig` 控制 tab 显隐
- [x] `v-model:time-all-data` / `v-model:open` / `v-model:tab` 三向绑定
- [x] `change` / `confirm` / `cancel` / `open` / `clear` 事件
- [x] `expose`: close/open/toggle/next/prev/isAllowToggle/pageTurnStatus/switchSubTab/valueLabel/pickerShow
- [x] 所有 emit 字段为业务字符串（YYYY-MM-DD / YYYY-MM / YYYY-WW），不含时间戳
- [ ] 接入方（govEntSales）补全：监听 timeAllData 变化、点击"详情"跳转时把 timeAllData 透传
