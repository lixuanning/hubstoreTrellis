# AI 助手 MVP: 入口机器人 + 基础智能问答

**任务**: 08-11-ai-assistant-mvp
**状态**: in_progress
**类型**: 轻量级 (PRD + implement)

---

## 目标

基于蓝图 P0 阶段，先实现：
- **基础智能问答** - LLM 抽象层 + Chat 业务模块 + 阿里云 DashScope 对接
- **入口机器人** - uniapp 首页浮动按钮 + 对话弹窗

**约束**：
- 不改动现有 aliyun-vision / vfm-verify 模块
- 抽象出通用 LLM 能力，后续业务复用

---

## 改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `ai-store-api/src/llm/llm.service.ts` | 新增 | 通用 LLM 服务，封装 DashScope API |
| `ai-store-api/src/llm/llm.module.ts` | 新增 | LLM Module (Global) |
| `ai-store-api/src/llm/index.ts` | 新增 | 导出 |
| `ai-store-api/src/chat/chat.service.ts` | 新增 | 业务封装：系统提示词 + 消息 |
| `ai-store-api/src/chat/chat.controller.ts` | 新增 | `POST /chat/message` |
| `ai-store-api/src/chat/chat.module.ts` | 新增 | Chat Module |
| `ai-store-api/src/chat/index.ts` | 新增 | 导出 |
| `ai-store-api/src/app.module.ts` | 修改 | 注册 LlmModule + ChatModule |
| `storehub-servless/src/chat/postMessage.post.ts` | 新增 | 代理 `apis.aiStore.post('/chat/message')` |
| `storehub-uniapp/src/api/apis/chat.ts` | 新增 | `API_CHAT_MESSAGE = '/chat/message'` |
| `storehub-uniapp/src/api/service/chatService.ts` | 新增 | `sendChatMessage()` |
| `storehub-uniapp/src/components/ai-robot.vue` | 新增 | 浮动入口 + 对话弹窗组件 |
| `storehub-uniapp/src/pages/home.vue` | 修改 | 引入 `<ai-robot />` |

---

## 已知问题与修复

### 1. serverless 404 Pitfall ⚠️

**问题**: 新增 `chat/postMessage.post.ts` 后，tsc 立即编译生成 `dist/chat/postMessage.post.js`，但 `slr debug` 进程不会自动注册新路由。直接 curl `:3001/chat/message` 返回 404。

**根因**: `@pagoda-serverless/runtime` 启动时静态扫描文件，注册路由后不再监听 `dist/` 变化。

**解决方案**: 新增 serverless 路由后必须**手动重启 serverless 进程**才能验证。

**已写入规格**: `.trellis/spec/storehub-servless/backend/index.md` 新增 "404 Pitfall" 章节

### 2. 对话框被底部导航栏遮住

**问题**: 弹窗 `position: bottom; height: 70vh;` 直接顶到屏幕底部，与 uniapp 的 tabBar 冲突。

**根因**:
1. 项目 5 个 TabBar，底部占约 180rpx
2. 我用 `marginBottom: 140rpx` 是错的 — `marginBottom` 不影响 `position: fixed` 的基点
3. Trellis 没读取 `.trae/rules/project_rules.md`，没看到项目专属规则

**修复**:
- 弹窗改用 `bottom: '180rpx'`，高度 `calc(70vh - 180rpx)`
- 浮动按钮 `bottom: 200rpx`

**已写入规格**:
- `architecture-overview.md` 新增 "TabBar 安全区" 章节
- `storehub-uniapp/frontend/index.md` 新增 "TabBar 安全区" 章节（含禁止模式 + 自检方法）

---

## 自检记录

### ai 后端

```bash
curl -s http://localhost:3000/chat/message -X POST \
  -H "Content-Type: application/json" -d '{"message":"你好"}'
# ✅ status=200, reply=您好！我是百果 AI 助手...
```

### serverless 代理

```bash
# 产物确认
ls dist/chat/postMessage.post.{js,js.map}  # ✅ 存在

# ⚠️ 需手动重启 serverless 进程后才能验证
curl -s http://localhost:3001/chat/message -X POST \
  -H "Content-Type: application/json" -d '{"message":"test"}'
# 重启后应返回: { "code": 0, "data": {...} }
```
