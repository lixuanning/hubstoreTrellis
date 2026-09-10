# wd-calendar-v2 Web 重构 — 设计文档（组件规格）

> 本文档是 **组件规格说明书**：完整描述 `wd-calendar-v2` 的能力、API、行为、边界条件，供 web 端等价实现参考。
> 源实现位于 `storehub-uniapp/src/components/wot-ui/wd-calendar-v2/`，已逐文件逆向。
> 业务侧使用见 `home-data-dashboard.vue` + `use-calendar-v2.ts` + `month-on-month.vue`。

---

## 1. 组件定位

`wd-calendar-v2` 是一个**带 Tab 维度切换的复合型日期选择器**，底层能力 = `wd-calendar-view`（日/周/月面板） + `wd-picker-view`（节日/自定义周滚轮） + `wd-action-sheet`（弹层）+ `wd-tabs`（Tab 切换）。

与官方 `wd-calendar` 的本质差异：

- 业务方对外**只通过 `v-model`（值）、`v-model:tab`（维度）、`type`（每 Tab 的子类型）三个入口**操作组件，组件内部维护每个 Tab 独立的 `modelValue` 缓存。
- 支持 5 个 Tab：`date`（日/单选） / `week`（周/单选，业务周） / `month`（月/单选） / `festival`（节日 + 节前 N 天 + 节后 N 天） / `custom`（双区间：选 + 对比）。
- 每个 Tab 还可独立配置 `custom=true`，把标准 `date/week/month` 改造成"自定义滚动周/列"等业务变体。

---

## 2. 关键数据模型

### 2.1 顶层 Props（与源 `types.ts` 对齐）

| 字段 | 类型 / 默认 | 说明 |
| --- | --- | --- |
| `modelValue` | `number \| string \| (number\|string)[] \| null` | 必填。受控值，13 位时间戳 / `YYYY-MM` / `YYYY-MM-DD` / 业务周 `YYYY-WW` / 数组 |
| `tab` | `'date' \| 'week' \| 'month' \| 'festival' \| 'custom'` (`'date'`) | 受控 Tab 维度 |
| `type` | `string \| CalendarTypeProps` (`'date'`) | 当为 string：所有 Tab 共用类型；为对象：按 Tab 独立配置（`visible` / `type` / `custom` / `request` / `displayFormat` / `maxDate` / `minDate` / `maxRange` / `showConfirmLeft` / `confirmLeftStyle` / `showConfirmRight` / `confirmRightStyle`） |
| `open` | `boolean` (`false`) | 受控开关 |
| `minDate` / `maxDate` | `number`（13 位时间戳） | 全局边界；不传则默认 `今年初-3年 ~ 今天` |
| `firstDayOfWeek` | `0-6` (`0`) | 周起始 |
| `formatter` | `(day) => day` | 单元格渲染钩子 |
| `maxRange` | `number` | 范围选择最大跨度（天） |
| `allowSameDay` | `boolean` (`true`) | 范围选择是否允许同日 |
| `defaultTime` | `string \| string[]` (`'00:00:00'`) | 选中日期的默认时分秒 |
| `timeFilter` | fn | datetime/datetimerange 时间过滤 |
| `hideSecond` | `boolean` (`false`) | datetime 是否隐藏秒 |
| `label` / `placeholder` / `title` | string | 单元格/弹层文案 |
| `disabled` / `readonly` | boolean | 禁用/只读 |
| `showConfirm` | `boolean` (`true`) | 是否显示确认按钮；为 `false` 时点击即提交 |
| `confirmText` | string | 确认按钮文案 |
| `displayFormat` | fn | 单元格顶部回显格式 |
| `innerDisplayFormat` | fn | 范围选择面板内部回显 |
| `showTypeSwitch` | `boolean` (`false`) | 是否显示 Tab 切换条 |
| `shortcuts` | `Array<{ text }>` | 快捷选项 |
| `onShortcutsClick` | fn | 快捷点击回调，返回新值 |
| `closeOnClickModal` | `boolean` (`true`) | 点遮罩关闭 |
| `safeAreaInsetBottom` | `boolean` (`true`) | iPhone X 安全区 |
| `beforeConfirm` | `({ value, tab, type, customType, resolve }) => void` | 确认前钩子，`resolve(true)` 放行 |
| `showRangeLabel` | `boolean` (`true`) | 范围选择面板顶部显示 `start/end` |
| `showConfirmLeft` / `showConfirmRight` | `boolean` | 确认按钮左右插槽开关 |
| `confirmLeftStyle` / `confirmRightStyle` | `CSSProperties` | 上述插槽样式 |
| `withCell` | `boolean` (`true`) | 是否使用内置单元格 |
| `lazyRender` / `rootPortal` | `boolean` | 弹层懒渲染 / root portal |
| `clearable` | `boolean` | 显示清除按钮 |
| `markerSide` | `'before' \| 'after'` | 必填星号位置 |
| `immediateChange` | `boolean` | picker 滚停即触发（仅小程序） |
| `customClass` / `customLabelClass` / `customValueClass` / `customStyle` | 样式穿透 | — |

