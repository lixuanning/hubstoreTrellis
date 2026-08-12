# Frontend Development Guidelines — storehub-uniapp

> **Pre-read (必须先读)**:
> 1. [Architecture Overview](../../guides/architecture-overview.md) — 系统架构
> 2. [Project Rules](../../../../storehub-uniapp/.trae/rules/project_rules.md) — **本项目的专属规则**（含禁止 dev/build、跨端条件编译、wot-ui 用法等）
>
> UniApp + Vue 3 enterprise WeChat miniapp (primary) + H5.

---

## Overview

**Package**: `storehub-uniapp`  
**Framework**: UniApp 3.x + Vue 3 + TypeScript 5.x + Vite  
**UI Library**: wot-ui (wot-design-uni)  
**HTTP Client**: alova  
**State**: Pinia  
**Style Unit**: rpx (odd numbers round UP to even)

---

## Key Conventions

### ⚠️ NEVER run dev/build commands

Project has HMR — do NOT auto-run `yarn dev` or `yarn build` unless explicitly asked. **详见 project_rules.md。**

### ⚠️ TabBar 安全区（最终版 v2，2026-08-11 修复沉淀）

本项目 uniapp 配置了 5 个原生 TabBar（首页/任务/工作台/消息/个人中心，见 `pages.json`），**MP-WEIXIN 和 H5 都有 TabBar 占位**。任何 **fixed 定位的浮动元素（按钮、弹窗、操作栏）必须考虑这个区域，且 H5 的 TabBar z-index 可能高于 popup 组件层级。

#### ⚠️⚠️⚠️ 核心根因（Pitfall）

1. **`wd-popup position="bottom"` 强制 `bottom: 0`**：组件内部写死对齐屏幕最底部，`:style` 传的 `bottom` 会被覆盖。
2. **`safe-area-inset-bottom` 只处理 iPhone 底部横条**：（通过 `uni.getSystemInfoSync().safeAreaInsets.bottom`），**不处理 TabBar 高度**——别指望开这个属性就能避开 TabBar。
3. **数学计算要统一**：`height: calc(70vh - 200rpx)` 再 `padding-bottom: 200rpx` = 留白 400rpx → 空太多。只能选一次！

#### ✅ 标准方案（参考项目 `filter-condition-pop.vue` 等范例）

**分两部分，互不叠加：**

| 层级 | 设置 | 作用 |
|------|------|------|
| wd-popup 外层 | `safe-area-inset-bottom`（开 true） + `height: '70vh'` 或 `80%`（**不减 TabBar**） | 处理 iPhone 底部黑条；高度用百分比/viewport 即可 |
| popup 内容根容器（你的第一个 view） | `box-sizing: border-box; padding-bottom: 110rpx;` | 处理 TabBar 高度；TabBar ≈ 100rpx + 10rpx 余量 = 110rpx |
| 浮动按钮（fixed 元素，非 popup 内部） | `position: fixed; bottom: 200rpx` | 单独写，与 popup 计算无关 |

```scss
// ✅ 推荐: 浮动按钮 (独立 fixed 元素)
.ai-robot-entry {
  position: fixed;
  right: 40rpx;
  bottom: 200rpx;
  z-index: 9998;
}

// ✅ 推荐: 底部 popup —— 参考 filter-condition-pop 写法
<wd-popup
  v-model="visible"
  position="bottom"
  safe-area-inset-bottom    <!-- 🔴 必须开：处理 iPhone 底部黑条（wd-popup.vue:167） -->
  :style="{
    height: '70vh',          <!-- 🔴 height 直接写，不再减 TabBar -->
    borderRadius: '24rpx 24rpx 0 0',
  }"
>
  <view class="chat-container">
    ...
    <view class="chat-input-bar">输入框</view>
  </view>
</wd-popup>

<style scoped>
.chat-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;   /* padding 不撑爆 height:100% */
  padding-bottom: 110rpx;  /* 🔴 只留 TabBar 高度 110rpx，不要 200rpx，不要叠加 height 减 */
}
</style>
```

#### ❌ 已踩过的坑（禁止再犯）

| 方案 | 为什么失败 |
|------|-----------|
| `:style="{ bottom: '200rpx' }"` 写在 wd-popup 上 | 组件内部强制覆盖为 `bottom: 0` |
| `height: calc(70vh - 200rpx)` + `padding-bottom: 200rpx` | 留白 400rpx，内容跑太上面，空太多 |
| `bottom: 0` + `marginBottom: 200rpx` | marginBottom 不影响 fixed 定位基点 |
| 条件编译 `#ifdef H5` 去掉 bottom | 本项目 H5 也有 TabBar，反而更严重 |
| 以为 `safe-area-inset-bottom=true` 会处理 TabBar | 它只处理系统安全区（iPhone 横条 ~34px），TabBar 是 uniapp 画的 |
| 假定 tabBar = 50px / 100rpx / 200rpx | 5 个图标约 100rpx，再加 padding ≈ 110rpx，200rpx 空太多 |

**自检清单**：
- [ ] 查 `pages.json` 的 `tabBar.list` 数量（本项目 5 个）
- [ ] wd-popup 是否开了 `safe-area-inset-bottom`
- [ ] wd-popup height 是否直接写（未减 TabBar 高度）
- [ ] 内容根容器 padding-bottom 是否为 110rpx 左右，未叠加
- [ ] H5 热更新 + 小程序打包双端验证

### API Call Pattern — 3-Tier (不可跳层)

```
src/api/
├── apis/home.ts        ← Tier 1: Path constants   API_HOME_XXX = '/home/xxx'
├── service/homeService.ts  ← Tier 2: Service fcns    export async fn() { alova.Post(API) }
└── index.ts            ← alova instance
```

**Pages MUST import from `service/`, NEVER inline `alova.Post()` or import from `apis/` directly.**

### Component Pattern
- Prefer wot-ui components over reinventing
- Use Vue 3 Composition API (`<script setup lang="ts">`)
- Conditional compilation: `// #ifdef H5` / `// #ifdef MP-WEIXIN`

### Platform Detection
```ts
import { PLATFORM } from '@/config';  // UNI_PLATFORM
```

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Page/module organization | To fill |
| [Component Guidelines](./component-guidelines.md) | wot-ui + custom component patterns | To fill |
| [Hook Guidelines](./hook-guidelines.md) | Custom hooks patterns | To fill |
| [State Management](./state-management.md) | Pinia store patterns | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, ESLint | To fill |
| [Type Safety](./type-safety.md) | TypeScript strictness | To fill |
