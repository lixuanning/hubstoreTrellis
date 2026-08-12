# storehub-web — 状态管理

## Pinia 两种写法并存

### 写法 1：普通对象（userInfoStore.ts）— 核心 Store

```typescript
// 不使用 defineStore，直接导出 reactive 对象
export default {
  state: reactive({
    loginStatus: LOGIN_STATUS.IDLE,
    userInfo: defineUserInfo(),
    loginUserInfo: defineLoginUserInfo(),
  }),
  computed: {
    userCurrentPosition() { /* 从 positionMap 按 postTypeCode 查 */ },
    userCurrentRole() { /* 从 roleMap 按当前岗位 roleCode 查 */ },
  },
  actions: {
    setUserInfo(info) { /* 合并用户信息 + 构建 positionMap/roleMap */ },
    hasMenuPermission(...codes) { /* 菜单权限判断 */ },
    hasPositionPermission(code) { /* 岗位权限校验 */ },
  },
};
```

组件中使用：
```typescript
import store from '@/store/userInfoStore';
const { userCurrentRole } = store; // 直接解构
```

### 写法 2：defineStore（dailyClearing.ts / reportCurrentStore.ts）

```typescript
export const usedailyClearingInfoStore = defineStore('dailyClearing', () => {
  const data = ref({});
  const setData = (v) => { data.value = v; };
  return { data, setData };
});
```

## 权限模型

`岗位 → 角色 → 门店 → 菜单` 四层级联：

```
UserInfo
  └── positionList[] → 岗位列表
        └── roleCode → 关联角色
              ├── roleMenuList[] → 菜单权限
              └── stores[] → 门店列表
```

## Token 存储

- `sessionStorage` 键名 `storehub:token:{platform}`（按平台隔离）
- 每次请求前实时读取（不缓存）
- `-9999` 响应 → `h5Login` 自动刷新（全局锁防并发）
