# Backend Development Guidelines — ai-store-api

> **Pre-read**: [Architecture Overview](../../guides/architecture-overview.md)
>
> **必须预先理解**: NestJS 框架 + 本项目的 Response 归一化约定 + curl 自检机制。详见下方 Key Conventions。

NestJS 后端服务（端口 3000）。基于 DashScope（阿里云大模型），负责核心业务逻辑和 AI 能力。
<!-- 以下英文由 Trellis 维护，中文注释为团队补充 -->

---

## Overview

**Package**: `ai-store-api`  
**Framework**: NestJS 7.x + TypeScript 5.x  
**Database**: TypeORM 0.2.x (MySQL) + Redis  
**Port**: 3000 (local dev)  
**Config**: `env/.env.*` (loaded by `ConfigModule`)

---

## Key Conventions

### Response Format — CRITICAL

All API responses MUST follow the pattern matching serverless result config:

```ts
// serverless env-config/ai-store.ts expects:
// resCodeKey: 'status', resSuccessCode: 200, resDataKey: 'data'

// Correct
{ status: 200, data: { ... }, message?: '...' }

// Wrong
{ code: 0, ok: true, data: { ... } }
```

Use the project's response classes:
- `ResponseData<T>` — `{ status, data?, message? }`
- `NormalResponse` — `{ status, message? }` (no data)
- `ResponseDto<T>` — `{ status: HttpStatus.OK, message, data }`

### Controller Annotations
- `@ApiExcludeEndpoint()` → skip Swagger generation for internal APIs
- `@UseGuards(JwtAuthGuard)` → require JWT authentication

### Module Structure
```
src/<module>/
├── <module>.controller.ts
├── <module>.service.ts
├── <module>.module.ts
├── <module>.config.ts (NestJS ConfigModule register)
├── dto/   (request DTOs)
└── interfaces/   (response interfaces)
```

### API Call Pattern
```ts
// In service (serverless uses apis.aiStore):
apis.aiStore.post('/api/path', body)  // POST
apis.aiStore.get('/api/path', params)  // GET
```

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Database Guidelines](./database-guidelines.md) | ORM patterns, queries, migrations | To fill |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Winston logging conventions | To fill |

---

**⚠️ Self-check after modification**:
```bash
curl -s http://localhost:3000/<new-endpoint> -X POST \
  -H "Content-Type: application/json" | python3 -m json.tool
# Verify: { "status": 200, "data": {...} }
```
