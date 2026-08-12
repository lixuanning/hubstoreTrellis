# ai-store-api 目录结构

> NestJS 后端服务（端口 3000）。按业务领域分模块，新模块用 `ResponseDto` 模式，旧模块用 `{status, data}` 字面量。

```
src/
├── common/                    # 基础设施层
│   ├── filters/
│   │   └── all-exceptions.filter.ts    # 全局异常过滤器
│   ├── interceptors/
│   │   └── logging.interceptor.ts      # 请求/响应日志 + 操作记录
│   ├── middleware/
│   │   ├── http.middleware.ts          # CORS + Content-Type
│   │   ├── logger.middleware.ts        # 请求日志
│   │   ├── mclz.middleware.ts          # 明厨亮灶认证
│   │   └── xfdj.middleware.ts          # 消费登记认证
│   ├── decorators/
│   │   ├── user.decorator.ts           # @CurrentUser() 装饰器
│   │   └── api-data-response.decorator.ts  # Swagger 文档装饰器
│   ├── interfaces/
│   │   └── response-data.interface.ts  # ResponseDto<T> / NormalResponse
│   └── providers/
│       ├── typeorm-config.service.ts   # TypeORM 配置工厂
│       └── winston-logger.service.ts   # 自定义 Logger
├── config/                    # 配置 namespace（registerAs）
│   ├── common.config.ts / cache.config.ts / typeorm-default.config.ts
├── auth/                      # 认证模块
│   ├── jwt.strategy.ts / jwt-auth.guard.ts / auth.service.ts
│   └── interfaces/user.interface.ts    # User/Role/OrgInfo 类型
├── llm/                       # 大模型服务（@Global() 全局模块）
│   ├── llm.service.ts / llm.module.ts / llm.config.ts
│   └── dto/
├── chat/                      # 智能问答
│   ├── chat.controller.ts / chat.service.ts
│   └── dto/
├── <业务模块>/                # 20+ 个业务模块
│   ├── dto/                   # DTO（请求体校验）
│   ├── *.controller.ts        # @Post/@Get + @UseGuards(JwtAuthGuard)
│   ├── *.service.ts           # 业务逻辑 + TypeORM Repository
│   ├── *.module.ts            # NestJS 模块声明
│   ├── *.config.ts            # 模块配置（registerAs）
│   └── *.entity.ts            # TypeORM @Entity
├── app.module.ts              # 根模块（ConfigModule + TypeORM + 所有子模块）
├── main.ts                    # 入口（Logger/Filter/Interceptor/CORS 全局注册）
└── env/                       # 环境变量文件（.env.development / .test / .production）
```

**两种响应模式**:
```typescript
// 新模块（ResponseDto）
@Post('create')
async create(@Body() dto: CreateDto): Promise<ResponseDto<any>> {
  return new ResponseDto(await this.service.create(dto)); // {status:200, data}
}

// 旧模块（字面量）
@Get()
async index(): Promise<WarningsResponse> {
  return { status: 200, data: { ... } };
}
```
