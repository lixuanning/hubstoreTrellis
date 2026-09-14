# timeAllData 逐字段对齐研究（web 重构版 vs 小程序旧组件）

> 目的：为「timeAllData 每个字段输出逻辑与旧组件完全一致」提供**权威基准**。本文只做事实沉淀与差异标注，不含实现方案。
>
> 权威基准（旧组件，唯一真源）：
> - `defineTimeDataConfig`：`storehub-uniapp/src/pages-home/hooks/utils.ts` L25-217
> - `defineCalendarDisplayFormat`：`storehub-uniapp/src/components/wot-ui/wd-calendar-v2/utils/defineCalendarDisplayFormat.ts`
> - `defineConfirmBtnStatus`：`storehub-uniapp/src/components/wot-ui/wd-calendar-v2/utils.ts` L132-162
> - `getDateWeek`：`storehub-uniapp/src/utils/util-dayjs.ts` L120-136（基于 `getWeekInfo` L32-111，支持 `startOffset`）
> - 旧组件 confirm 链路：`storehub-uniapp/src/components/wot-ui/wd-calendar-v2/use-calendar.ts`（`handleChange`/`handleConfirm`/`onConfirm`/`setValue`）
>
> 待对齐实现（web 重构版）：
> - `stringifyTimeAllData`：`storehub-web/src/components/calendar-v2/index.vue` L1119-1297
> - 辅助：`computeDayData` L1006-1015、`computeWeekData` L1028-1053、`computeMonthData` L1055-1071、`computeFestivalRange` L1077-1089、`clampToYesterday` L1021-1026、`businessWeekString`/`getYearWeekNumber` L733-743、`syncFromTimeAllData` L766-861

---

## 0. 关键结构性差异（最重要，先看这条）

**旧组件（源）**：所有次级日期字段由**同一个 `day`** 派生。

```ts
// utils.ts L39-68
let values = flattenDeep([params?.value]).filter(v => isString(v) || isNumber(v));
let day = null;
switch (true) {
  case tab === 'festival' && values.length > 2: day = dayjs(values[2]); break; // 节中
  case tab !== 'week' && values.length > 0:      day = dayjs(values[0]); break; // 主值
  case tab === 'week':
  case tab !== 'week' && values.length === 0:    day = dayjs();          break; // 今天
}
const today            = day.format('YYYY-MM-DD');      // → dayData
const monthData        = day.endOf('month').format('YYYY-MM-DD');
const monthDisplayText = day.endOf('month').format('YYYY年MM月');
const { week, year, weekRange } = getDateWeek(tab !== 'week' ? day : undefined, offsetWeek); // offsetWeek=4
const weekData         = weekRange[1];
const weekDisplayText  = `${year}年第${padZero(week)}周`;
config = { dayData: today, weekData, weekDisplayText, monthData, monthDisplayText, timeText: day.format('MM-DD'), ... }
```

⇒ 源保证：**dayData / weekData / monthData / monthDisplayText / timeText 全部围绕「当前 tab 的主值 `day`」自洽**。
例：date tab 选 `2026-09-11` → dayData=`2026-09-11`、weekData=该日所在业务周结束日、monthData=`2026-09-30`。

**web 重构版**：`dayData / weekData / monthData` 分别取自**各自 tab 的缓存** `cacheModel.date / cacheModel.week / cacheModel.month`（L1006-1071 + L1120-1122）。

⇒ 切到 date tab 选日期时，web 的 `weekData/monthData` 仍来自 week/month tab 的缓存（默认值或历史值），**不与选中日期自洽**。这是与源最大的结构性偏差，波及所有 tab。

> ⚠️ 唯一例外：源 `getDateWeek(tab !== 'week' ? day : undefined, ...)` 对 **week tab** 传 `undefined` ⇒ week tab 的 base weekData 是「今天所在周」，随后被 `case 'week'` 用选中周覆盖。其余 tab 均用 `day`。

---

## 1. 字段 × tab 差异总表

图例：✅ 一致 ｜ ❌ 不一致（需修） ｜ ⚠️ 条件性差异 / 待业务确认

