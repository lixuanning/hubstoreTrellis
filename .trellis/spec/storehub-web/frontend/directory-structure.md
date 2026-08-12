# storehub-web 目录结构

> Vue 3 + Vite + TypeScript H5 子应用。通过 webview/iframe 嵌入企业微信小程序。Vant 4 + PagodaMobile。

```
src/
├── api/
│   ├── http.ts                # axios 实例（baseURL/withCredentials/拦截器）
│   ├── index.ts               # import.meta.glob 自动导入 modules/ 所有 API 函数
│   └── modules/               # 按业务拆分的 API 函数
│       ├── auth.ts            # h5Login / getUserInfo / getSignture
│       ├── dailyClearing.ts / finance.ts / lossReported.ts / aiRecognition.ts
├── config/
│   └── baseUrl.ts             # 环境变量导出：baseApiUrl / loginURL / logoutURL
├── interfaces/
│   └── user.ts                # 用户类型（UserInfo/Role/Position/Store）+ 工厂函数
├── router/
│   ├── index.js               # createWebHistory + beforeEach 权限守卫 + afterEach
│   └── modules/               # 按业务模块拆分的路由（自动聚合）
│       ├── home.js / inventory.js / finance.js / ...
├── store/
│   ├── index.ts               # Pinia 实例
│   ├── userInfoStore.ts       # 核心 Store（用户/角色/岗位/权限，非 defineStore 写法）
│   └── dailyClearing.ts / reportCurrentStore.ts  # defineStore 标准写法
├── styles/
│   ├── common.less            # 全局基础样式
│   └── mobile.less / pc.less  # 双端适配样式
├── utils/
│   ├── userInfo.ts            # Token CRUD + ensureAuth 登录入口（核心）
│   ├── filter.js              # 全局过滤器（金额/百分比/日期格式化）
│   └── qywx.ts / wxsdk.ts     # 企业微信 JS-SDK + 小程序环境检测
├── views/                     # 页面视图（按业务模块组织）
│   ├── layout/index.vue       # 首页入口
│   ├── dailyClearing/         # 日清管理（最大模块，有 components/page/ 子目录）
│   ├── finance/ / inventory/ / lossReported/ / employeeSalary/
│   ├── universal/             # PC 端通用模块（页面路径含 universal 即为 PC 模式）
│   └── 404.vue / Forbidden.vue / dataForbidden.vue
├── rabuild-libs-utils/        # 共享工具层（从 ra-build 迁移）
├── App.vue                    # 根组件（keep-alive / 水印 / viewport 适配）
└── main.js                    # 入口（Vant / PagodaMobile / Pinia / filters / VConsole）
```

**登录链路（H5 嵌入小程序）**:
```
App.vue onMounted → ensureAuth()
  └─ [小程序 webview]?token=xxx → setToken() 注入 sessionStorage
  └─ [H5 浏览器] sessionStorage → h5Login() → /user/casLogin
```

**HTTP 拦截器 -9999 自动刷新**:
```
axios 响应 → code === 0 → resolve
          → code === -9999 → h5Login 刷新 token（全局锁防并发）
          → code === 500 → toast 提示 + reject
```