### 2.2 内部状态（不暴露但决定行为）

```
pickerShow        ref<boolean>           // 弹层显示
currentTab        ref<TypeSwitchTabType> // 当前 Tab
lastTab           ref<TypeSwitchTabType> // 打开前的 Tab（cancel 时回退）
currentType       computed<CalendarType> // 剥离 custom 前缀后的实际 type
lastCurrentType   ref                    // 关闭前回退
customType(tab)   computed               // 当前 Tab 是否为 custom（返回 customxxx）
calendarTypeMap   ref                    // props.type 解析后的 type→配置
calendarShowTabs  computed               // visible=true 且按 TypeSwitchTabs 顺序排好的 Tab 序列
modelValue        reactive<CalendarModel>// 每个 Tab 独立缓存：{ date, week, month, festival, custom, subcustom, subdate, ... }
lastModelValue    reactive               // 打开前的快照（cancel 回退用）
currentSubtab     ref<boolean>           // 仅 custom Tab 有：false=选区  true=对比区
calendarValue     computed               // 受 props.modelValue 与 currentTab/subtab 影响的展示值
weekValue         ref                    // customweek 滚轮值
festivalValue     computed               // [date, beforeDate, afterDate]，展示给 picker
festivalValueMap  ref                    // 上述三者原始映射
festivalYear      ref<number>            // 当前展示的节日年份
panelHeight       ref<number>            // 日历面板计算高度
inited            ref<boolean>           // 首次进入面板后置 true
pageTurnStatus    { prev, next: boolean }// 左右切换按钮是否禁用
toggleState       ref<boolean>           // 防抖，250ms 内禁止重复开/关/翻页
```

### 2.3 事件 / 双向绑定

| 事件 | 触发时机 | 载荷 |
| --- | --- | --- |
| `update:modelValue` | `confirm` 触发 / `shortcut` 触发 / `setValue()` | 新值 |
| `update:tab` | `onConfirm` 内部 | 当前 `tab` |
| `update:open` | `toggle` 之后 | 弹层状态 |
| `update:endDate` | 组件内部未真正写入，保留兼容 | — |
| `confirm` | 点确认按钮 / `showConfirm=false` 即时 | `{ value, type, tab }` |
| `change` | 任意选择变化（即使未 confirm） | `{ value }` |
| `cancel` | 关闭弹层（恢复快照） | — |
| `open` | 弹层打开 | — |
| `clear` | 点击清除 | — |

### 2.4 对外暴露（`defineExpose`）

```
close()                                    // 关闭（恢复 lastTab / lastModelValue）
open()                                     // 打开（重置面板高度 + scrollIntoView）
toggle()                                   // 取反
next() / prev()                            // 翻页 ±1
isAllowToggle(num: -1 | 1)                 // 是否允许翻页（受 min/max 边界与节日范围限制）
pageTurnStatus                             // { prev, next } 计算后的禁用态
switchSubTab(tab?: boolean)                // 切 custom 的两个子 Tab
valueLabel                                 // 当前 modelValue 渲染后的展示文本
formatCalendarLabel(value)                 // 任意值的展示文本
weekCalendarRequest(params, update)        // 节日/业务周远程数据拉取（500ms 防抖）
pickerShow                                 // ref<boolean>
```

---

## 3. 初始化（"初始值"详细说明）

### 3.1 `type` 解析时机

`useCalendarTab` 内的 `calendarTypeMap` 监听 `props.type` 立即 + 深 watch 执行 `defineCalendarTypeMap(value)`。所以**首次渲染**就会得到：