| # | 字段 | tab | 源行为 | web 行为 | 判定 |
|---|------|-----|--------|----------|------|
| 1 | `type` | date | `mergeWith(config,{type:'day'})`（L110） | `type: tab` ⇒ `'date'`（L1141） | ❌ |
| 2 | `type` | week/month/custom | `'week'`/`'month'`/`'custom'` | 同 | ✅ |
| 3 | `type` | festival | 归一 `'custom'`（L172） | 归一 `'custom'`（L1154） | ✅ |
| 4 | `isToday` | date | `dayjs().diff(dayData,'day')===0`（L108-112） | `dayjs(dayData).isSame(dayjs(),'day')`（L1125） | ✅ 等价 |
| 5 | `isToday` | week/month | **恒 `false`**（仅 date 分支赋值） | 全局计算，可能为 `true` | ❌ |
| 6 | `isToday` | festival/custom | `false` | festival 显式 `false`（L1158）；custom 走全局计算 | ⚠️ custom 需确认 |
| 7 | `dayData` | date | `dayjs(values[0])` = 选中日 | 同（cacheModel.date） | ✅ |
| 8 | `dayData` | week | `dayjs()` = **今天**（L52-54） | cacheModel.date（当前日缓存） | ❌ |
| 9 | `dayData` | month | `dayjs(values[0])` = 选中月首日 | cacheModel.date | ❌ |
| 10 | `dayData` | custom | `dayjs(values[0])` = **leftBegin** | cacheModel.date（今天） | ❌ |
| 11 | `dayData` | festival | `dayjs(values[2])` = **节中** | `range.center`（L1159） | ✅ |
| 12 | `weekData` | 非 week | `getDateWeek(day,4).weekRange[1]`（选中主值所在周结束） | 取 cacheModel.week（week tab 缓存） | ❌ |
| 13 | `weekData` | week | `case 'week'` 用选中周覆盖 | 由 cacheModel.week 换算 | ⚠️ 换算算法不同，见 §2 |
| 14 | `weekDisplayText` | 非 week | `${year}年第${padZero(week)}周` | 同格式但基于不同日期 | ⚠️ 随 #12 |
| 15 | `weekDisplayText` | week | `find.simpleLabel ?? find.label`（业务周表命中时）；否则 `${year}年第NN周` | 恒 `${year}年第NN周` | ⚠️ 业务周表命中时不一致，见 §2 |
| 16 | `monthData` | 非 month | `day.endOf('month')`（选中主值所在月最后一天） | 取 cacheModel.month 所在月最后一天 | ❌ |
| 17 | `monthData` | month | `day.endOf('month')` | 同（cacheModel.month） | ✅ |
| 18 | `monthDisplayText` | 非 month | `day.endOf('month').format('YYYY年MM月')` | 取 cacheModel.month | ❌ |
| 19 | `timeText` | date | `day.format('MM-DD')` | `dayjs(dayData).format('MM-DD')` | ✅ |
| 20 | `timeText` | week | `[start,end].map(MM.DD).join('-')` ⇒ `MM.DD-MM.DD` | `weekDisplayText`（`YYYY年第NN周`） | ❌ |
| 21 | `timeText` | month | `monthDisplayText`（`YYYY年MM月`） | `monthDisplayText` | ✅ |
| 22 | `timeText` | custom | `[leftBegin,leftEnd].map(MM.DD).join('~')`，**无 guard** | 有 `dates[0] && dates[1]` guard，缺值返 `''` | ⚠️ 缺值场景不同 |
| 23 | `timeText` | festival | 同上 `MM.DD~MM.DD` | 同（L1169-1171） | ✅ |
| 24 | `weekCompare` | all | `apiTimeParams.isWeekAlign`（等于下方 `isWeekAlign`） | `isWeekAlign ?? 0`（L1295） | ✅ |
| 25 | `apiTimeParams.isWeekAlign` | date | `params.isWeekAlign ?? true` ⇒ 默认 `1` | `weekAlignValue`（默认 `true`）⇒ `1` | ✅ |
| 26 | `apiTimeParams.isWeekAlign` | week | 恒 `1` | 恒 `1` | ✅ |
| 27 | `apiTimeParams.isWeekAlign` | month/festival/custom | 恒 `0` | 恒 `0` | ✅ |
| 28 | `apiTimeParams.queryType` | all | date=0 / week=1 / month=2 / custom(festival)=4 | 同 | ✅ |
| 29 | `apiTimeParams.isChoseCustom` | all | date/week/month=0；custom/festival=1 | 同 | ✅ |
| 30 | `apiTimeParams.beginTime` | 非 custom/festival | `undefined` | `undefined` | ✅ |
| 31 | `apiTimeParams.beginTime` | custom | `dates[0]`（leftBegin） | `dates[0]` | ✅ |
| 32 | `apiTimeParams.endTime` | date | = `dayData` | = `dayData` | ✅ |
| 33 | `apiTimeParams.endTime` | week | = clamp 后 `weekData` | 同 | ✅ |
| 34 | `apiTimeParams.endTime` | month | = clamp 后 `monthData` | 同 | ✅ |
| 35 | `apiTimeParams.endTime` | custom/festival | = `leftEnd` / 节日止 | 同 | ✅ |
| 36 | `apiTimeParams.customBeginTime/customEndTime` | 非 custom/festival | `undefined` | `undefined` | ✅ |
| 37 | `apiTimeParams.customBeginTime/customEndTime` | custom/festival | `dates[2]/dates[3]`（对比区） | 同 | ✅ |
| 38 | `customData.leftBegin/leftEnd` | custom | `dates[0]/dates[1]` | `dates[0]/dates[1]` | ✅ |
| 39 | `customData.rightBegin/rightEnd` | custom | `dates[2]/dates[3]` | 同 | ✅ |
| 40 | `customData.showText` | custom | `[leftBegin,leftEnd].map(MM-DD).join('至')`，**无 filter** | 有 `.filter(Boolean)` | ⚠️ 缺值场景不同 |
| 41 | `customData.*` | 非 custom/festival | 全 `undefined` | 全 `undefined` | ✅ |
| 42 | `customData.leftBegin/leftEnd` | festival | 节日起/止 | `range.begin/end` | ✅ |
| 43 | `customData.rightBegin/rightEnd` | festival | 对比年同节日区间 | `compareRange` | ✅ |
| 44 | `customData.showText` | festival | `MM-DD至MM-DD` | 同 | ✅ |
| 45 | week/month clamp | week/month | weekData/monthData > 昨天 ⇒ 昨天 | `clampToYesterday` | ✅ 等价 |
| 46 | `clear` 输出 | — | 无对应（源由父级重置） | `handleClear` 手写对象 | ⚠️ 需与源默认对象比对 |

