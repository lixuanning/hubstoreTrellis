# StoreHub 工程化文档

> 这里是给**人**看的文档。AI 编码规范在 `.trellis/spec/`。

---

## 文档导航

| 文档 | 适合谁 | 读完你会 |
|------|--------|---------|
| [Trellis 是什么 & 怎么用](./trellis-what-and-how.md) | **所有人先看这个** | 理解 Trellis 怎么工作、你日常怎么做、规范怎么维护 |
| [Trellis 集成实验文档](./trellis-integration-experiment.md) | 想了解完整过程的同事 | 了解安装、配置、关键决策、推广建议 |
| [百果AI助手产品蓝图](./ai-assistant-roadmap.md) | 产品 / 技术 | 了解 AI 功能的产品规划和架构方案 |
| [MCP 设计与使用指南](./mcp-design-and-usage.md) | 开发者 | 配置 AI 编辑器的外部工具（设计稿、接口文档、搜索等） |

---

## 两层文档体系

```
storehub/
├── docs/              ← 你在这里（给人看）
│   ├── trellis-what-and-how.md
│   ├── trellis-integration-experiment.md
│   ├── ai-assistant-roadmap.md
│   └── mcp-design-and-usage.md
│
└── .trellis/spec/     ← AI 自动读（不用人看）
    ├── guides/        ← 架构概览、思维指南
    ├── ai-store-api/  ← 后端规范
    ├── storehub-servless/  ← 中间件规范
    ├── storehub-uniapp/    ← 小程序规范
    └── storehub-web/       ← H5 规范
```

---

## 新人上手路线

```bash
# 1. Clone 仓库（这个仓库只管理规范，不含业务代码）
git clone https://github.com/lixuanning/hubstoreTrellis.git

# 2. 配置 MCP（可选，提升 AI 写代码准确度）
cp mcp.config.example.json .trae/mcp.json
# 编辑 .trae/mcp.json 填入你的 Token

# 3. 开始对话
# 在 Trae / VS Code 里打开项目，直接跟 AI 对话即可
# AI 会自动读取 .trellis/spec/ 理解一切
```