- 若 `type` 是 `string`：`calendarTypeMap` 全 5 个 Tab 全部 `visible=true`，`customType(tab)` 始终 `undefined`（即全部走标准 `wd-calendar-view`，无列样式变体）。
- 若 `type` 是对象：按对象粒度决定每个 Tab 的 `visible` / 子 `type` / `custom` / `request` / `displayFormat` / 边界 / 按钮扩展。

> **Web 重构注意**：string 与 object 两种形态的初始化路径必须并存，object 形态的 key 不存在时按 `visible=true` 兜底（见 `defineCalendarTypeMap` 的 `typeConfig` 默认值）。

### 3.2 `currentTab` 的初始选择

```
const currentTab = ref(calendarShowTabs.value[0] ?? 'date')
```

- `calendarShowTabs` 按 `TypeSwitchTabs` 的固定顺序（`date/week/month/festival/custom`）保留 `visible=true` 的 Tab 列表。
- 若用户给了 `props.tab`，且 `tab` 在新列表里 → 切到该 tab；否则保持 `calendarShowTabs[0]`。
- `onMounted` 还会再调用一次 `handleCalendarTabType(props.tab)` 做最终确认（防止 `type` 变化导致 `props.tab` 已不在可见集合中，自动回退到 `calendarShowTabs[0]`）。

### 3.3 `modelValue` 初始化的两条路径

组件内部 `modelValue` 是一个 reactive 对象 `{ date, week, month, festival, custom, subcustom, subdate, subweek, submonth, subfestival }`，所有 Tab 互不干扰。

**路径 A：`onMounted` 一次性写入**

```ts
onMounted(() => setCalendarValue(props.modelValue))
```

- `setCalendarValue` 会按 `customType(currentTab)` 分流：
  - `festival`：调用 `setDefaultFestivalValue(value)`，根据传入值/今天/最近节日自动算出 `date / beforeDate / afterDate`。
  - `customweek`：`weekValue` 同步为 `value[0]`，否则用 `defaultWeekValue`。
  - 其他：直接把 `props.modelValue` 通过 `calendarValue` 写入 `modelValue[currentTab]`。
- **如果传入 `null` 或空数组**：`calendarValue.value = null`，对应 Tab 的缓存被清空。

**路径 B：每次 `open()` 重新写入**

```ts
setCalendarValue(props.modelValue)            // 覆盖缓存
lastCalendarValue.value = deepClone(calendarValue) // 备份快照
lastTab.value = currentTab.value
lastCurrentType.value = currentType.value
handleTypeChange(...)                          // 触发重新拉取
```

- **业务上**：组件"打开弹层"动作会用最新的 `props.modelValue` 覆盖内部缓存，关闭（cancel）则恢复 `lastCalendarValue`。

### 3.4 `calendarValue` 写入的特殊规则（setter）

```ts
set(value) {
  if (tab === 'custom') {
    modelValue.custom = values.slice(0, 2)     // 前两个 → 主选区
    modelValue.subcustom = values.slice(2, 2)  // 后两个 → 对比区
  }
  if (tab === 'month' && isEmptyValue(values[0])) {
    modelValue.month = dayjs().format('YYYY-MM') // 容错：空值回退当月
  }
  modelValue[currentTab] = value               // 其他 Tab 直接写
}
```

> **Web 重构注意**：自定义 Tab 的写入是"前 2 个 → 选区、后 2 个 → 对比区"的 4 元素协议。重构后如果拆成两个 `customValue` / `customSubValue` 受控 ref，**对外仍要提供 flatten 合并读取**（`calendarValue` getter 已经做了 `flattenDeep([value, subValue])`）。

### 3.5 `festival` 的初始化最复杂

`setDefaultFestivalValue(value, useSet=false)` 行为：

1. 取传入值（`flattenDeep` + 过滤空）；空则用 `dayjs().format('YYYY-MM-DD')`。
2. 计算 `festival`（数组第 3 个元素，即"节中日期"）；若只有一个元素则同时作为节前/节后。
3. 用 `defineFestivalCalendarColumns(year)` 拉出该年度的节日列。
4. 在节日列中找与 `festival` 天数差 `≤ FestivalNum(9)` 的最近节日，按 `diff` + `date` 排序。
5. 若 `useSet=true` 或 `festivalValue` 为空：把 `[festivalDate, beforeDays, afterDays]` 写入 `festivalValue`。
6. 同时把 `festivalYear` 切到对应年。

### 3.6 `currentSubtab` 初始值

