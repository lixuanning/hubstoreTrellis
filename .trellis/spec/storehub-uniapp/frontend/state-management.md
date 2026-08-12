# storehub-uniapp — 状态管理与权限模型

## getUserInfo 后端数据结构

> 此接口为 uniapp 和 web 共用，返回的 JSON 结构见 [data.txt](data.txt)

```typescript
// 后端原始返回 (GET /user/getUserInfo)
{
  token: string;                          // 会话 token
  success: boolean;
  session: { id: string; skey: string };  // 会话标识
  realUsers: { code: string; name: string }; // 真实用户（模拟登录功能用）
  userInfo: {
    user: string;                          // 用户编码
    originalUserId: string;                // 真实用户 ID
    attributes: {
      oaid: string[];           // 用户编码列表
      employeeName: string[];   // 姓名
      avatar: string[];         // 头像 URL
      phone: string[];          // 手机号
      postInfoAry: { postType: string; postTypeCode: string }[]; // 岗位列表
      deptInfoAry: [];          // 部门信息
      postTypeCode: string;     // 当前选中岗位编码
      storeErpCode: string;     // 当前门店 ERP 编码
      storeEhrCode: string;     // 当前门店 EHR 编码
      roleList: RoleData[];     // ⭐ 角色列表（核心权限数据）
      originalUserName: string; // 真实用户姓名
      worked: string;
    };
  };
}
```

### roleList 中每个 RoleData 的结构

```typescript
interface RoleData {
  roleCode: string;             // 角色编码，如 "bgms_dz"
  roleName: string;             // 角色名称，如 "店长（ehr）"
  isSysInnerRole: string;       // "1"=内置角色，"0"=自定义角色
  noDesensitizationAreas: string[]; // 不脱敏的地区编码列表
  dateRange: {
    type: string;               // 数据范围类型
    scopeList: { label: string; value: string }[]; // 可见门店列表
  };
  positionType: PositionData[]; // 该角色下的岗位
  roleMenuList: MenuItem[];     // ⭐ 该角色的菜单权限列表
}

interface PositionData {
  postType: string;             // 岗位名称，如 "店长"
  postTypeCode: string;         // 岗位编码，如 "2001"
  roleCode: string;             // 关联的角色编码
  roleName: string;             // 关联的角色名称
  stores: StoreData[];          // 该岗位可管理的门店列表
}

interface StoreData {
  name: string;                 // 门店名称
  code: string;                 // 物理门店编码
  storeErpCode: string;         // ERP 编码
  storeEhrCode: string;         // EHR 编码
  erpCode: string;              // ERP 代码
  erp2Code: string;             // ERP2 代码
  city: string;                 // 城市
  address: string;              // 地址
  dataSource: string;           // 数据来源
  storeManagerCode: string;     // 店长编码
  storeManagerName: string;     // 店长姓名
  storeManagerPhone: string;    // 店长电话
  // 区域层级（大区→片区→区域）
  areaQCode/areaQName: string;  // 大区
  areaPCode/areaPName: string;  // 片区
  areaFCode/areaFName: string;  // 区域
  areaManagerCode/Name/Phone;   // 区域经理
  // 配送层级
  regionDCode/regionDName: string; // 配送中心
  regionPCode/regionPName: string; // 配送片区
  regionFCode/regionFName: string; // 配送区域
  regionQCode/regionQName: string; // 配送大区
}

interface MenuItem {
  code: string;                 // 菜单编码，如 "bgms_sy"
  name: string;                 // 菜单名称，如 "首页"
  tags: string;                 // "页面" | "按钮"
  treeNodeSort: number;         // 排序号
  treeParentCode: string;       // 父级编码（空字符串=顶级）
}
```

### 菜单权限树（roleMenuList 典型结构）

