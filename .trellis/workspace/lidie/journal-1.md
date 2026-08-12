# Journal - lidie (Part 1)

> AI 开发会话日志。仅记录里程碑，日常流水不维护。
> 详见: `.trellis/spec/guides/index.md` → 记忆与知识管理设计
> 开始时间: 2026-08-11

---

## 实验期里程碑 (2026-08-11 ~ 08-12)

### Trellis 初始化
- Monorepo 模式初始化 4 仓库包名映射
- 建立 `.trellis/spec/guides/architecture-overview.md` — 核心调用链路 + Response 归一化表
- 建立 4 个 package 的 `index.md` 入场规范 + `quality-guidelines.md`

### AI 助手 MVP (Phase 0)
- `ai-store-api`: LlmModule (DashScope OpenAI 兼容抽象) + ChatModule (基础问答)
- `storehub-servless`: `/chat/postMessage` 代理转发
- `storehub-uniapp`: ai-robot 浮动入口 + 对话框（含 TabBar 安全区修复）
- 全栈路径对齐规范沉淀（文件名 = 接口路径，三端一致）

### 工程化
- `.trae/mcp.json` 模板（6 个 MCP Server + CoDesign 替代方案）
- `start-dev.sh` — 一键启动 4 端 dev 环境
- `storehub` 根目录 git init + GitHub remote（排除业务仓库）
- 中文注释 + commit-no-push 规则写入 spec

### 踩坑知识沉淀（已写入 spec）
- wd-popup bottom:0 强行覆盖 → TabBar 安全区方案
- serverless 文件路由 = 文件名 → 三端路径对齐
- slr debug 静态路由需手动重启
- login 白名单临时加 → curl → 删除流程

### 下一步
- AI 助手 Phase 1: 门店数据注入 + 多轮对话
- MCP 真正接入验证（Figma → CoDesign 流程跑通）
- Releases 目录建 `test-cases.md` v0.1.0 首次验收