始终初始化为 `false`（选区优先）。仅当 `currentTab === 'custom'` 且 `calendarValue` 是数组时，才能切到 `true`（对比区）。

### 3.7 业务侧（`use-calendar-v2.ts`）的初始值

```ts
calendarValue = ref(dayjs().toDate().getTime())   // 今天
calendarTab   = ref('date')
festivalYear  = ref(dayjs().year())
weekAlignValue= ref(true)
```

`onMounted` 还会判断早 7 点前 → `calendarValue = 昨天 0 点`，首页"经营总览"实际查询昨日数据。

---

## 4. 赋值场景（"赋值场景"详细说明）

### 4.1 双向绑定的两种语义

| 方向 | 行为 |
| --- | --- |
| 外 → 内（`props.modelValue` 改变） | 弹层**未打开时**通过 `open()` 内 `setCalendarValue` 同步；**已打开时**仍按 `setCalendarValue` 同步覆盖（注意：会触发 `pickerShow` 内 `pause()` + scrollIntoView） |
| 内 → 外（`calendarValue.set` 触发） | `setValue()` → `emit('update:modelValue', value)` + `emit('confirm', { value, type, tab })`（仅 `onConfirm` 路径） |

> **Web 重构注意**：组件当前实现里**只有 `onConfirm` 路径才向外 `update:modelValue`**；`change` 事件只是 emit 不回写父级。如果 Web 版要"实时双向"，需要在 set 内每次都 emit update，或在 `v-model` 写时区分 `live` / `confirm` 模式。

### 4.2 五种典型赋值场景

#### 场景 1：单元格受控 + 用户点击开 + 选 + 关

```
v-model:modelValue 父级 dayjs().valueOf()
用户点 wd-cell → open() → setCalendarValue(props.modelValue) → 渲染
用户在面板点选 → handleChange → calendarValue.set → 仅 emit('change')
点确认 → handleConfirm → beforeConfirm? → onConfirm → emit('update:modelValue') + emit('confirm') + emit('update:tab')
父级收到新值，更新 props.modelValue
```

#### 场景 2：showConfirm=false → 即时回写

`handleChange` 检测到 `!showConfirm && !confirmBtnDisabled` 时**直接调 `handleConfirm()`**。即每个选择动作都会触发 `update:modelValue`。

#### 场景 3：快捷选项

```ts
async function handleShortcutClick(index) {
  if (props.onShortcutsClick) {
    calendarValue.value = deepClone(props.onShortcutsClick({ item, index }))
  }
  if (!props.showConfirm) await handleConfirm()
}
```

- `onShortcutsClick` 必须返回 `number | number[]`（业务实现里也是返回符合 type 的时间戳）。
- 注意：**返回值不会被 `onShortcutsClick` 内部校验 min/max**，业务方需自己保证。

#### 场景 4：Tab 切换赋值

```ts
handleTypeChange({ index, name }) {
  currentTab = name                              // 同时也会通过 v-model:tab 回写
  if (currentTab !== 'custom') switchSubTab(false)
  handleCalendarRequest(currentTab, { customType, calendarValue }) // 拉取周/节日数据
  if (customType) setColumnsValue(customType)   // customweek/festival 时把滚轮值写回 calendarValue
  pause(250).then(() => handleChange({ value: calendarValue.value }))
}
```

**关键**：每次切 Tab，组件都会**重新拿当前 Tab 的缓存**（互不干扰）；如果缓存为空则显示空面板。

#### 场景 5：左右切换（核心，见 §5）

---

## 5. 左右切换（"边界条件"详细说明）

左右切换是本组件业务侧 (`home-data-dashboard.vue`) 唯一**直接对外可见的操作**（左右两个 `button` 调 `prev/next`），约束最多、最容易踩坑。

### 5.1 入口与状态

```ts
// 业务侧
<button :disabled="calendarV2Ref?.pageTurnStatus.prev" @click.stop="prev">
<button :disabled="calendarV2Ref?.pageTurnStatus.next" @click.stop="next">
```

`pageTurnStatus = { prev: isAllowToggle(-1) === false, next: isAllowToggle(1) === false }`，由 watcher 监听 `[modelValue, currentTab, weekColumns]` 自动计算。

`prev/next` 内部走 `handleCalendarValueToggle(num)`：

```ts
const date = isAllowToggle(num)
if (date === false) return   // 边界
setValue(date)              // 写入并 emit confirm
```

