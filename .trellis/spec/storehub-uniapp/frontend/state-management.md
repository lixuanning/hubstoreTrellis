# storehub-uniapp — 状态管理

## Pinia 两种写法并存

### 写法 1：Setup Store（userInfoStore.ts）— 推荐

```typescript
export const useUserInfoStore = defineStore('userInfo', () => {
  const loginStatus = ref<LOGIN_STATUS>(LOGIN_STATUS.IDLE);
  const userInfo = ref<UserData>(defineUserInfo());
  const userCurrentPostType = computed(() => { /* ... */ });
  return { loginStatus, userInfo, userCurrentPostType };
});
```

组件中使用：
```typescript
const store = useUserInfoStore();
const { userCurrentPostType } = storeToRefs(store);
```

### 写法 2：Options Store（homeStore.ts）

```typescript
export const useHomeStore = defineStore('homeStore', {
  state: () => ({ erpToken: '', storeCodes: [] }),
  getters: { isStoreItemPage: () => { /* ... */ } },
  actions: { setErpInfo(value) { this.erpToken = value; } },
});
```

## 用户角色 Hook

`hooks/use-user-role.ts` 包装 Pinia store，在非组件上下文中使用：

```typescript
const { userRoleInfo } = useUserRoleInfo(); // 可用在拦截器等非组件位置
```

## 登录管理器

`utils/login/LoginManager.ts` — 队列 + 单例模式，确保多个并发登录请求只执行一次。
