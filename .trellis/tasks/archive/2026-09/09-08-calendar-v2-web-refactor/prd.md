# wd-calendar-v2 Web 重构

**任务**: 09-08-calendar-v2-web-refactor
**状态**: planning
**类型**: 复杂 (PRD + design + implement)
**目标包**: storehub-web
**源组件**: `storehub-uniapp/src/components/wot-ui/wd-calendar-v2/`

---

## 1. 背景

- `wd-calendar-v2` 是 storehub-uniapp 端的**企业微信小程序核心日期选择器**，首页（`home-data-dashboard.vue`）"经营总览"模块 100% 依赖它做日/周/月/节日/自定义 5 维度切换 + 左右翻页 + 同比环比联动。
- storehub-web（Vue 3 + Vant + Vite）作为 H5 子应用通过 webview 嵌入企业微信小程序，目前**没有等价组件**，导致 webview 内嵌页面只能用降级方案或绕开日期筛选。
- 业务方诉求：把 `wd-calendar-v2` 的能力**等价**迁移到 web，使得 uniapp 端切到 web 子应用时日期选择体验**完全一致**（同 Tab、同翻页、同回显、同对比值联动）。

### 1.1 源组件能力（详见 `design.md` §1-§7）

- **5 Tab**：`date` / `week`（业务周） / `month` / `festival`（节日 + 节前/后 N 天） / `custom`（双区间）
- **每 Tab 独立缓存值**（关闭不丢值）
- **左右翻页**（`prev/next` ≡ 一次完整 `confirm`）
- **`type` 双形态**（string 共享 / object 粒度配置）
- **快捷选项 / 自定义 formatter / beforeConfirm / displayFormat / innerDisplayFormat**
- **festival 翻年**（不走 prev/next）
- **custom 4 元素协议**（选区 + 对比区）
- **6 个插槽**（默认/label/footer/confirm-left/confirm-right/title）

### 1.2 已知坑（必须保留的行为）

1. `week` Tab 的 columns 必须 `reverse()`，**索引语义与按钮相反**：`next`（num=1）取更早一周、`prev`（num=-1）取更晚一周。
2. `prev/next` 会触发完整 `update:modelValue` + `confirm`，**驱动 `month-on-month` 重算对比值**。
3. `festival` 走独立 `festivalYear` 翻年（不通过 prev/next）。
4. 打开弹层时**用 props.modelValue 覆盖当前 Tab 缓存** + 备份快照，cancel 时回退。
5. `custom` 4 元素协议（`values[0..1]` 主选区、`values[2..3]` 对比区）。
6. `month` 的 disabled 判定用 `calendarType:'date'`（按"该月 1 号"作为代表日）。

---

## 2. Goal

把 `wd-calendar-v2` 的 5 Tab + 翻页 + 缓存 + 联动能力**等价**实现在 `storehub-web` 包下，对外暴露同名（等价）API，承接 storehub-uniapp 侧"未来切到 web 子应用"的迁移需求。

---

## 3. Requirements

### 3.1 功能需求

#### F1. Web 端 `CalendarV2` 组件

- F1.1 暴露 props：`v-model`（modelValue）、`v-model:tab`、`v-model:open`、`type`、`minDate` / `maxDate`、`firstDayOfWeek`、`formatter`、`maxRange`、`allowSameDay`、`defaultTime`、`timeFilter`、`hideSecond`、`label` / `placeholder` / `title`、`disabled` / `readonly`、`showConfirm`、`confirmText`、`displayFormat`、`innerDisplayFormat`、`showTypeSwitch`、`shortcuts`、`onShortcutsClick`、`closeOnClickModal`、`safeAreaInsetBottom`、`beforeConfirm`、`showRangeLabel`、`showConfirmLeft` / `showConfirmRight`、`confirmLeftStyle` / `confirmRightStyle`、`withCell`、`lazyRender`、`clearable`、`markerSide`、`customClass` / `customLabelClass` / `customValueClass` / `customStyle`。
- F1.2 暴露事件：`update:modelValue` / `update:tab` / `update:open` / `update:endDate` / `confirm` / `change` / `cancel` / `open` / `clear`。
- F1.3 暴露方法（`defineExpose`）：`close` / `open` / `toggle` / `next` / `prev` / `isAllowToggle` / `pageTurnStatus` / `switchSubTab` / `valueLabel` / `formatCalendarLabel` / `weekCalendarRequest` / `pickerShow`。
- F1.4 5 Tab 全部支持：`date` / `week` / `month` / `festival` / `custom`。
- F1.5 8 种 `type`：`date` / `dates` / `datetime` / `week` / `month` / `daterange` / `datetimerange` / `weekrange` / `monthrange`，以及 `customXxx` 自定义列。
- F1.6 6 个插槽：`default` / `label` / `footer` / `confirm-left` / `confirm-right` / `title`。
- F1.7 `type` 双形态：`string` 全局共享 / `object` 每 Tab 粒度。
- F1.8 `prev/next` 翻页 + `pageTurnStatus` 禁用态 + `isAllowToggle` 判定。
- F1.9 业务周（`week`）支持远端 `request` 注入 + 500ms 防抖。
- F1.10 节日（`festival`）三列滚轮（节中 / 节前 N / 节后 N，N ≤ 9）+ 翻年按钮。
- F1.11 自定义（`custom`）双区间 + 自动对比值（4 元素协议）。
- F1.12 单元格（`withCell=true` 时显示）+ 清除按钮 + 箭头按钮。
- F1.13 弹层（action-sheet） + 标题 + tabs + 快捷选项 + 关闭按钮 + 确认/取消按钮。