```
bgms_sy (首页)                     bgms_qxgl (权限管理-仅内置角色)
├── bgms_sy_xzmdym (新增门店页面)    ├── bgms_qxgl_mngl (模拟管理)
│   ├── bgms_sy_xzmdym_zbddsj
│   ├── bgms_sy_xzmdym_sjsl
│   └── bgms_sy_xzmdym_hygk
└── bgms_sy_xzpqym (新增片区页面)    bgms_rw (任务)
                                    ├── bgms_rw_jrsx (今日事项)
bgms_gzt (工作台)                    ├── bgms_rw_zgrw (整改任务)
├── bgms_gzt_bj (编辑-按钮)          │   └── bgms_rw_zgrw_zb (转办-按钮)
├── bgms_gzt_mdrw (门店任务)         ├── bgms_rw_zjrw (自检任务)
├── bgms_gzt_rqrj (日清日结)         └── bgms_rw_wdss (我的申诉)
├── bgms_gzt_xd (鲜度)
├── bgms_gzt_ydpd (移动盘点)         bgms_wd (我的)
├── bgms_gzt_fxyj (分享有奖)         ├── bgms_wd_dqgw (当前岗位)
├── bgms_gzt_mdwg (门店违规)         ├── bgms_wd_mdwxpf (门店五行评分)
├── bgms_gzt_zlts (质量投诉)         ├── bgms_wd_jljj (激励奖金)
└── bgms_gzt_yjbz (一键报障)         ├── bgms_wd_yggz (员工工资)
                                      ├── bgms_wd_xdbg (巡店报告)
bgms_xx (消息)                       ├── bgms_wd_jmspj (加盟商评级)
                                      └── bgms_wd_syfk (使用反馈)
bgms_xdzs (鲜度助手)
├── bgms_xdzs_sy (首页)              bgms_spsq (商品售罄)
│   ├── bgms_xdzs_sy_xdsj (鲜度数据)
│   │   ├── bgms_xdzs_sy_xdsj_ysycgl (疑似异常概览)
│   │   ├── bgms_xdzs_sy_xdsj_gqsp (过期商品)
│   │   ├── bgms_xdzs_sy_xdsj_bdxsp (不动销商品)
│   │   └── bgms_xdzs_sy_xdsj_xkcsp (虚库存商品)
│   ├── bgms_xdzs_sy_kxbsj (库销比数据)
│   └── bgms_xdzs_sy_xdsj_cd (菜单)
├── bgms_xdzs_splb (商品列表页)
│   ├── bgms_xdzs_splb_fqpd (发起盘点-按钮)
│   └── bgms_xdzs_splb_qxpd (取消盘点-按钮)
└── bgms_xdzs_dpxq (单品详情页)
    ├── bgms_xdzs_dpxq_fqpd (发起盘点-按钮)
    ├── bgms_xdzs_dpxq_qxpd (取消盘点-按钮)
    └── bgms_xdzs_dpxq_cjt (长截图-按钮)
```

---

## 客户端数据转换（defineUserInfo）

`src/interfaces/user.ts` 中的 `defineUserInfo()` 将后端原始数据转换：

```
后端 roleList[].positionType[]  ←平坦化→  positionList (所有岗位)
后端 roleList[]                 ←索引化→  roleMap (roleCode → Role)
positionList[].stores[]         ←关联→    roleCode + postTypeCode
```

每个 Store 同时携带其所属的 `roleCode` 和 `postTypeCode`，实现：**选中门店 → 确定岗位 → 确定角色 → 确定菜单权限**。

---

## 8 种角色体系

| key | roleCode | 角色名称 | 说明 |
|-----|----------|---------|------|
| `m` | `bgms_dz` | 店长 | 门店管理核心角色 |
| `d` | `bgms_dy` | 店员 | 门店执行角色 |
| `j` | `bgms_jms` | 加盟商 | 加盟门店角色 |
| `p` | `bgms_pqjl` | 片区经理 | 管理多个门店 |
| `f` | `bgms_fsdc` | 防损督察 | 巡店检查角色 |
| `y` | `bgms_yyjl` | 运营经理 | 运营管理角色 |
| `z` | `bgms_qz` | 区总 | 区域负责人 |
| `q` | `bgms_qt` | 其他 | 自定义角色（如"单大区-功能-ym"） |

---

## Pinia 两种写法并存

### 写法 1：Setup Store（userInfoStore.ts）— 推荐

