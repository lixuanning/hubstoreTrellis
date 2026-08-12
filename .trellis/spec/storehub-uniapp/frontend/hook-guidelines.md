# storehub-uniapp — 组合式函数/Hook 指南

## Hook 文件位置

`src/hooks/` — 集中管理，按功能命名。

| Hook | 用途 |
|------|------|
| `use-uni-app.ts` | 生命周期包装（注入登录守卫 `afterLoginHook`） |
| `use-user-role.ts` | Pinia 用户角色 store 封装 |
| `use-calendar-weeks.ts` | 业务周查询 + 缓存 |
| `use-message.ts` | 消息已读跟踪 |
| `use-zIndex.ts` | provide/inject z-index 栈管理 |

## 生命周期包装模式

`use-uni-app.ts` 重写了 `onLoad`/`onShow`/`onMounted`/`onHide`，在原生命周期前自动注入 `afterLoginHook`：

```typescript
// 使用自定义包装（有登录守卫）
import { onLoad, onMounted } from '@/hooks/use-uni-app';

// 不需要登录守卫的页面，直接用 dcloudio 原生
import { onShow, onHide } from '@dcloudio/uni-app';
```

## 自定义 Hook 模式

```typescript
// 模块级 cache（跨组件共享）
const cache = ref<Record<string, any>>({});
export function useCalendarWeeks() {
  // compose 逻辑 + 返回响应式数据
}
```

## 新增 Hook 时

- 放 `src/hooks/` 下
- 命名遵循 `use-xxx.ts`
- 单例数据用模块级 ref，组件级数据每次调用返回新 ref
