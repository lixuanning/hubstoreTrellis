# StoreHub MCP 设计与使用指南

> 最后更新: 2026-08-12 | 适用编辑器: Trae / Trae CN

---

## 一句话理解

**MCP（Model Context Protocol）是 AI 编辑器的"USB-C 接口"。** 配置后，AI 在写代码时可以直接读 Figma/CoDesign 设计稿、查 Apifox 接口文档、搜最新技术文档——而不是凭记忆瞎猜。

你现在在 Trae 里跟我对话，我就是通过 MCP 协议读取外部工具的数据来辅助编码。

---

## 当前接入的 6 个 MCP Server

| MCP Server | 优先级 | 作用 | 需要 Token？ |
|---|---|---|---|
| **filesystem-storehub** | ⭐⭐⭐⭐⭐ | 只读 4 个子仓库 `src/` + trellis spec + designs/ 设计稿。替代 Grep/Glob 做精准跨仓库查代码、读设计稿标注 | ❌ 不需要 |
| **apifox** | ⭐⭐⭐⭐⭐ | 自动读接口文档 JSON Schema，生成 apis/service 层代码时字段 100% 对齐后端出参 | ✅ 需要 |
| **tavily-search** | ⭐⭐⭐⭐ | 联网搜索 UniApp / wot-ui / 企业微信最新文档、报错解决方案 | ✅ 需要 |
| **github** | ⭐⭐⭐ | 开 PR、看 CI、diff 分支、查 Issue | ✅ 需要 |
| **amap** | ⭐⭐ | 门店选址/巡店页面画地图、算路线、地址经纬度解析 | ✅ 需要 |
| **figma** | ⏸️ 已弃用 | 公司实际使用 CoDesign，非 Figma。条目保留在配置中备用 | ✅ 需要 |

---

## CoDesign 设计稿方案（路径 A）

### 背景

公司使用腾讯 CoDesign (codesign.qq.com) 而非 Figma。截至 2026.08，CoDesign **没有官方的 MCP Server**，也没有对外开放设计稿节点 OpenAPI。

选定的方案是 **"CoDesign 原生导出 + Filesystem MCP 读图 + AI 多模态"**：

### 操作流程（3 步）

**Step 1：CoDesign 端导出（你或设计师操作）**

1. **代码骨架**：打开设计稿画板 → 右上角「CodeFun 智能生成页面代码」→ 选 UniApp / Vue3 → 导出 `.vue` 先有骨架
2. **标注 PNG**：画板列表「导出」→ 2x 分辨率 → 存到 `storehub/designs/` 按页面分目录：
   ```
   designs/
   ├── xxx-page/
   │   ├── 01-列表页.png
   │   ├── 02-详情态.png
   │   └── 切图/
   │       ├── icon-search@2x.png
   │       └── ...
   ```
3. **切图标注**：进入「切图标注」Tab → 「批量导出」→ 解压到 `designs/xxx-page/切图/`

**Step 2：在对话中使用标准话术**（带 `@Builder with MCP` 前缀）

> @Builder with MCP  
> 参考 `designs/xxx-page/02-详情态.png`，精修 `storehub-uniapp/src/components/xxx.vue` 到 100% 对齐设计稿。注意 TabBar 底部 110rpx 安全区、wot-ui 组件优先。

> @Builder with MCP  
> `designs/xxx-page/CodeFun-export.vue` 是 CoDesign 自动出的代码。按 uniapp 三层架构规范重写：样式对齐 PNG、数据拉 service 层、底部 110rpx 避让 TabBar。

**Step 3：AI 端实际做的事**

1. MCP Filesystem 读 `designs/` 目录下的 PNG + 切图
2. 多模态视觉量尺寸/色值/间距
3. 按 `.trellis/spec/storehub-uniapp/` 规范（TabBar、三层 API、wot-ui）直接产出正确代码

### 升级路径（路径 B）

CoDesign 网页端内部 API 可以通过 F12 抓取。如果未来要自制 CoDesign MCP Server（能按节点精确查图层尺寸、色值、间距，体验接近 Figma MCP），只需要配合抓取 2-3 个请求的 headers + URL，半天就能写出一个基于 FastMCP 的最小可用版本。

---

## 启用步骤

### 1. 部署配置文件

```bash
cd /Users/lidie/a-code/a-pgy/storehub
cp mcp.config.example.json .trae/mcp.json
```

### 2. 开启项目级 MCP

Trae 右上角 ⚙️ 设置 → 左侧【MCP】→ 打开「启用项目级 MCP」→ 弹窗确认

### 3. 填写 Token

编辑 `.trae/mcp.json`，将 5 个 `REPLACE_WITH_...` 替换为真实 Token：

| 配置项 | 获取方式 |
|---|---|
| `APIFOX_ACCESS_TOKEN` + `APIFOX_PROJECT_ID` | apifox.cn → 头像 →「账号设置」→「API 令牌」→ 新建；项目 ID 在 URL 里 |
| `TAVILY_API_KEY` | tavily.com 注册，每月 1000 次免费 |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | github.com/settings/tokens → Fine-grained PAT，勾 repo + read:org |
| `AMAP_WEB_SERVICE_KEY` | [高德开放平台](https://console.amap.com/) → 应用管理 → 新建应用 → Web 服务 Key |

### 4. 验证

Trae MCP 面板里每个 Server 状态显示 `running` 即成功，可以开始用 `@Builder with MCP` 对话。

### 5. 安全

`.trae/mcp.json` 含 Token，**不要提交到 Git**。模板文件 `mcp.config.example.json` 是占位符可以提交。

---

## MCP 架构说明（如果要在其他 AI 编辑器里复用）

本项目的 MCP 配置遵循标准的 JSON-RPC 2.0 协议，所有 Server 均为 **npx 本地 stdio 模式**：

```
Trae（MCP Host）
  ├── filesystem-storehub（stdio，本地只读文件系统）
  ├── apifox（stdio，HTTP 调 Apifox API）
  ├── tavily-search（stdio，HTTP 搜索）
  ├── github（stdio，HTTP 调 GitHub API）
  ├── amap（stdio，HTTP 调高德 API）
  └── figma（已弃用，备用）
```

配置文件 `mcp.config.example.json` 是标准 MCP 配置格式，可以直接搬到 Cursor / Claude Desktop 等任意支持 MCP 的编辑器使用。

---

## 文件清单

| 文件 | 说明 |
|---|---|
| `mcp.config.example.json` | 配置模板（含占位符，可提交 Git） |
| `.trae/mcp.json` | 实际生效的配置（含真实 Token，不提交） |
| `designs/` | 设计稿导出目录（CoDesign → PNG → 这里），Filesystem MCP 已授权只读 |
