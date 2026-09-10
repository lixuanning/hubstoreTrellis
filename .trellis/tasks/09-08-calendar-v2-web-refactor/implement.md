# wd-calendar-v2 Web 重构 — 执行计划

**任务**: 09-08-calendar-v2-web-refactor
**父任务**: 09-08-calendar-v2-web-refactor（本任务，只承载规格与计划）
**依赖**: 父任务用户确认 → 子任务 A → 子任务 B

---

## 0. 完成定义（DoD）

- [ ] `prd.md` + `design.md` + `implement.md` 都已 review 通过
- [ ] 子任务 A：组件源码 + 单测 + `pnpm lint`/`type-check`/`test` 全过
- [ ] 子任务 B：业务 demo 页面 + 浏览器手动验证 + `pnpm lint`/`type-check` 过
- [ ] 父任务 archive + journal

---

## 1. Task 树

```
09-08-calendar-v2-web-refactor (parent, planning)
├── 09-08-...-component  (child A, implementation)
└── 09-08-...-dashboard  (child B, implementation, depends on A)
```

**A → B 依赖**：A 完成且 `pnpm test` 全部通过后，才能启 B。理由：B 的 `data-dashboard.vue` 必须基于 A 提供的 CalendarV2 组件。

---

## 2. 子任务 A：组件实现（09-08-...-component）

### 2.1 范围

- 在 `storehub-web/src/components/calendar-v2/` 下实现 1:1 等价组件
- 1:1 移植源 `useCalendar` / `useCalendarTab` / `festival` / `default-value` / `displayFormat` 等 hooks/utils
- 写 vitest 单测覆盖核心行为
- 写 README

### 2.2 拆分步骤（按顺序）

1. **A1. 脚手架**（30min）
   - 创建 `src/components/calendar-v2/` 目录
   - 写 `types.ts`（1:1 翻译源 `types.ts`）
   - 写 `utils/date.ts`（dayjs 包装 + 边界计算）
   - 跑 `pnpm test` 确认基础工程 OK

2. **A2. types + utils**（1h）
   - 移植 `utils/confirmStatus.ts`（`defineConfirmBtnStatus`）
   - 移植 `utils/displayFormat.ts`（`defineCalendarDisplayFormat`）
   - 移植 `utils/defaultValue.ts`（`defineDefaultFestivalValue`）
   - 移植 `utils/festival.ts`（`defineFestivalCalendarColumns`）
   - 单测：边界（min/max、format、disabled）

3. **A3. hooks：useCalendarTab**（1h）
   - 移植源 `useCalendarTab.ts`
   - 改名驼峰：API 完全等价
   - 单测：type 双形态、tab 切换、visible 兜底

4. **A4. hooks：useCalendar**（2h）
   - 移植源 `useCalendar.ts`
   - 保留 6 个"非显然"行为（见 `design.md` §8.2）
   - 单测：prev/next 三 Tab 边界、festival 翻年、custom 4 元素、cancel 回退、beforeConfirm

5. **A5. 子组件**（2h）
   - `CalendarDateView`（date/dates/datetime/daterange/datetimerange）
   - `CalendarMonthView`（month/monthrange）
   - `CalendarWeekView`（week/weekrange，本地周）
   - `CalendarCustomWeekView`（Vant Picker 三列）
   - `CalendarFestivalView`（Vant Picker 三列 + 翻年按钮）
   - 复用源组件 `wd-calendar-view` 的渲染逻辑（用 Vant 替换 wot-ui）

6. **A6. CalendarV2 主壳**（1.5h）
   - 单元格（withCell=true）+ 弹层（Popup）
   - 头部（title + tabs + shortcuts + close）
   - 底部（confirm-left/center/right + 范围 label）
   - 6 个插槽全部暴露
   - `defineExpose` 全部方法
   - 接入 `useCalendar` / `useCalendarTab`

