# storehub-web — 状态管理与权限模型

## getUserInfo 共享接口

> 与 uniapp 共用同一个 `GET /user/getUserInfo` 接口，完整数据结构参见 uniapp 的 [state-management.md](../../storehub-uniapp/frontend/state-management.md#getuserinfo-后端数据结构)

关键差异：
- web 仅使用 3 种角色（门店店长/片区经理/加盟商），其余角色走 `bgms_qt` 兜底
- web 不使用 `config-provider` 权限组件，改用路由 `meta` + `beforeEach` 守卫
- web 的 userStore 用 `reactive` 普通对象而非 `defineStore`

---

## Store 架构

### 写法 1：普通对象（userInfoStore.ts）— 核心 Store

```typescript
// 不使用 defineStore，直接导出 reactive + computed + 方法 的普通对象
export default {
  state: reactive({
    loginStatus: LOGIN_STATUS.IDLE,
    userInfo: defineUserInfo(),
    loginUserInfo: defineLoginUserInfo(),
    switchRoleInfo: {},   // 切换岗位时的临时状态
    realUsers: {},        // 模拟用户
  }),
  // computed 通过 getter 函数定义（非 Vue computed）
  get userCurrentPosition() {
    return this.state.userInfo.positionMap?.[this.state.userInfo.postTypeCode];
  },
  get userCurrentRole() {
    const roleCode = this.userCurrentPosition?.roleCode || 'bgms_qt';
    return this.state.userInfo.roleMap?.[roleCode];
  },
  get currentRoleMenuList() {
    return this.userCurrentRole?.roleMenuList || [];
  },
  get userCurrentRoleStoreList() {
    return this.userCurrentPosition?.stores || [];
  },
  // 方法
  setUserInfo(info) { /* 合并 + 构建 positionMap/roleMap */ },
  hasMenuPermission(...codes) { /* 菜单权限判断 */ },
  hasPositionPermission(code) { /* 当前岗位权限判断 */ },
  hasAnyRolePermission(code) { /* 任意角色权限判断 */ },
  isOneOfCurrentUserRoles(...keys) { /* 角色判断 */ },
};
```

组件中使用：
```typescript
import store from '@/store/userInfoStore';
const { userCurrentRole } = store;  // 直接解构
```

### 写法 2：defineStore（dailyClearing.ts / reportCurrentStore.ts）

```typescript
export const usedailyClearingInfoStore = defineStore('dailyClearing', () => {
  const data = ref({});
  const setData = (v) => { data.value = v; };
  return { data, setData };
});
```

---

## 权限模型

`岗位 → 角色 → 门店 → 菜单` 四层级联：

```
UserInfo
  └── roleList[] — 用户所有角色
        └── positionType[] → positionList (客户端平坦化)
              ├── roleCode → roleMap → 角色菜单权限 roleMenuList
              └── stores[] → 可管理门店列表
```

**客户端转换（setUserInfo）：**
1. 遍历 `roleList`，提取所有 `positionType[]` → 平坦化为 `positionList`
2. 构建 `positionMap`（postTypeCode → Position）
3. 构建 `roleMap`（roleCode → Role）
4. 每个 Store 携带其所属 `roleCode`

---

## 双轨权限体系

与 uniapp 共用同一 `getUserInfo` 接口，存在**两套并行的权限路径**：

### 路径 1：3 种固定角色 — roleCode + stores 门店权限

| key | roleCode | 角色名称 | 权限来源 |
|-----|----------|---------|---------|
| `mdj` | `bgms_mdj` | 门店店长 | `stores[]` → 管理的门店 |
| `pqjl` | `bgms_pqjl` | 片区经理 | `stores[]` → 片区门店 |
| `jms` | `bgms_jms` | 加盟商 | `stores[]` → 加盟门店 |

其余角色走 `roleCode` 直接比对 `roleMenuList` 控制菜单权限。

### 路径 2：自定义角色 — dateRange 层级数据权限

自定义角色不走 `stores[]`，通过 `dateRange.type` + `dateRange.scopeList` 按组织层级查看数据。

#### orgType 枚举

web 使用自有的 3 套组织类型枚举（定义在 `src/views/dailyClearing/config/common.js`）：

| 层级 | dailyClearingOrgType (后端) | userCenterOrgType (个人中心) | goodsListOrgTypeEnum (商品查询) |
|------|---------------------------|---------------------------|-------------------------------|
| 集团 | `JT: -1` | `JT: '0'` | `JT: 'JT'` |
| 大区 | `DQ: 0` | `DQ: '0'` | `DQ: 'BIGREGN'` |
| 区域 | `QY: 1` | `QY: '1'` | `QY: 'REGN'` |
| 片区 | `PQ: 2` | `PQ: '2'` | `PQ: 'AREA'` |
| 门店 | `MD: 3` | `MD: '3'` | `MD: 'STORE'` |

#### 权限判定函数（common.js）

```javascript
// getRoleOrgDtos() — 将 dateRange 转为后端接口参数
// 集团（type='0' 且 scopeList 含 '*'）→ { orgType: -1, codes: ['0'] }
// 非集团 → { orgType: Number(type), codes: scopeList.map(i => i.value) }

// getMaxOrg(dateRange) — 判断最大权限范围
// scopeList.length === 1 → 单店/单区域 → 直接跳转对应层级
// scopeList.length > 1  → 多选 → 列表前插入"全部"选项

// hasDataPermission(dateRange) — 无权限判断
// !scopeList || scopeList.length <= 0 → 跳转 /dataForbidden

// getCompleteOrg({ orgType, value, label }) — 下钻时查询完整层级链路
// 调用 dailyGetOrgHierarchy 接口向上追溯区域/大区/片区
```

#### 层级下钻（Drill-Down）

web 的下钻实现在**日清结算模块**（非首页），通过 `orgCascaderList.vue` 级联选择器 + 商品详情页列表点击：

```
orgCascaderList (JT → 大区 → 区域 → 片区 → 门店 五级级联)
  ├── initMaxOrg() — 从 dateRange 初始化最大权限范围
  ├── loadChildren() — 调用 dailyGetActiveOrgList 按层级异步加载子级
  ├── selectItem() — 用户选择某级后加载下一级子项
  └── 商品详情页 orgInfoClick → getCompleteOrg() → 自动切换 Tab 层级
```

#### 与 uniapp 实现差异

| 维度 | uniapp | web |
|------|--------|-----|
| 固定角色数量 | 8 种 | 3 种 |
| orgType 枚举 | `DATE_RANGE_TYPE` + `ORG_ROLE` | `dailyClearingOrgType` + `userCenterOrgType` |
| 角色映射 | `DATE_RANGE_TO_ORG_ROLE_MAP` | 直接判 `type` + `scopeList` |
| 层级下钻位置 | 首页 homeAuth Hook | 日清结算 orgCascaderList |
| 下钻接口 | `getStoreLvlsByLvlData` | `dailyGetActiveOrgList` + `dailyGetOrgHierarchy` |
| isSysInnerRole | 区分内置/自定义角色 | 不使用此字段 |

---

## 权限判断函数

所有函数定义在 `src/store/userInfoStore.ts`：

### hasMenuPermission(...codes) — 菜单权限判断（最常用）

```typescript
// 判断当前角色 currentRoleMenuList 是否包含指定 code
// 支持多 code（全部满足才返回 true）
store.hasMenuPermission('bgms_spsq')           // 是否有商品售罄权限
store.hasMenuPermission('bgms_gzt', 'bgms_gzt_bj')  // 多 code AND 判断
```

### hasPositionPermission(code) — 当前岗位权限

```typescript
// 从当前岗位 postTypeCode → positionMap → roleCode → roleMap → roleMenuList
// 检查当前岗位对应的角色是否有该权限
store.hasPositionPermission('bgms_spsq')
```

### hasAnyRolePermission(code) — 任意角色权限

```typescript
// 遍历用户所有角色的 roleMenuList，任意一个拥有即返回 true
// 用于路由守卫：用户只需在某个角色下有该权限即可访问
store.hasAnyRolePermission('bgms_spsq')
```

### isOneOfCurrentUserRoles(...keys) — 角色判断

```typescript
// 判断当前角色是否预设角色之一
store.isOneOfCurrentUserRoles('mdj')    // 是否门店店长
store.isOneOfCurrentUserRoles('pqjl')   // 是否片区经理
store.isOneOfCurrentUserRoles('jms')    // 是否加盟商
```

---

## 路由权限控制

web 采用**静态路由 + beforeEach 守卫**模式（非动态生成路由）：

### 路由 meta 字段

```javascript
// src/router/modules/dailyClearing.js
{
  path: '/daily-clearing',
  meta: {
    requirePositionPermission: 'bgms_spsq',  // 需要当前岗位有此权限
  }
}
```

### beforeEach 守卫优先级

```
requirePositionPermission → requireAnyRolePermission → 默认放行
         ↓                          ↓
  hasPositionPermission()    hasAnyRolePermission()
         ↓                          ↓
     失败 → /forbidden        失败 → /forbidden
```

### 守卫实现

```javascript
// src/router/index.js
router.beforeEach(async (to, from, next) => {
  await ensureAuth();  // 确保已登录并获取 userInfo

  if (to.meta.requirePositionPermission) {
    return store.hasPositionPermission(to.meta.requirePositionPermission)
      ? next()
      : next('/forbidden');
  }
  if (to.meta.requireAnyRolePermission) {
    return store.hasAnyRolePermission(to.meta.requireAnyRolePermission)
      ? next()
      : next('/forbidden');
  }
  next();
});
```

目前仅日清模块使用了 `requirePositionPermission`，其他模块无权限 meta（默认放行）。

---

## Token 存储

- `sessionStorage` 键名 `storehub:token:{platform}`（按平台隔离）
- 每次请求前实时读取（不缓存）
- `-9999` 响应 → `h5Login` 自动刷新（全局锁防并发）

---

## web vs uniapp 权限实现差异

| 维度 | uniapp | web |
|------|--------|-----|
| 角色数量 | 8 种（m/d/j/p/f/y/z/q） | 3 种（mdj/pqjl/jms）|
| Store 写法 | `defineStore` Setup Store | `reactive` 普通对象 |
| 页面权限 | `config-provider` 声明式 | 路由 `meta` + `beforeEach` |
| 菜单生成 | 无动态路由（TabBar 静态） | 静态路由 + 守卫过滤 |
| 权限函数 | hasMenuPermission / isOneOfCurrentUserRoles / hasPostType | 同上 + hasPositionPermission / hasAnyRolePermission |
| 登录入口 | 微信/H5 双通道 | 仅 H5（`h5Login`） |
| 双轨-自定义角色 | `DATE_RANGE_TYPE`+`ORG_ROLE` 映射 | `dailyClearingOrgType` 直接比对 |
| 双轨-下钻位置 | 首页 homeAuth | 日清结算 orgCascaderList |
| 双轨-下钻接口 | `getStoreLvlsByLvlData` | `dailyGetActiveOrgList`+`dailyGetOrgHierarchy` |