- `setValue` 会 `update:modelValue` + `emit('confirm', { value, type, tab })`，**等于一次完整的 confirm 流程**，会驱动 `month-on-month` 重算对比值。
- 防抖：`toggleState` 250ms 内的 `prev/next` 直接 return。

### 5.2 `isAllowToggle(num)` 三种 Tab 的边界规则

```ts
isAllowToggle(num) {       // num = -1 (prev) 或 1 (next)
  switch (tab) {
    case 'date':  // 单日
      value = props.modelValue ?? Date.now()
      day = dayjs(value)
      date = day.add(num, 'day').format('YYYY-MM-DD')
      info = formatter({ date, calendarType: 'date' })
      return info.disabled ? false : date
    case 'month': // 单月
      value = props.modelValue ?? Date.now()
      day = dayjs(value)
      date = day.startOf('month').add(num, 'month').format('YYYY-MM')
      info = formatter({ date, calendarType: 'date' })   // 注意：calendarType 传 'date'，会按"日"判定 disabled
      return info.disabled ? false : date
    case 'week':  // 业务周
      value = props.modelValue
      if (empty) break                          // 返回 false
      columns = [...weekColumns].reverse()      // ⚠️ 反转！索引 0 = 最近
      if (columns.length === 0) {
        handleWeekCalendarRequest()             // 异步补拉
      }
      fIndex = columns.findIndex(c => c.value === value)
      if (fIndex > -1) {
        find = columns[fIndex - num]            // 关键：-1 时往"更早"找，1 时往"更新"找
        if (find && !formatter({ date: startDate, calendarType: 'week' }).disabled) {
          return find.value
        }
      }
      break                                     // 默认 false
  }
  return false
}
```

> **Web 重构必看**：
> 1. `week` Tab 的 columns 必须**先 `reverse()`**（业务方 `handleCustomWeekRequest` 返回的 list 是按年份升序；`reverse` 后索引 0 = 最新一周）。
> 2. 切换方向计算是 `columns[fIndex - num]`：`num=1`（next）取 `fIndex-1`（更早一周）；`num=-1`（prev）取 `fIndex+1`（更晚一周）—— 即 `next` 是"上一周"，`prev` 是"下一周"（**命名与按钮视觉相反**！这是已知坑）。
> 3. `month` 的边界判定用 `formatter({ date, calendarType: 'date' })` 而非 `'month'`，意图是把"该月 1 号"作为代表日，套用日级别的 min/max 判定。

### 5.3 边界（disabled）的判定细节

`formatter` 根据 `calendarType` 走三条 disabled 路径：

| calendarType | 边界来源 |
| --- | --- |
| `date` / `datetime` / `daterange` / `datetimerange` / `month` | `minDate` / `maxDate`（取自 `props.minDate/maxDate` 或默认值 `今年初-3年 ~ 今天`） |
| `week` | `weekMinDate` / `weekMaxDate`（来自 `typeMap.week.minDate/maxDate` 或全局回退） |
| `festival` | `festivalMinDate` / `festivalMaxDate`（来自 `typeMap.festival.minDate/maxDate` 或全局回退） |
| `custom` + `currentSubtab=true` | 与主选区联动：基于主选区 [0]/[1] 计算可用区间，详见 `formatter` 内 `day.calendarType === 'custom' && day.currentSubtab` 分支 |

**默认值**（`defineMinDate` / `defineMaxDate`）：

- minDate：props 未传时 = `今年初 - 3 年`。
- maxDate：props 未传时 = `今天`。
- `showMinDate/showMaxDate` 永远 = `今年初-3年 ~ 今年末+3年`，是面板**可滚动**范围，与 disabled 无关。

### 5.4 边界情况下的实际行为

| 场景 | 结果 |
| --- | --- |
| `modelValue` 为 `null/undefined` | `date/month` Tab 用 `Date.now()` 兜底；`week` Tab 直接 `break` → `prev/next` 按钮置灰 |
| `modelValue` 是数组 | `flattenDeep` 取第一个非空元素 |
| `week` Tab 但 `weekColumns` 还没拉到 | 自动调 `handleWeekCalendarRequest()`（500ms 防抖），拉完前按钮置灰 |
| `week` Tab 找不到 `value` 对应 column | 返回 `false` |
| `festival` Tab 没有 `customType=festival` | `prev/next` 不在 `isAllowToggle` 中实现 → `pageTurnStatus` 不会被计算该 tab 的状态，业务上 festival 不出现左右键 |
| 250ms 内连点 | `toggleState` 防抖直接 return |
| 切换到 disabled 的下一格 | 按钮置灰，不可点 |