#### F2. 业务侧（`home-data-dashboard`）接入

- F2.1 storehub-web 子应用内能**等价**复用首页"经营总览"的 5 Tab 切换 + 翻页 + 对比值联动。
- F2.2 `month-on-month`（同比/环比/对比值）计算结果与 storehub-uniapp 一致（包括早 7 点回退昨日、`weekAlign` 业务周对齐、`festivalYear` 选对比年份、`custom` 4 元素协议）。

#### F3. 测试 / 验收

- F3.1 单测覆盖：5 Tab 缓存独立性、prev/next 边界（含 `week` reverse 索引）、festival 跨年、custom 4 元素、cancel 回退、beforeConfirm 异步 resolve、`showConfirm=false` 即时回写。
- F3.2 与源组件行为对照清单（详见 `design.md` §8.4）：每个用例都跑通两侧（uniapp 端现状 vs web 端新实现）。

### 3.2 非功能需求

- 行为等价（contract-equivalent）：与源组件在所有受控 props / 事件 / 翻页 / 缓存 / 联动 / 边界上**完全等价**。
- 类型安全：所有 props / 事件 / ref 必须有 TypeScript 类型，不允许 `any`。
- 可测试：核心 hook（`useCalendar` / `useCalendarTab`）可独立单测，不依赖弹层 DOM。
- 体积：单个组件拆目录后入口 bundle < 80KB（gzip）。
- 性能：翻页 250ms 防抖；打开弹层首次渲染 < 100ms（本地）。
- 兼容性：Vue 3.4+，TypeScript 5.x，Vite 5+。

### 3.3 约束

- C1：实现必须在 `storehub-web` 包下（`src/components/calendar-v2/`），不污染 storehub-uniapp。
- C2：保持 3 个 package 解耦：组件本身不直接 import 任何 storehub-uniapp 模块（如 `use-calendar-weeks`、`month-on-month` 业务封装）—— 业务封装在 web 侧重新写。
- C3：UI 库用 Vant 4 + 自定义 Less（不引入 wot-ui 移植版）。
- C4：不引入新依赖，除非必要（如日期库 dayjs 已存在；如需农历/节日计算可复用 `@/utils/chinese-days` 等价物）。
- C5：业务周数据源在 web 端走 `api/modules/calendar.ts`（按 storehub-web 的 2-tier API 规范），不允许跨包 import。

### 3.4 验收标准（Acceptance Criteria）

#### 组件层
- [ ] 5 Tab 全部可正常切换，每个 Tab 独立缓存值，关闭弹层不丢值
- [ ] `prev/next` 在 `date` / `month` / `week` 三个 Tab 都按文档边界规则禁用/启用
- [ ] `week` Tab 的翻页索引语义与源组件**完全一致**（`next` 取更早一周）
- [ ] `week` Tab `columns=[]` 时自动调 `request` 拉取（500ms 防抖）
- [ ] `festival` Tab 三列滚轮可独立翻年（不走 prev/next）
- [ ] `custom` Tab 主选区选完，对比区联动启用；未选对比区点确认弹"自动向前 N 天"提示
- [ ] `type=string` 与 `type=object` 两种形态都工作
- [ ] `beforeConfirm({ resolve })` 异步 resolve API 兼容
- [ ] `showConfirm=false` 时选择即触发 `update:modelValue` + `confirm`
- [ ] 6 个插槽全部接受对应作用域参数
- [ ] 单元格/弹层/快捷/确认按钮/清除按钮 视觉与交互一致
- [ ] 翻页时若目标日期 disabled，按钮置灰不可点
- [ ] 关闭弹层（cancel）回退到 `lastModelValue` / `lastTab`
- [ ] `clearable=true` 时显示清除按钮，点击 emit `clear` + `update:modelValue=null`