7. **A7. 视觉对齐**（1h）
   - 用 Less + BEM 命名
   - 与源组件截图对比，校验 cell / 弹层 / 按钮 / 翻页按钮视觉一致
   - 字号 / 间距 / 圆角按 750 设计稿（storehub-web 规范）

8. **A8. 单元测试**（1.5h）
   - 写 vitest + @vue/test-utils 测试
   - 覆盖 §2.4 行为对照测试用例
   - 覆盖率 > 80%

9. **A9. README + 验收**（0.5h）
   - 写 `README.md`：用法、API 列表、与源组件差异
   - 跑 `pnpm lint` / `pnpm type-check` / `pnpm test`
   - 用 vitest UI 跑一遍
   - 提一个 commit（commit message：`feat(storehub-web): add CalendarV2 component (1:1 port of uniapp wd-calendar-v2)`）

### 2.3 验收

- [ ] 所有 6 个"非显然"行为在单测中明确覆盖
- [ ] `pnpm lint` / `pnpm type-check` / `pnpm test` 全过
- [ ] 单元测试覆盖率 > 80%
- [ ] `pnpm build` 通过
- [ ] 浏览器手动验证：5 Tab + 翻页 + custom 4 元素 + festival 翻年 + beforeConfirm

---

## 3. 子任务 B：业务接入（09-08-...-dashboard）

### 3.1 范围

- 在 `storehub-web/src/views/home/data-dashboard/` 实现等价首页 demo
- 1:1 移植 `month-on-month.vue`（同比/环比/对比值）
- 写 `use-calendar-v2.ts`（hooks 封装）
- 跑通首页"经营总览"在 web 子应用下的全链路

### 3.2 拆分步骤（按顺序）

1. **B1. hooks**（1.5h）
   - 写 `hooks/use-calendar-v2.ts`：1:1 移植源 `use-calendar-v2.ts`
   - 改名驼峰、保留 4 个 Hook（`updateTimeAllData` / `handleCustomWeekRequest` / `handleCalendarV2Confirm` / `defineLastCalendarQuery`）
   - 注意：业务周 `request` 走 `api/modules/calendar.ts`（storehub-web 2-tier 规范）

2. **B2. 子组件**（1.5h）
   - 写 `components/MonthOnMonth.vue`：1:1 移植源 `month-on-month.vue`
   - 写 `components/WeekAlign.vue`：1:1 移植源 `week-align.vue`
   - 写 `components/StoreList.vue`：1:1 移植（首页顶部门店切换）

3. **B3. data-dashboard.vue 主页**（2h）
   - 1:1 移植源 `home-data-dashboard.vue`
   - 替换 uniapp 特有的 `ConfigProvider` / `FooterBackground` 为 web 端等价物
   - 早 7 点回退昨日逻辑保留
   - `dataType`（累计/店日均）切换保留
   - 翻页 / 同比 / 环比 / 周对齐 / 节日对比年份 全部保留

4. **B4. 路由 + 入口**（0.5h）
   - 在 `router/modules/home.ts` 加 `/data-dashboard` 路由
   - 入口能直接访问该页面

5. **B5. 浏览器验证**（1h）
   - 手动点一遍：
     - 5 Tab 切换
     - prev/next 翻页（确认按钮置灰行为）
     - week 翻页（确认 `next` 取更早一周）
     - festival 翻年
     - custom 4 元素 + 自动对比提示
     - 早 7 点前进入页面看回退昨日
     - `weekAlign` 开关
     - `festivalYear` 选对比年份
   - 与 uniapp 端截图对比（视觉一致性）

6. **B6. 验收**（0.5h）
   - 跑 `pnpm lint` / `pnpm type-check`
   - 提 commit（`feat(storehub-web): port home data-dashboard to use new CalendarV2`）

### 3.3 验收

- [ ] 5 Tab + 翻页 + 同比/环比 + 周对齐 + 节日对比年份 全部工作
- [ ] 早 7 点前回退昨日
- [ ] `pnpm lint` / `pnpm type-check` 全过
- [ ] 浏览器手动验证清单全过
- [ ] 与源组件截图对比基本一致

