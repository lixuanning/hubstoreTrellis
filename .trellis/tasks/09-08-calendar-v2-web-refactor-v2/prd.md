# CalendarV2 · Web 重构 v2

## Context
v1 实现不可用：
1. tab 是手画 button（不是 van-tabs），切不动且无样式
2. 弹层没复刻 wot-ui `wd-action-sheet` 的 header/body/footer 结构
3. 每个 Tab 时间选择下面功能缺失（festival 翻年 / custom 子 tab / shortcuts / picker change / beforeConfirm / setColumnsValue / 节前节后）
4. 没有 van-button 确认按钮
5. `update:timeAllData` 吐出来的字段混了时间戳，业务字段应该是字符串

## 目标
完全复刻 `storehub-uniapp/src/components/wot-ui/wd-calendar-v2` 的业务行为，把 `wot-ui` 全部换成 `vant`，主入口用 `<van-tabs>` + `<van-popup>` + `<van-button>`，**保持字段格式不变**。

## 字段格式（与旧组件完全一致）

```ts
interface TimeAllData {
  date?:  string | number          // YYYY-MM-DD 或时间戳（内部使用）
  week?:  string | number | null   // YYYY-WW 业务周
  month?: string | number | null   // YYYY-MM
  festival?: [beforeDate, afterDate, date] // 3 元素数组（业务字符串）
  custom?: [mainStart, mainEnd, cmpStart, cmpEnd] // 4 元素数组
}
```

emit 时一律 stringify 成业务字符串，时间戳仅作为内部值使用。

## Constraints
- 完全无 hooks（仅 `<script setup>`，所有逻辑都在主入口文件）
- `v-model:time-all-data` 单数据源
- `v-model:open` 受控开关
- `v-model:tab` 受控 tab
- 5 个 tab 子组件保持现有 API 稳定

## Acceptance
1. vant tabs 可点击切换
2. 弹层头部包含：title / tabs / shortcuts / 关闭按钮
3. 弹层底部包含：range label + 确认按钮（van-button block）
4. festival tab 可翻年，custom tab 可切换选区/对比区
5. emit timeAllData 时不含时间戳（业务字符串）
