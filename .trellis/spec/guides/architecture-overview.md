# StoreHub 项目架构概览

> **Purpose**: AI 在写任何代码前，必须先理解本项目的四仓库架构和调用关系。

---

## 系统架构

本项目是一个 **monorepo**，包含 4 个子项目：

```
storehub/
├── ai-store-api/         ← NestJS 后端，AI识别/核验/预警，端口 3000
├── storehub-servless/    ← Node.js Serverless 中间件/网关，端口 3001
├── storehub-uniapp/      ← UniApp+Vue3 企业微信小程序（主）+ H5
└── storehub-web/         ← Vue3+Vite H5 页面（webview 嵌入）
```

---

## 核心调用链路

```
uniapp (小程序)
    │
    ├─ [alova HTTP] ──→ serverless (网关, :3001)
    │                       │
    │                       ├─→ ai-store-api (:3000)   NestJS 后端
    │                       ├─→ 慧云 / 魅族 / 消防监   第三方系统
    │                       ├─→ 小程序后端 / ERP / 财务 25+ 后端服务
    │                       └─→ MySQL + Redis
    │
    └─ [webview] ─────→ storehub-web (H5 页面)
```

**关键约束**：
- uniapp **不直接**调用 ai，必须通过 serverless 代理
- serverless 是唯一网关，统一认证 + 代理转发
- web 通过小程序 webview 嵌入，登录走 subAppStore 预登录流程

---

## 响应格式约定

### 两层解析模型

serverless 通过每个后端服务的 `result` 配置，将不同后端的**异构响应格式**统一解析，再经 `setup.ts` 的 `transformer` 标准化为前端统一格式。

```
各后端异构响应              serverless result 解析          前端统一格式
────────────────────────────────────────────────────────────────────
ai-store:                   resCodeKey: 'status'          { code: 0,
  { status: 200,             resDataKey: 'data'              data: {...} }
    data: {...} }           ───────→ ERP:
miniapp:                    resCodeKey: 'code'            { code: 0,
  { code: 200,               resDataKey: 'content'           data: {...} }
    content: {...} }  ERP2:  ─────── →
erp2:                       resCodeKey: 'resultCode'
  { resultCode: '0',         resDataKey: 'data'           { code: 0,
    data: {...} }
    errorMsg: '...' }       ───────→
```

### env-config.result 配置说明

每个后端服务在 `src/api/env-config/<service>.ts` 中定义 4 个解析字段：

| 字段 | 含义 | ai-store 示例 | miniapp 示例 | erp2 示例 |
|------|------|--------------|-------------|----------|
| `resCodeKey` | 响应码字段名 | `status` | `code` | `resultCode` |
| `resSuccessCode` | 成功的 code 值 | `200` | `200` | `'0'` |
| `resDataKey` | 业务数据字段名 | `data` | `content` | `data` |
| `resMessageKey` | 错误信息字段名 | `message` | `error` | `errorMsg` |

### 关键规则

1. **每个后端有自己的响应格式** — 没有统一标准，取决于各自后端团队
2. **serverless 负责归一化** — 通过 `result` 配置 + `transformer` 统一输出 `{ code: 0, data: {...} }` 给前端
3. **新增 ai 接口时**：返回 `{ status: 200, data: {...} }`，匹配 `ai-store.ts` 的 result 配置
4. **新增其他后端代理时**：先确认该服务的 `resCodeKey` 和 `resSuccessCode`，不要假设是 `code: 0`

---

## 各端 API 约定

### uniapp: 三层架构（不可跳层）

```
src/api/
├── apis/        ← 第1层: 路径常量  API_XXX = '/xxx'
├── service/     ← 第2层: 服务函数  export async fn() { alova.Post(API_XXX) }
└── index.ts     ← alova 实例
```

**页面只能 import service/**，禁止内联 `alova.Post()`。

**TabBar 安全区**：uniapp 有 5 个原生 TabBar（见 `pages.json`），底部占约 180rpx。浮动按钮/底部弹窗需用 `bottom: 180rpx` 而非 `marginBottom`，避免被遮挡。详见 [storehub-uniapp/frontend/index.md](./storehub-uniapp-frontend-index.html)。

### web: 两层架构

```
src/api/
├── modules/     ← API 函数 (glob 自动加载)  http.post('/xxx')
└── http.ts      ← axios 实例 (拦截器 + token)
```

### serverless: 文件路由

```
src/
├── xxx/
│   └── yyy.post.ts  ← 文件路径 = URL: POST /xxx/yyy
│                    export main: Main, 通过 apis.xxx 代理到后端
```

### ai: NestJS 模块化

- 简单接口 → `app.controller.ts`
- 复杂模块 → `src/<module>/` (controller + service + module)
- 使用 `@ApiExcludeEndpoint()` 标记非 Swagger 接口
- 使用 `@UseGuards(JwtAuthGuard)` 保护需要认证的接口

---

## 环境映射

| 环境 | serverless | ai | uniapp BASE_API_URL |
|------|-----------|----|--------------------|
| 本地 | :3001 | :3000 | :3001 |
| dev | kdev.pagoda.com.cn | ai-store-api...test.bghdkj.com | serverless dev |
| test | ktest.pagoda.com.cn | ai-store-api.aixundian | serverless test |
| prod | pagoda.com.cn | ai-store-api.aixundian | serverless prod |

---

## 修改后自检流程

| 改动范围 | 验证方式 |
|----------|---------|
| 仅改 ai | `curl :3000/xxx` → 验证 `{ status: 200, data: {...} }` |
| 改 serverless | `curl :3001/xxx` → 验证 `{ code: 0, data: {...} }` |
| 两端都改 | 先 `curl :3000/xxx` 确认 ai 正确，再 `curl :3001/xxx` 验证完整链路 |

### ⚠️ serverless 自检与登录白名单

serverless 有 CAS 登录中间件，curl 自检时可能被拦截返回登录提示。正常业务流程中小程序自带登录态，**不应**将接口永久加入白名单。

**自检时的正确做法**（零副作用，验证完即清理）：

```
1. 临时加入白名单 → curl :3001 验证 → 验证通过后立即移除
```

```bash
# 在 contacts.ts 的 allowedToPass 中临时加一行
# 验证: curl -s http://localhost:3001/demo/hello | python3 -m json.tool
# 通过后立即删除该行，不留残留
```

**规则**：`allowedToPass` 只放无需登录的公共接口（如 login/logout）。自检用的临时路径必须在验证完成后删除。 |
