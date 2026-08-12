# storehub-servless — 错误处理

## 全局错误处理（setup.ts errorHandle）

三种异常类型 → 三种响应：

```typescript
// 1. ApiBusinessException — 业务异常
res.json({
  code: e.code,              // 业务错误码
  message: e.message,        // 错误描述
  error: { api, origin, debugInfo }
});

// 2. ServiceException — 下游服务异常
res.json({
  code: e.httpStatusCode,    // HTTP 状态码
  message: '服务异常, ...',
  error: { api, origin, message: e.message }
});

// 3. 未知异常
res.json({
  code: 500,
  message: '服务异常, ...',
  error: { api, origin, message: e.origin }
});

// 所有分支都调用 slrLog.error(e) 记录
```

## 下游响应拦截器异常（api/util.ts）

```typescript
// 下游返回非成功码 → ApiBusinessException
new ApiBusinessException({
  code: result[resCodeKey],
  message: result[resMessageKey],
  origin: `${desc}：${config.url}`,
});

// 网络异常/HTTP 错误 → ServiceException
new ServiceException({
  message: error.message,
  origin: `${desc}：${config.url}`,
});
```

## 登录失效

返回 `code: -9999, message: '登录失效，请重新登录'`，由前端拦截器处理。

## 调试信息保护

非生产环境（`RUNTIME_ENV !== 'exc'`）才附加 `__debugInfo`（含下游 URL、请求参数等）。
