# 实现记录

**任务**: 08-11-home-api-demo

## 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `ai-store-api/src/app.controller.ts` | 新增 | `GET /demo/hello` → `{ status: 200, data: { greeting, timestamp } }` |
| `storehub-servless/src/demo/hello.get.ts` | 新增 | 代理转发 `apis.aiStore.get('/demo/hello')` |
| `storehub-uniapp/src/api/apis/common.ts` | 新增 | `API_DEMO_HELLO = '/demo/hello'` |
| `storehub-uniapp/src/api/service/common.ts` | 新增 | `demoHello()` 服务函数 |
| `storehub-uniapp/src/pages/home.vue` | 修改 | `onMounted` 中调用 `demoHello()` 并 console.log |

## 自检结果

| 步骤 | 命令 | 结果 |
|------|------|------|
| ai:3000 | `curl -s :3000/demo/hello` | ✅ `{ status: 200, data: {...} }` |
| sl:3001 (临时白名单) | `curl -s :3001/demo/hello` | ✅ `{ code: 0, data: {...} }` |
| 白名单清理 | 删除 contacts.ts 中 `/demo/hello` | ✅ 无残留 |