---

## 2. 需重点关注的次级差异

### 2.1 业务周换算算法（影响 #12/#13/#14/#15）

- 源：`getDateWeek(date, offsetWeek=4)`，基于 `getWeekInfo`（`util-dayjs.ts` L32-111），`startOffset=4`（周四为一周起始，即 ISO 业务周）；week tab 命中业务周表（`defineWeekRequest`）时，`weekData/weekDisplayText/timeText` 全部改用**接口返回的业务周**（`find.endDate / find.simpleLabel ?? find.label / startDate-endDate`）。
- web：`getYearWeekNumber`（L733-737）用 `Math.ceil((ts - startOf('year')) / 7天)` 近似；`computeWeekData`（L1028-1053）再用 `weekNumber*7` 反推日期；无业务周表接入。
- 结论：**算法不等价**（年首周归属、周四起始边界、业务周表命中均不同）。是否必须完全对齐取决于业务周表（`API_HOME_BGYW_LIST`）在 web 侧是否可用 —— 待业务确认。

### 2.2 festival 的 `values` 来源

- 源：`case 'festival'` 中把 `values` 替换为 `flattenDeep(params.values)`（= `monthOnMonthValue`，由 `defineMonthOnMonthValue` 生成，形态为 `[今年节日起, 今年节日止, 对比年节日起, 对比年节日止]`）⇒ `customData` 四项来自它。
- web：`customData` 四项来自 `computeFestivalRange()`（节中±N天）+ `festivalCompareRange`（对比年同节日）。
- 结论：**推导路径不同，结果需逐样本比对**（尤其"节前/节后天数"越界、跨年、对比年缺该节日等边界）。