### 5.5 节日（`festival`）的"翻年"边界

`festival` 不通过 `prev/next` 翻页，而是 `month-on-month.vue` 内的"对比年份" `wd-picker` 调 `update:festivalYear` → `useCalendarV2.festivalYear` → `monthOnMonth` 重算对比区间。
`festival` Tab 弹层里也有左右按钮（`handleFestivalTurnYear(±1)`），按年切换并**校验该年是否在 `festivalMinDate/festivalMaxDate` 内**（`disabledYear(year)`）。

### 5.6 `custom` Tab 的对比区边界

`currentSubtab = true` 时 `formatter` 会做：

- `values[2]` 已选但 `values[3]` 未选 → 根据 `values[2] <= values[0]` 或 `> values[1]` 决定是"对比前 N 天"还是"对比后 N 天"。
- 否则 `disabled = isTimeInRange(values[0], values[0], values[1])`（主选区已被选的日子，对比区不可选）。
- 加之 `maxRange: 30`，所以对比区最长 30 天。

---

## 6. 确认（`confirm`）流程细节

```
handleConfirm() {
  // 1) 必选校验
  if (confirmBtnDisabled) {
    if (tab === 'custom' && values.length < 2) {
      // 弹窗问：未选对比区，是否自动用"向前相同天数"
      $message.confirm(...).then(({confirm}) => {
        if (confirm) {
          // 自动算 subcustom = [start-N, start-1]
          customSubValue.value = [Math.abs(diff)+1, 1].map(v =>
            dayjs(values[0]).subtract(v, 'day').toDate().getTime()
          )
        } else return
      })
    } else return
  }
  // 2) beforeConfirm 钩子
  if (beforeConfirm) {
    beforeConfirm({ value, tab, type, customType, resolve })
    resolve(true) → onConfirm() else 不发
  } else {
    onConfirm()
  }
}
onConfirm() {
  pickerShow = false
  lastCurrentType = customType(tab) ?? currentType
  lastTab = tab
  setValue(value)         // emit('update:modelValue') + emit('confirm', { value, type, tab })
  emit('update:tab', tab)
}
```

`defineConfirmBtnStatus` 判定条件（**确认按钮置灰规则**）：

| Tab | 置灰条件 |
| --- | --- |
| 任意 | `value` 为 `null/undefined/[]` |
| `custom` | `flattenDeep(value).filter(Boolean).length < 4` |
| type 含 `range` 或 `custom === 'festival'` | 不是数组 / `!value[0]` / `!value[1]` |

---

## 7. 插槽与扩展点

`wd-calendar-v2.vue` 模板暴露的所有插槽：

| 插槽 | 作用域参数 | 业务用途 |
| --- | --- | --- |
| 默认 (`#default`) | `valueLabel, placeholder, value, modelValue, tab, type, currentSubtab, switchSubTab, calendarV2Props, next, prev, isAllowToggle, pageTurnStatus, open` | **完全替换**内置单元格；首页 `home-data-dashboard` 用它做了"左右键 + 文本"的自定义单元格 |
| `#label` | — | 单元格标题 |
| `#footer` | `value, modelValue, tab, type, currentSubtab, switchSubTab, weekColumns, calendarV2Props, next, prev, open` | 弹层底部追加；首页用它渲染 `month-on-month` 同比/环比 |
| `#confirm-left` / `#confirm-right` | `value, modelValue, tab, type, currentSubtab, switchSubTab, disabled, calendarV2Props, next, prev, open` | 确认按钮左右扩展；首页用它放 `week-align` |
| `#title`（内部 cell 透传） | — | — |

`month-on-month` 自身又会通过 `defineMonthOnMonthValue(value, { tab, isWeekAlign, festivalYear, disabledYear })` 异步算出"对比周/月/日期"，**与日历主选区联动**：

- `date` Tab：`[modelValue-1年, modelValue-1月]` 作为对比。
- `week` Tab：基于 `weekAlign`（是否按业务周对齐）算出上周、上月。
- `month` Tab：`[modelValue-去年同月, modelValue-上月]`。
- `festival` Tab：用户选的"对比年份"决定。
- `custom` Tab：双区间直接来自 `calendarValue` 的后两个元素。

