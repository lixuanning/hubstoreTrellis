# Frontend Development Guidelines — storehub-web

> **Pre-read**: [Architecture Overview](../../guides/architecture-overview.md)
>
> Vue 3 + Vite H5 子应用，**通过 webview/iframe 嵌入企业微信小程序**。与 uniapp 主应用共享业务数据（subAppStore），登录走 preLogin → cookie → 子应用页面的链路。
>
> <!-- 以下英文由 Trellis 维护，中文注释为团队补充 -->
>
> Vue 3 + Vite H5 pages embedded in miniapp via webview/iframe.

---

## Overview

**Package**: `storehub-web`  
**Framework**: Vue 3 + Vite + TypeScript  
**HTTP Client**: axios (wrapped in `api/http.ts` — interceptors for token injection + auto-refresh)  
**UI**: Vant (Notify for toasts)  
**State**: Pinia  
**Router**: Vue Router (modular config in `router/modules/`)

---

## Key Conventions

### API Call Pattern — 2-Tier

```
src/api/
├── modules/        ← API functions (glob auto-loaded via import.meta.glob)
│   ├── auth.ts        export fn() { http.get('/user/xxx', params) }
│   └── ...
├── http.ts         ← axios instance (interceptors, token, refresh)
└── index.ts        ← auto-aggregator
```

```ts
// In page:
import { getUserInfo } from '@/api/modules/auth';
const data = await getUserInfo({ ...params });
```

### HTTP Interceptor Chain (http.ts)
- Request: inject token from sessionStorage + position-type header
- Response: code === -9999 → auto-refresh token & retry
- Response: code === 418 → redirect to login
- Empty params (null/undefined/'') auto-stripped

### Webview Integration
- Pages are loaded inside miniapp webview via subAppStore
- Login flow: preLogin → get cookie → subApp page
- Domain cache: 2-day validity to avoid repeated login

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Views/modules organization | To fill |
| [Component Guidelines](./component-guidelines.md) | Vant + custom component patterns | To fill |
| [Hook Guidelines](./hook-guidelines.md) | Custom hooks patterns | To fill |
| [State Management](./state-management.md) | Pinia store patterns | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards | To fill |
| [Type Safety](./type-safety.md) | TypeScript patterns | To fill |
