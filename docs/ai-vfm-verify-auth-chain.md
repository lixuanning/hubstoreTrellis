# AI 复核模块 鉴权链路梳理 v2（含 mclz/xfdj 签名机制）

> 用途：明确 ai-store-api 的 4 套鉴权机制（JWT / mclz / xfdj / 硬编码密码），梳理 vfm-* 为何"裸奔"、以及如何复用现成机制
> 涉及仓库：`storehub-uniapp`、`storehub-servless`、`storehub-web`、`ai-store-api`
> 修订：v3 · 2026-09-02 实施 aixd 签名中间件

---

## 0. 核心结论

| 接口分组 | 鉴权方式 | 现状 | 是否复用现有机制 |
|---|---|---|---|
| `ai-verify/*` | JWT | ✅ 受保护 | — |
| `warning/*` | JWT | ✅ 受保护 | — |
| `aliyun/*` | JWT | ✅ 受保护 | — |
| `logs/*` | JWT | ✅ 受保护 | — |
| `mclz/*` | **mclz 签名** | ✅ 受保护 | — |
| `xfdj/*` | **xfdj 签名** | ✅ 受保护 | — |
| **`vfm-verify/*`**（除 `pipeline-batch`） | **aixd 签名** | ✅ 已加 | 跟 mclz/xfdj 一致模式 |
| **`vfm-verify/pipeline-batch`** | **白名单免签** | ✅ 已加 | 对内批量入口，内网调用无需签名 |
| **`vfm-result/*`** | **aixd 签名** | ✅ 已加 | — |
| **`vfm-sample/*`** | **aixd 签名** | ✅ 已加 | — |
| **`vfm-tag/*`** | **aixd 签名** | ✅ 已加 | — |
| **`vfm-review-prompt/*`** | **aixd 签名** | ✅ 已加 | — |

---

## 1. 4 套鉴权机制全景

### 1.1 JWT（Bearer Token · 适用于"企业内部登录用户"）