### 2.3 `syncFromTimeAllData` 的反向解析（回显链路）

- web L839-846 用 `.filter(Boolean)` 提取 `custom`/`subcustom`，会**丢失数组位置语义**：若 `leftEnd` 缺失而 `rightBegin` 有值，位置会前移 ⇒ 与源「按位取值」不一致。
- 建议（待定）：改为按位 `[v[0] ?? null, v[1] ?? null]`。

### 2.4 `next()/prev()` 缺口

- 源：翻页经 `setValue → emit('update:modelValue') + emit('confirm')`，父级 `handleCalendarV2Confirm → updateTimeAllData`，即**翻页后 timeAllData 会被刷新**。
- web（L1725-1751）：翻页仅 `emitChange()`，**不 emit `update:timeAllData`** ⇒ 翻页后 business 对象不刷新。⚠️ 需确认是否对齐。

### 2.5 `customType()` STUB

- 源 `customType(tab)` 支持「对象形态 type」，web `customType()`（L531-535）恒 `undefined`。仅在使用对象 type 时影响 `lastCurrentType`，当前消费方未传 → 低优先级。

---

## 3. 已验证的正确项（无需改动，防回归）

- `queryType` 枚举 0/1/2/4、`isChoseCustom`、`isWeekAlign` 各 tab 取值。
- `endTime` 各 tab 取值与 clamp 到「昨天」。
- `beginTime/customBeginTime/customEndTime` 在 custom/festival 下的取值。
- `customData` 在 custom/festival/其他 tab 下的四项取值与 `showText`。
- `type` 在 week/month/custom/festival 下的取值。
- `weekCompare` = `apiTimeParams.isWeekAlign`。

---

## 4. 自定义回显「请选择」根因（本期已修，留档）

- 现象：festival 回显正确后，custom 入口仍显示 `请选择`。
- 根因：`valueLabel` 的 custom 分支门槛比源 `defineCalendarDisplayFormat` 更严 —— 旧实现 `if (!Array.isArray(c) || c.length < 2) return ''`；而源为 `flattenDeep(...).filter(v => isString(v) || isNumber(v))` 后 **`values.length === 0` 才返 `''`**，`case tab === 'custom': case type === 'festival':` 合并分支只 `slice(0,2).map(...).join(translate('to'))`。
- 触发场景：`CustomTab.scrollToFestival`（`CustomTab.vue` L190-204）emit **单元素** `[date]`；Vant `van-calendar` range 型单点点击也 emit **单元素** `[date]`（`Calendar.mjs` L289-345）⇒ 单值场景被渲染为空 ⇒ 回落 `constants.ts` 的 `DEFAULT_PLACEHOLDER = '请选择'`。
- 修复：`index.vue` L1600-1610 改为 `flattenValue(cacheModel.custom)` → `length === 0` 才返 `''` → `slice(0,2).map(MM-DD).join('至')`，与源语义一致。
- 验证：`npx vue-tsc --noEmit -p tsconfig.app.json` 退出码 0。

---

## 5. 参考：源 `defineConfirmBtnStatus`（确认按钮门槛，勿改动语义）

```ts
value = flattenDeep(isArray(value) ? value : [value]).filter(Boolean);
switch (true) {
  case value === null || value === undefined:
  case isArray(value) && value.length === 0: return true;      // 空 ⇒ 置灰
  case tab === 'custom': return isArray(value) ? value.filter(Boolean).length < 4 : true;
  case custom === 'festival':
  case type.includes('range'): return !isArray(value) || !value[0] || !value[1] || !value;
}
return false;
```