```typescript
export const useUserInfoStore = defineStore('userInfo', () => {
  const loginStatus = ref<LOGIN_STATUS>(LOGIN_STATUS.IDLE);
  const userInfo = ref<UserData>(defineUserInfo());

  // 当前角色关联的计算属性
  const userCurrentRole = computed(() => {
    // 从当前岗位 postTypeCode → positionMap → roleCode → roleMap
  });
  const currentRoleMenuList = computed(() => userCurrentRole.value?.roleMenuList || []);

  // 权限判断函数（见下文）
  const hasMenuPermission = (...codes) => { /* ... */ };
  const isOneOfCurrentUserRoles = (...keys) => { /* ... */ };

  return { loginStatus, userInfo, userCurrentRole, currentRoleMenuList, hasMenuPermission };
});
```

### 写法 2：Options Store（homeStore.ts）

```typescript
export const useHomeStore = defineStore('homeStore', {
  state: () => ({ erpToken: '', storeCodes: [] }),
  getters: { isStoreItemPage: () => { /* ... */ } },
  actions: { setErpInfo(value) { this.erpToken = value; } },
});
```

---

## 权限判断函数

所有函数定义在 `src/store/modules/userInfoStore.ts`：

### hasMenuPermission(...codes) — 菜单权限判断（最常用）

```typescript
// 判断当前角色的 roleMenuList 是否包含指定菜单编码
// 支持多 code（全部满足才返回 true），支持布尔表达式
store.hasMenuPermission('bgms_gzt')                              // 是否有工作台权限
store.hasMenuPermission('bgms_gzt', 'bgms_gzt_bj')               // 是否同时有工作台+编辑
store.hasMenuPermission('bgms_rw && (bgms_rw_zgrw || bgms_rw_jrsx)')  // 布尔表达式
```

### isOneOfCurrentUserRoles(...keys) — 角色判断

```typescript
// 判断当前用户是否是指定角色之一
store.isOneOfCurrentUserRoles('m')          // 是否店长
store.isOneOfCurrentUserRoles('j')          // 是否加盟商
store.isOneOfCurrentUserRoles('m', 'd')     // 是否门店端（店长或店员）
store.isOneOfCurrentUserRoles('p')          // 是否片区经理
```

### hasPostType(...postTypeCodes) — 岗位判断

```typescript
// 判断用户是否拥有指定岗位（不限于当前选中岗位）
store.hasPostType('2001')  // 是否拥有店长岗位
```

---

## 页面级权限控制（config-provider）

`src/components/layout/config-provider/config-provider.vue` 是页面级权限核心：

```vue
<!-- 需要任务相关权限才显示 -->
<config-provider auth-code="bgms_rw && (bgms_rw_zgrw || bgms_rw_zjrw || bgms_rw_jrsx)">
  <task-page />
</config-provider>

<!-- 需要工作台权限 -->
<config-provider auth-code="bgms_gzt">
  <workbench-page />
</config-provider>
```

无权限时渲染 `<config-provider-permission>` 占位组件（"当前岗位无页面权限"）。

---

## 首页权限控制（homeAuth Hook）

`src/pages-home/hooks/homeAuth.ts`:
- 根据 `dateRange.type` + `scopeList` 确定组织层级（集团/大区/区域/片区/门店）
- `currentPermissionCodes` 根据层级返回对应的 `HOME_PERMISSION_CODES`
- 无 `postTypeCode` 或 `scopeList` 为空时 → `authStatus === 'no-permission'` → 跳转到任务 Tab

---

## 用户角色 Hook

`hooks/use-user-role.ts` 包装 Pinia store，在非组件上下文中使用：

```typescript
const { userRoleInfo } = useUserRoleInfo(); // 可用在拦截器等非组件位置
```

## 登录管理器

`utils/login/LoginManager.ts` — 队列 + 单例模式，确保多个并发登录请求只执行一次。

---

## 权限判断决策树

```
需要判断权限时，按以下优先级选择函数：

1. 控制页面/组件显隐 → hasMenuPermission(code)（基于菜单编码，最灵活）
2. 按角色分流逻辑   → isOneOfCurrentUserRoles(key)（如店长/加盟商不同页面）
3. 按岗位过滤       → hasPostType(code)（仅判断是否拥有，不常用）
4. 页面入口守卫     → config-provider auth-code（声明式，推荐）
```