**登录入口**（[ai-store-api/src/auth/auth.service.ts:46-59](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/auth/auth.service.ts#L46-L59)）：
```ts
POST /auth/login
Body: { code, current_role, current_orgCode }
  → wechatService.getUserInfo(code)        // 微信 code → user_ticket
  → wechatService.getUserDetail()           // user_ticket → 用户信息
  → rbacService.listPostTypeByPersonnel()   // 查用户角色 / 机构
  → jwtService.sign({ name, userCode, role, sub: userCode })
  → 返回 { token, userCode, name, role }
```

**校验逻辑**（[ai-store-api/src/auth/jwt.strategy.ts:8-20](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/auth/jwt.strategy.ts#L8-L20)）：
```ts
super({
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),  // 必须 header: Authorization: Bearer <token>
  ignoreExpiration: false,
  secretOrKey: configService.get('auth.jwt').secret,
});
```

**挂载方式**：按 controller 单独加 `@UseGuards(JwtAuthGuard)`
- 入口：[ai-store-api/src/ai-verify/ai-review-result.controller.ts:9](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/ai-verify/ai-review-result.controller.ts#L9)

**适合场景**：用户从企业微信登录、有 user_ticket、需要 RBAC 权限校验的接口

---

### 1.2 mclz 签名（Header 签名 · 适用于"明厨亮灶"系统对接）

**客户端签名逻辑**（[storehub-servless/src/cos/mclzSignature.ts:60-75](file:///Users/lidie/a-code/a-pgy/storehub/storehub-servless/src/cos/mclzSignature.ts#L60-L75)）：
```ts
const SIGNA_EXPIRE = 60;                          // 签名 60s 过期
const SIGNA_SECRET = 'pagoda-mclz';                // 共享密钥（硬编码在仓库里）

function getPassWord() {
  return `${SIGNA_SECRET}-${moment().tz('Asia/Shanghai').format('YYYY-MM-DD')}`;
  // 密码 = pagoda-mclz-2026-09-02（按天轮换）
}

export const signature = (body) => {
  const str = Object.assign({}, {
    expire: 60,
    password: getPassWord(),  // 注入 expire + password
  }, body);
  const newStr = createStringByObject(str);  // 序列化：KEY=VAL&...（key 倒序排序）
  return crypto.createHash('md5').update(newStr).digest('hex').toUpperCase();
};
```

**客户端调用示例**（[storehub-servless/src/cos/getAiStoreCosAuth.post.ts:18-26](file:///Users/lidie/a-code/a-pgy/storehub/storehub-servless/src/cos/getAiStoreCosAuth.post.ts#L18-L26)）：
```ts
export function getAiStoreCosAuth() {
  return apis.aiStore.request({
    headers: {
      mclz: signature({}),  // ← header 注入 mclz 签名
    },
    method: 'post',
    url: '/mclz/scan-record/getCosAuthorization',
  });
}
```

**服务端校验逻辑**（[ai-store-api/src/common/middleware/mclz.middleware.ts:5-35](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/common/middleware/mclz.middleware.ts#L5-L35)）：
```ts
@Injectable()
export class MclzMiddleware implements NestMiddleware {
  use(req, res, next) {
    const whiteUrl = ['/mclz/scan-record/save', '/mclz/scan-record/sign'];  // 白名单
    if (whiteUrl.includes(req.originalUrl)) return next();

    if (headers.mclz) {
      const sign = signature(body);  // ← 用同样逻辑重算签名
      if (sign === headers.mclz) next();
      else this.commonRes(res);       // 签名错误：{status: 60000100, message: '签名错误'}
    } else {
      this.commonRes(res, '缺少签名');
    }
  }
}
```

**挂载方式**（[ai-store-api/src/app.module.ts:159-163](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/app.module.ts#L159-L163)）：
```ts
configure(consumer: MiddlewareConsumer): void {
  consumer.apply(LoggerMiddleware).forRoutes('*');
  consumer.apply(MclzMiddleware).forRoutes('mclz*');   // ← 只对 mclz* 路由生效
  consumer.apply(XfdjMiddleware).forRoutes('xfdj*');
}
```

**适用路由**：
- `/mclz/scan-record/*`（明厨扫码、COS、大华录像）
- `/mclz/order/*`
- `/mclz/store/*`
- `/mclz/video/*`

**核心安全点**：
- 共享密钥 `pagoda-mclz`（⚠️ 硬编码在仓库里，安全级别不算高）
- 每日轮换：密码 = `pagoda-mclz-YYYY-MM-DD`
- 签名有效期 60s（防重放）
- 签名内容包含 body，body 被改签名就对不上
- 失败码：`status: 60000100, message: '签名错误'`

---

### 1.3 xfdj 签名（Header 签名 · 适用于"新风到家"系统对接）

逻辑和 mclz **完全一样**，只是：
- Header 名：`x-ai-xfdj`（不是 `mclz`）
- 共享密钥：`pagoda-ai&xfdj`
- 失败码：`status: 70000100`

**实现文件**：
- 客户端：[storehub-servless/src/cos/xfdjSignature.ts](#)（mclz 同源）
- 服务端中间件：[ai-store-api/src/common/middleware/xfdj.middleware.ts](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/common/middleware/xfdj.middleware.ts)
- 签名函数：[ai-store-api/src/common/signature/xfdj.ts:8](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/common/signature/xfdj.ts#L8)

**适用路由**：`/xfdj/*`

---

### 1.4 硬编码密码（最简陋 · 仅用于内部 dev/debug 保护）

**示例**（[ai-store-api/src/app.controller.ts:59-75](file:///Users/lidie/a-code/a-pgy/storehub/ai-store-api/src/app.controller.ts#L59-L75)）：
```ts
@Post('syncWithDisp')
async syncWithDisp(@Body() body: Record<string, any>): Promise<NormalResponse> {
  if (body.pd && body.pd === 'pagoda-mclz-20240529-zxcvbnm,.') {
    await this.storeStructureService.syncWithDisp();
    return { status: 200, message: '同步完成' };
  }
  return { status: 20001, message: '权限不足' };
}
```

调用方需要 body 里带 `pd: 'pagoda-mclz-20240529-zxcvbnm,.'`。
**仅用于内部 dev 调试，不适合生产对外**。

---

## 2. 当前 vfm-* 为什么是裸奔

### 2.1 直接原因

`ai-store-api/src/app.module.ts:159-163` 的 `configure()` 里：
```ts
consumer.apply(MclzMiddleware).forRoutes('mclz*');   // 只覆盖 mclz*
consumer.apply(XfdjMiddleware).forRoutes('xfdj*');   // 只覆盖 xfdj*
// ⚠️ 没有 vfm* 的中间件注册
```

而且 vfm-* 5 个 controller 也没有 `@UseGuards(JwtAuthGuard)`。

### 2.2 调用链路（4 段全部裸奔）

| 调用方 | 服务 | 文件 | 鉴权 | 备注 |
|---|---|---|---|---|
| ① storehub-uniapp | 企业微信小程序 | `storehub-uniapp/src/api/aiRecognition/index.ts` | ❌ 不传 token | — |
| ② storehub-servless | Pagoda BFF | `storehub-servless/src/aiRecognition/reVerifyByIds.post.ts` | ❌ 不传 mclz header | — |
| ③ storehub-web | Vue 后台 | `storehub-web/src/api/modules/aiRecognition.ts` → baseApiUrl=storehub-servless | ❌ 通过 servless 进 | — |
| ④ ai-store-api | NestJS | `ai-store-api/src/ai-recognition/vfm-verify/vfm-verify.controller.ts` | ❌ 无 guard | — |

**典型调用流（web 端）**：
```
storehub-web
  → http.post('/aiRecognition/reVerifyByIds', params)
  → 命中 storehub-servless（pagoda BFF）
  → servless 内 apis.aiImg.post('/vfm-sample/list', req.body)  // 无 auth header
  → 命中 ai-store-api
  → VfmVerifyController.reVerify()  // 无 guard，直接进 service
```

---

## 3. 对比 mclz vs JWT 的适用场景

| 维度 | JWT | mclz 签名 |
|---|---|---|
| 鉴权位置 | Controller (`@UseGuards`) | Middleware（路由级） |
| 凭证 | Bearer Token（有时效） | Header `mclz: <md5>`（60s 过期） |
| 是否需要先登录 | ✅ 是（`/auth/login` 拿 token） | ❌ 否（双方硬编码密钥） |
| 鉴权粒度 | 单接口（per-controller） | 路由前缀（per-prefix） |
| 防重放 | token 过期 | 60s 过期 + 当日密码 |
| 适合场景 | 企业微信内部用户 | 系统间对接（无用户登录） |
| 实现复杂度 | 中（要 JWT 签发 + 校验） | 低（双方算 md5 比对） |
| 安全性 | 中-高（密钥不在仓库） | 低-中（密钥 `pagoda-mclz` 在仓库明文） |

**结论**：
- **对接方调 pipeline / pipeline-batch** → **mclz 签名** 更合适（不需要对接方搞微信登录）
- **企业内部用户** → JWT 更合适（但当前 vfm-* 也没接，web 端用户是怎么调通的？走的是 web → servless 的 pagoda 主登录态，跟 ai-store-api 的 JWT 没关系）

---

## 4. 为什么 vfm-* 之前没加 mclz

推测时间线：
1. mclz 中间件和 sign 接口（`POST /mclz/scan-record/sign`）最初是给"明厨扫码"业务写的
2. `MclzMiddleware.forRoutes('mclz*')` 限定了前缀，只保护 mclz 业务
3. vfm-verify 等是后来新增的业务（最近几轮迭代），加 controller 时**忘了同步加 mclz 守护**
4. 但 servless 端有现成的 `mclzSignature.ts` 和 `getAiStoreCosAuth.post.ts` 范例可参考

---

## 5. 修复方案（推荐复用 mclz 机制）

### 5.1 最小改动：复用 mclz 中间件

**后端 ai-store-api**：

```ts
// src/app.module.ts:159
configure(consumer: MiddlewareConsumer): void {
  consumer.apply(LoggerMiddleware).forRoutes('*');
  consumer.apply(MclzMiddleware).forRoutes('mclz*', 'vfm*');  // ← 加 vfm*
  consumer.apply(XfdjMiddleware).forRoutes('xfdj*');
}
```

⚠️ **风险**：mclz 是给对接方系统用的（"明厨"硬件设备），密钥在仓库公开。如果给 web 后台也用 mclz，等于把"对接方凭证"和"内部用户凭证"混在一起。建议**新增一套 vfm 专用签名**（参考 mclz 实现）。

### 5.2 推荐方案：新增 vfm 专用签名中间件

**思路**：照搬 mclz，但用独立密钥 + 独立失败码

```ts
// 1. 新建 ai-store-api/src/common/signature/vfm.ts
const SIGNA_SECRET = process.env.VFM_PIPELINE_SECRET || 'pagoda-vfm-pipeline-2026';
const SIGNA_EXPIRE = 60;
// 其余代码复制 mclz.ts

// 2. 新建 ai-store-api/src/common/middleware/vfm.middleware.ts
// 复制 mclz.middleware.ts，header 改 x-vfm-pipeline，失败码改 80000100

// 3. 在 app.module.ts 注册
consumer.apply(VfmMiddleware).forRoutes('vfm*');
```

**Servless 端**（`storehub-servless/src/cos/vfmSignature.ts`）：
```ts
import { signature } from './mclzSignature';  // 复用算法
// 或新建 vfmSignature.ts，调同样逻辑
```

**调用示例**（`storehub-servless/src/aiRecognition/reVerifyByIds.post.ts`）：
```ts
import { signature } from '@/cos/vfmSignature';

export const main: Main = async req => {
  const data = await apis.aiStore.post('/vfm-verify/re-verify', req.body, {
    headers: { 'x-vfm-pipeline': signature(req.body || {}) },
  });
  return { data };
};
```

### 5.3 对接方文档需要明确

- 共享密钥：`pagoda-vfm-pipeline-2026`（或环境变量值）
- Header：`x-vfm-pipeline: <md5>`
- 签名算法：md5(upper(KEY)=VAL&...)（KEY 倒序排序，VAL 对象/数组转 JSON）
- 签名内容：`{expire: 60, password: '<密钥>-YYYY-MM-DD', ...body}`
- 有效期：60s
- 失败响应：`{status: 80000100, message: '签名错误'}`

### 5.4 是否要让 uniapp / web 也走 mclz

**不需要**。uniapp / web 是企业内部用户，最终通过 pagoda 主登录态鉴权（storehub-servless 受 pagoda 主框架保护），只要在 servless → ai-store-api 这一跳加 mclz 签名就够了。

具体来说：
- **web 端 → servless**：pagoda 主登录态鉴权（不在 ai-store-api 范围内）
- **uniapp → servless**：pagoda 主登录态鉴权（不在 ai-store-api 范围内）
- **servless → ai-store-api**：需要加 mclz 签名（这是真正裸奔的环节）

---

## 6. 对接方系统接入 pipeline 流程

```
┌─────────────────┐                  ┌──────────────────┐                  ┌──────────────────┐
│   对接方系统     │                  │  storehub-servless│                  │  ai-store-api    │
│  (无企业微信)    │                  │  (Pagoda BFF)     │                  │  (NestJS)        │
└─────────────────┘                  └──────────────────┘                  └──────────────────┘
         │                                    │                                     │
         │ 1. 双方约定密钥                     │                                     │
         │    pagoda-vfm-pipeline-2026        │                                     │
         │                                    │                                     │
         │ 2. 调 /aiRecognition/pipeline       │                                     │
         │    body: { sampleCode, ... }        │                                     │
         ├───────────────────────────────────▶│                                     │
         │                                    │ 3. servless 算签名                  │
         │                                    │    signature(body) → md5            │
         │                                    │ 4. 加 header: x-vfm-pipeline: <md5> │
         │                                    ├────────────────────────────────────▶│
         │                                    │                                     │ 5. VfmMiddleware 校验
         │                                    │                                     │    重算签名 vs header
         │                                    │                                     │ 6. 校验通过 → 进 controller
         │                                    │                                     │    → service → LLM
         │                                    │                                     │ 7. 返回 {sample, result, review}
         │                                    │◀────────────────────────────────────┤
         │◀───────────────────────────────────┤ 8. 透传                            │
         │ 9. 对接方收到结果                    │                                     │
```

**对接方不需要登录、不需要 token**，只需要：
- 共享密钥
- 实现签名算法（按文档）
- 60s 内发完请求

---

## 7. 决策点（待你确认）

| # | 问题 | 选项 |
|---|---|---|
| Q1 | 复用 mclz 还是新建 vfm 专用签名？ | A. 复用 mclz（最快，密钥公开） / B. 新建 vfm 专用（独立密钥，推荐） |
| Q2 | 共享密钥怎么管？ | A. 硬编码仓库（mclz 现状） / B. 环境变量（推荐，部署到 .env） / C. 数据库存（最严） |
| Q3 | 哪些接口走签名？ | A. 只 pipeline / pipeline-batch（对外） / B. 全部 vfm-* 5 个 controller |
| Q4 | 签名有效期？ | A. 60s（mclz 现状） / B. 5min（更宽松） / C. 1h（仅做防重放） |
| Q5 | 白名单（哪些接口免签）？ | A. 全部都要签 / B. 只 list/detail 类查询免签 |
| Q6 | 失败码格式？ | A. 跟 mclz 一致 `60000100` / B. 新建 `80000100`（推荐，便于区分） |

---

> 文档结束。请你过一遍后告诉我决策方向。