---

## 4. 父子任务交付

### 4.1 父任务（本任务）

- 交付物：
  - `prd.md`（已完成）
  - `design.md`（已完成）
  - `implement.md`（本文件，已完成）
  - `implement.jsonl` / `check.jsonl`（已配置）
- 验收：用户 review 通过 + 触发子任务创建

### 4.2 子任务 A（必须先 start）

- 创建时机：父任务 confirm 后
- 命令：
  ```bash
  python3 .trellis/scripts/task.py create "wd-calendar-v2 Web 组件实现" \
    --slug calendar-v2-web-component \
    --parent .trellis/tasks/09-08-calendar-v2-web-refactor \
    --package storehub-web \
    --assignee lidie \
    --priority P1
  ```
- 拷贝 prd 片段 + design §1-§8 + 本 implement §2

### 4.3 子任务 B（依赖 A）

- 创建时机：子任务 A archive 后
- 命令：
  ```bash
  python3 .trellis/scripts/task.py create "wd-calendar-v2 业务接入（home data-dashboard）" \
    --slug calendar-v2-web-dashboard \
    --parent .trellis/tasks/09-08-calendar-v2-web-refactor \
    --package storehub-web \
    --assignee lidie \
    --priority P2
  ```
- 拷贝 prd F2 + design §8.5 + 本 implement §3

---

## 5. 风险与回滚

| 风险 | 概率 | 影响 | 缓解 |
| --- | --- | --- | --- |
| 源组件行为逆向不全 | 中 | 大 | 1:1 移植 + 行为对照单测 |
| Vant 弹层/选择器与源行为不一致 | 高 | 中 | 优先功能等价，UI 视觉可优化 |
| 业务周 columns 拉取在 web 端接口不匹配 | 中 | 大 | 子任务 A 中提前验证 API 对接 |
| 农历/节日计算移植出错 | 低 | 中 | 1:1 移植 `festival.ts`，单测覆盖 |
| 4 元素 custom 协议搞错 | 中 | 大 | 单测 + 业务 demo 双重验证 |

**回滚点**：
- 阶段 1 失败：仅丢弃子任务 A 实现，父任务保留（设计沉淀）
- 阶段 2 失败：仅回滚子任务 B 实现，A 保留
- 任一阶段发现"行为不可等价"：先回 prd 修订、再 re-implement

---

## 6. 进度跟踪

| 阶段 | 状态 | 备注 |
| --- | --- | --- |
| 父任务 PRD | ✅ 完成 | prd.md |
| 父任务 design | ✅ 完成 | design.md（含组件规格书） |
| 父任务 implement | ✅ 完成 | implement.md |
| 父任务用户 review | ⏳ 待确认 | 见下方"等待用户确认" |
| 子任务 A create | ⏸ 阻塞 | 父任务确认后 |
| 子任务 A start | ⏸ 阻塞 | review 完 |
| 子任务 A 实现 | ⏸ 阻塞 | — |
| 子任务 A archive | ⏸ 阻塞 | — |
| 子任务 B create | ⏸ 阻塞 | A archive |
| 子任务 B 实现 | ⏸ 阻塞 | — |
| 子任务 B archive | ⏸ 阻塞 | — |
| 父任务 archive | ⏸ 阻塞 | B archive |

---

## 7. 等待用户确认

> 父任务的规格与计划已就位。请你 review 一下：
> - **PRD §3**（功能/非功能/约束/验收标准）
> - **design.md §8.1-§8.6**（Web 重构实现策略、组件拆分、关键决策）
> - **implement.md §1-§4**（任务拆分、A/B 依赖、DoD）
>
> 如果 OK，请回复"确认"或"开始 A"，我就创建子任务 A 并启动 `trellis-implement`。
> 如需调整，直接说哪一节要改。