---

## 8. Web 重构实现策略

### 8.1 组件拆分

```
src/components/calendar-v2/
├── CalendarV2.vue              # 壳：tab/弹层/受控值（直接对应源 wd-calendar-v2.vue）
├── CalendarHeader.vue          # title + tabs + shortcuts + close
├── CalendarPanel.vue           # 按 currentTab 渲染分发
│   ├── CalendarDateView        # date / datetime / daterange / datetimerange / dates
│   ├── CalendarMonthView       # month / monthrange
│   ├── CalendarWeekView        # week / weekrange，本地周
│   ├── CalendarCustomWeekView  # customweek = Vant Picker
│   └── CalendarFestivalView    # festival = 三列 Vant Picker
├── CalendarRangeLabel.vue      # showRangeLabel=true 时显示
├── CalendarFooter.vue          # confirm-left/center/right
├── hooks/
│   ├── useCalendar.ts          # 1:1 移植源 useCalendar（缓存/翻页/确认）
│   ├── useCalendarTab.ts       # 1:1 移植源 useCalendarTab（type 解析 + tab 切换）
│   ├── useCalendarWeeks.ts     # 业务周数据请求
│   └── useCalendarFestival.ts  # 节日列定义
├── utils/
│   ├── date.ts                 # dayjs 包装 + 边界计算
│   ├── festival.ts             # 1:1 移植源 festival.ts
│   ├── displayFormat.ts        # 1:1 移植源 defineCalendarDisplayFormat
│   ├── confirmStatus.ts        # defineConfirmBtnStatus
│   └── defaultValue.ts         # defineDefaultFestivalValue
├── types.ts                    # 1:1 翻译源 types.ts
├── __tests__/                  # vitest 单测
│   ├── useCalendar.test.ts
│   ├── useCalendarTab.test.ts
│   └── boundary.test.ts
├── index.ts                    # 对外只暴露 CalendarV2
└── README.md                   # Web 端使用说明
```

> **重要原则**：第一版先 1:1 移植 + 改 API 风格（驼峰、refactor types），**不重写**。等行为等价完成后再考虑拆分。

### 8.2 必须保留的"非显然"行为

1. **每个 Tab 独立缓存值**（`reactive<Record<tab, value>>`）—— 否则切 Tab 会丢用户已选未提交的值。
2. **打开弹层时**：
   - 用 `props.modelValue` 覆盖当前 Tab 缓存（**不要**只读不写）。
   - 备份 `lastTab / lastModelValue`，cancel 时回退。
3. **`prev/next` 等价 `confirm`**：翻页即 `update:modelValue` + `emit('confirm', {value, type, tab})`，**不要**只 emit change 不 emit confirm，否则 `month-on-month` 的"对比值"不会更新。
4. **week Tab 的 `reverse()` + 索引逻辑**保持原样。
5. **festival Tab 不走 `prev/next`**，需独立暴露 `festivalYear` 受控。
6. **custom Tab 4 元素协议**（选区 2 个 + 对比区 2 个）。
7. **beforeConfirm**：resolve 异步 API 需兼容（实现中使用了"resolve 回调"，不是 Promise）。
8. **showConfirm=false**：每次选择都触发 confirm。
9. **onShortcutsClick** 返回值要深拷贝后写入（参考 `deepClone`）。
10. **`immediateChange` / `hideSecond` / `timeFilter` / `defaultTime`** 这一组 datetime 行为要继承自 `wd-calendar-view`，Web 重构时如果有现成 DatePicker 也要支持。

### 8.3 类型与 API 简化建议

- 把 `type` 的对象形态抽成 `CalendarTypeProps<K extends keyof Tabs>` 类型，**所有 Tab 配置项可选**，缺省走组件默认。
- 把 `formatter` 与 `displayFormat` 拆开：`formatter` 管单元格视觉，`displayFormat` 管单元格顶部文本，二者不混用。
- 增加一个**受控的 `page-turn-disabled` 字段**，让业务方可以临时强制禁用左右键（不依赖 `minDate/maxDate`）。

### 8.4 行为对照测试用例（边界）

