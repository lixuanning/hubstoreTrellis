# 小程序首页新增简单 API 调用

**任务**: 08-11-home-api-demo  
**状态**: in_progress  
**类型**: 轻量级任务（PRD-only）

---

## 需求

在小程序首页（`storehub-uniapp/src/pages/home.vue`）新增一个简单的 API 调用，验证跨端联调链路是否正常工作。

## 涉及范围

| 端 | 改动 |
|----|------|
| **ai** (NestJS) | 新增 `GET /demo/hello` 接口，返回固定数据 |
| **serverless** (中间件) | 新增 `demo/hello.get.ts`，代理转发到 ai |
| **uniapp** (小程序) | 首页 `onMounted` 中调用该接口，控制台打印结果 |

> 说明：web 端不涉及本次任务。

## 验收标准

- [ ] ai 端 `GET /demo/hello` 返回 `{ status: 200, data: { greeting: "...", timestamp: ... } }`
- [ ] serverless 代理 `/demo/hello`，返回 `{ code: 0, data: { ... } }`（经 result 解析后的统一格式）
- [ ] 小程序首页加载后在控制台打印接口返回数据
- [ ] curl 自检通过（先 ai:3000，再 serverless:3001）
