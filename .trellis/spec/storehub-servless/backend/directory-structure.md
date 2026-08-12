# storehub-servless 目录结构

> 基于 `@pagoda-serverless/runtime` 框架，文件系统路由自动映射。有热更新，新增文件不需要重启。

```
src/
├── api/                       # API 代理基础设施（核心）
│   ├── _utils/
│   │   ├── httpService.ts     # axios 实例 + Proxy 懒加载（按需创建微服务实例）
│   │   ├── serviceConfig.ts   # 从 env-config 聚合域名/响应key/headers
│   │   └── debugInfo.ts       # 请求/响应调试信息（非生产环境）
│   ├── env-config/            # 20+ 个下游微服务的环境配置（含 Response 归一化 key）
│   │   ├── index.ts           # 统一 re-export
│   │   ├── dm-store.ts        # 门店作业域
│   │   ├── ai-store.ts        # AI 服务
│   │   └── store-ms.ts / finance.ts / ...（按微服务名命名）
│   └── util.ts                # creatResponseInterceptor + 响应日志
├── middlewares/
│   ├── contacts.ts            # 登录白名单 allowedToPass 数组（精确匹配 + 正则）
│   ├── casMiddleware.ts       # CAS 单点登录中间件
│   └── middleware.ts          # 主认证中间件（JWT 校验 + session 设置）
├── utils/
│   ├── contacts/              # session/user 工具
│   ├── common.ts              # Header/Platform/AppConfig 常量
│   ├── contacts.ts            # defineStoreData/definePageableConfig
│   ├── login.ts               # 企业微信 qwMpSdk 初始化
│   └── user.ts                # 用户会话/权限/角色处理（核心）
├── types/                     # 全局类型声明
├── setup.ts                   # 应用入口（注册中间件、响应转换、全局错误处理）
├── loadEnv.ts                 # dotenv 多层环境变量加载
└── <业务模块>/
    ├── <action>.get.ts        # GET 接口（文件即路由）
    └── <action>.post.ts       # POST 接口

业务模块: chat/ cos/ dailyClearing/ employeeSalary/ finance/ home/ message/
          myInfo/ store/ storeRating/ task/(子模块嵌套) user/ wecom/ workbench/
```

**核心调用链路**:
```
客户端 → casMiddleware(白名单/CAS) → middleware(JWT) → main(req)
  → apis.<微服务名>.post(path, data)
  → creatResponseInterceptor 统一 code 判断
  → transformer 包装为 { code: 0, data }
  → 返回客户端
```