#### 业务层
- [ ] storehub-web 内有一个等价首页 demo 页面（`views/home/data-dashboard.vue`），5 Tab + 翻页 + 同比环比 + 周对齐开关全部工作
- [ ] 早 7 点前进入页面回退昨日（与 uniapp 一致）
- [ ] `weekAlign` 切换会重算 `month-on-month` 对比值
- [ ] `festivalYear` 切换重算 `month-on-month` 对比值

#### 工程
- [ ] 通过 `pnpm lint` / `pnpm type-check` / `pnpm test`（三件套）
- [ ] 单元测试覆盖率 > 80%
- [ ] 没有 `any` 类型泄漏（用 `unknown` + 类型守卫代替）
- [ ] 组件 + 业务封装在 `storehub-web/src/components/calendar-v2/` 与 `storehub-web/src/views/home/data-dashboard/` 目录规范
- [ ] README + JSDoc 关键函数有注释

---

## 4. Task 拆分（parent / child）

> 父任务只承载规格与计划；**实现交付物拆 2 个独立可验证的子任务**。

### 4.1 父任务（09-08-calendar-v2-web-refactor，本任务）

- 输出：PRD（本文档） + design（组件规格） + implement（执行计划）
- 验收：用户确认 PRD + design + implement

### 4.2 子任务 A：组件实现（09-08-...-component）

- 交付：storehub-web `src/components/calendar-v2/` 全部源码 + 单测
- 验收：组件层所有 AC 通过 + lint/type-check/test 通过

### 4.3 子任务 B：业务接入（09-08-...-dashboard）

- 交付：storehub-web `src/views/home/data-dashboard/` 等价首页 + 业务封装
- 验收：业务层所有 AC 通过 + lint/type-check 通过 + 浏览器手动验证

> 任务 A 完成后才能启动任务 B（依赖关系在子任务 implement.md 中显式声明）。

---

## 5. Out of Scope

- storehub-uniapp 侧 `wd-calendar-v2` 组件**本身**的代码修改（不重构源，只做等价迁移）。
- storehub-uniapp `home-data-dashboard.vue` 切到 web 组件的迁移（属于"业务切换"，是后续另一个独立任务；本次只在 storehub-web 侧做等价 demo）。
- web 端 `month-on-month` 的视觉/动效细化（先功能等价，再做体验优化）。
- 农历 / 节日计算在 web 端的从零实现（web 端**复用** `getFestivalName` / `getYearFestivals` 等工具的等价封装或外部库；如缺则在子任务 A 中新建 utils）。
- 节日区间列的 i18n（默认中文）。

---

## 6. Notes

- 源组件的内部实现非常复杂（含 reactive 缓存 + watcher 链路 + 异步 request + 节日列缓存），重构建议**先 1:1 移植 + 改命名风格 + 改 API 风格**，再考虑 web 端习惯的拆分（如把 hook 拆成 `useCalendarTabs` / `useCalendarValue` / `useCalendarEvents`）。功能等价优先，**禁止**在第一版"顺手优化"导致行为偏差。
- `week` Tab 翻页的索引反向行为是**源组件的"已知坑"**，见 `design.md` §5.2 —— 移植时必须保留，**不要"修正"**（除非业务方明确要求改）。
- 节日 / 业务周列的远端拉取（`request`）是异步入口，500ms 防抖。web 端需用 lodash.debounce 或自实现。
- `beforeConfirm` 用 `resolve` 回调而非 Promise —— **保持兼容**。
- `showRangeLabel` / `innerDisplayFormat` 仅在 `type` 含 `range` 时生效。
- `month-on-month` 在 web 端**整体移植**到 `src/views/home/components/MonthOnMonth.vue`（不与组件库耦合）。

---

## 7. 自检记录

> 占位：实现阶段填充。