- `modelValue=null` + `type='date'`：面板展示空、左右键置灰。
- `modelValue=null` + `type='week'`：同上空、`weekColumns=[]` 时应自动拉取。
- `modelValue=null` + `custom`：确认按钮置灰；点确认弹"是否自动选对比区间"提示。
- 切到 `festival` 后 `modelValue` 仍为 number：应通过 `defineDefaultFestivalValue` 选最近节日。
- `prev/next` 在 `week` Tab 跨年：columns reverse 后索引要对，跨年时若 `value` 不在新一年的 columns 应直接 `false`。
- `beforeConfirm` resolve(false) 时不应 emit `update:modelValue`。
- `clear` 按钮：emit 'clear' + emit('update:modelValue', null)，弹层内同时重置。
- `cancel` 关闭：恢复 `lastModelValue[currentTab]`，不重置其他 Tab 缓存。

### 8.5 业务侧（首页）用法快照

```ts
// use-calendar-v2.ts（参考实现）
calendarValue = ref(dayjs().valueOf())
calendarTab   = ref<TypeSwitchTabType>('date')
calendarV2Params = ref<CalendarTypeProps>({
  date:    { showConfirmLeft: true, confirmLeftStyle: { width: '50%' } },
  week:    { custom: true, request: handleCustomWeekRequest, displayFormat: 'YYYY年第WW周', firstDayOfWeek: 4 },
  custom:  { displayFormat: 'MM-DD', maxRange: 30 },
  festival:{ displayFormat: 'MM-DD' },
})

// 左右切换
prev → calendarV2Ref.value?.prev()
next → calendarV2Ref.value?.next()

// 翻页/确认后
handleCalendarV2Confirm({ value, type, tab }) → updateTimeAllData()

// 早 7 点前进入页面
onMounted: if (dayjs().hour() < 7) calendarValue.value = dayjs().subtract(1,'day').startOf('date').valueOf()
```

模板用法（首页 `home-data-dashboard.vue`）：

```vue
<CalendarV2
  ref="calendarV2Ref"
  v-model="calendarValue"
  v-model:tab="calendarTab"
  :type="calendarV2Params"
  show-type-switch
  :with-cell="false"
  :safe-area-inset-bottom="false"
  :z-index="1008"
  @confirm="handleCalendarV2Confirm"
>
  <template #footer="{ tab, value, modelValue, type, currentSubtab, switchSubTab }">
    <MonthOnMonth
      v-model="monthOnMonthValue"
      v-model:festival-year="festivalYear"
      :value="value"
      :model="modelValue"
      :type="type"
      :tab="tab"
      :current-subtab="currentSubtab"
      :switch-sub-tab="switchSubTab"
      :is-week-align="weekAlignValue"
      @weeks-request="handleWeeksRequest"
    />
  </template>
  <template #confirm-left="{ tab, calendarV2Props: props, open }">
    <WeekAlign
      v-if="open && tab === 'date'"
      v-model="weekAlignValue"
      :z-index="props?.zIndex + 1"
    />
  </template>
</CalendarV2>
```

### 8.6 关键技术决策

| 决策 | 选择 | 理由 |
| --- | --- | --- |
| UI 库 | Vant 4 + 自定义 Less | storehub-web 已用 Vant，组件更轻量；不引入 wot-ui 移植版 |
| 日期库 | dayjs（已存在） | 业务侧已用，体积小、API 接近 moment |
| 状态管理 | `reactive<Record<Tab, ModelValue>>`（in-component） | 不引入 Pinia，组件自带状态足够 |
| 弹层 | Vant Popup（bottom） | 比 ActionSheet 灵活，承接 `lazyRender` / `safeAreaInsetBottom` 等 props |
| 单元测试 | vitest + @vue/test-utils | 已在 storehub-web |
| 国际化 | 默认中文，无 i18n 抽象 | 第一版范围；Out of Scope |
| 农历/节日 | 移植源 `festival.ts` 逻辑 | 行为必须一致，源已是经过业务验证的算法 |
| 业务周 | 通过 `request` 注入 + 500ms debounce | 与源一致 |

---

## 9. 一句话回顾

`wd-calendar-v2` = **5 Tab 切换 + 每 Tab 独立缓存 + 左右翻页/快捷/确认三向回写 + festival/custom 双自定义列 + 嵌套 month-on-month 计算对比值**。重构时最关键的是：**每个 Tab 缓存独立、`prev/next` 触发完整 `confirm`、`custom` 4 元素协议、`festival` 跨年不走 `prev/next`、打开时必须用 `props.modelValue` 覆盖当前 Tab 缓存、cancel 时回退到 `lastModelValue` 这六个"非显然"行为**。
