# Backend Development Guidelines — storehub-servless

> **Pre-read**: [Architecture Overview](../../guides/architecture-overview.md) — understand the gateway role.
>
> Serverless gateway: all uniapp/web requests route through here.

---

## Overview

**Package**: `storehub-servless`  
**Framework**: 腾讯云 Serverless SCF (Express + @pagoda-serverless/runtime)  
**Port**: 3001 (local dev)

### Responsibilities
1. **Unified auth** — JWT Token validation via `qwMpSdk.check()`
2. **Proxy forwarding** — Route to 25+ backend services by `SeverEnum`
3. **Response normalization** — Parse each backend's response per its `result` config

---

## Key Conventions

### File Routing — CRITICAL

File path = URL path. Extension = HTTP method.

```
src/<module>/
├── <action>.post.ts   ← POST /module/action
├── <action>.get.ts    ← GET  /module/action
├── <action>.put.ts    ← PUT  /module/action
└── <action>.delete.ts ← DELETE /module/action
```

**关键: `<action>` 部分是 URL 路径的最后一段，不是函数名。**

```ts
// ✅ 正确: 文件 src/chat/postMessage.post.ts → POST /chat/postMessage
// uniapp 调用: alova.Post('/chat/postMessage')

// ❌ 错误: 文件 src/chat/message.post.ts → POST /chat/message
// 路径里不能偷懒写成 "message"，必须和文件名保持一致
```

**跨端路径对齐规则**：
- `src/chat/postMessage.post.ts` → serverless 暴露路径 `POST /chat/postMessage`
- ai 后端 NestJS 必须用 `@Controller('chat')` + `@Post('postMessage')` 接收
- uniapp 调 `alova.Post('/chat/postMessage')`

**自查方法**:
1. 写完 serverless 文件后，`ls dist/<module>/` 确认文件结构
2. 文件名是 `<action>.post.ts` → URL 最后一段必是 `<action>`（不是简化版 `message`）
3. 三端路径字符串必须完全相同

### API Proxy Pattern

```ts
import type { Main } from '@pagoda-serverless/runtime';
import { apis } from '@/api/_utils/httpService';

export const main: Main = async req => {
  const data = await apis.aiStore.post('/debug/test', { ...req.body });
  return { data };
};
```

### Service Config (`env-config/`)

Each backend service has its own config defining:
- `service` — environment URL mapping
- `result` — response parsing rules (`resCodeKey`, `resSuccessCode`, `resDataKey`)

**Always read the env-config before creating a new proxy** to ensure correct response parsing.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Proxy module organization | To fill |
| [Database Guidelines](./database-guidelines.md) | N/A (this is a gateway, not DB) | — |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Request logging conventions | To fill |

---

**⚠️ Self-check after modification**:
```bash
curl -s http://localhost:3001/<new-endpoint> -X POST \
  -H "Content-Type: application/json" | python3 -m json.tool
# Verify: { "code": 0, "data": {...} }
```

### ⚠️ CRITICAL: 404 Pitfall — serverless runtime 重启机制

**坑**: 新增 POST/GET 文件后，tsc watch 会立即编译产物到 `dist/` 目录，但 `@pagoda-serverless/runtime` 进程（`slr debug`）**不监听文件变化**，不会自动加载新路由。直接 curl 会得到 `404 不存在的请求资源`，但实际上产物已生成在 `dist/<module>/<action>.post.js`。

**自检前必做**：

1. 确认 `dist/` 下已生成对应 `.js` 文件：
   ```bash
   ls -la dist/<module>/<action>.post.{js,js.map}
   ```
2. 如果产物存在但 curl 404 → **必须重启 serverless 进程**才能验证。
3. 重启后再次 curl 自检。

**为什么容易踩**: tsc watch 输出新产物 ≠ runtime 注册了新路由。这是 serverless 框架的运行时限制，不是 bug。

**预防措施**: 新增 serverless 路由后，先 `ls dist/` 确认编译产物，再重启进程，再 curl。**不要在未重启前就下结论"404 → 路由没生效"或修改代码重试**。
