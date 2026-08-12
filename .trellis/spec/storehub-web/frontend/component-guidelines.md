# storehub-web — 组件指南

## 规范

- `<script setup lang="ts">` + `<style lang="less" scoped>` 标准 Vue 3 SFC
- 样式使用 Less + scoped

## 组件模式

```vue
<script setup lang="ts">
import store from '@/store/userInfoStore'; // 直接导入对象（非 defineStore 写法）
import { usedailyClearingInfoStore } from '@/store/dailyClearing'; // defineStore 写法

const { userCurrentRole } = store; // 直接解构
const { $store, fetchData } = usedailyClearingInfoStore();
</script>
```

## 样式约定

- **BEM 命名**：`&__element` / `&--modifier`
- **Scoped**：`<style lang="less" scoped>`
- **Vant + PagodaMobile**：自动导入（unplugin），直接用不需要 import
- **双端适配**：postcss-px-to-viewport-8-plugin 双 viewport 配置
  - Vant/PagodaMobile 库组件：375 设计稿
  - src/ 业务代码：750 设计稿
  - PC 页面（`universal/` 路径）：`selectorBlackList: ['pc', 'universal']` 不转换 px

## 新增组件时

1. 放对应 `views/<模块>/components/` 下
2. 使用 `<script setup>`
3. 导入 store 而非自己重写
