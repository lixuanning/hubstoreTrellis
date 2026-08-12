# storehub-servless — 日志指南

## 日志 API

| 方法 | 使用场景 | 触发条件 |
|------|---------|----------|
| `slrLog.info()` | 请求日志、成功响应 | 非 draft_exc |
| `slrLog.error()` | 所有错误 | 非 draft_exc |
| `slrLog.debug()` | 登录失效详情 | 无限制 |
| `console.log()` | 开发调试 | draft_exc 本地 |

## 请求日志格式（middleware.ts 自动打印）

```
[RequestHandler-收到请求]:/store/getPerformers
[请求头]:{"x-client-platform":"mp-weixin",...}
[请求参数]:{"body":{...},"query":{}}
```

## 下游调用日志

```
# 成功
[成功请求]:/dm-store/task/store/performers
[请求数据]:{...}
[响应数据]:{...}

# 业务失败
[状态码失败]:/dm-store/task/store/performers
[业务码]:500
[错误信息]:参数错误

# 网络异常
[请求异常]:/dm-store/task/store/performers
[错误信息]:timeout of 30000ms exceeded
```

## 日志截断

`handleSliceStr()` 默认截断 5000 字符，防止单个日志过大。

## 生产环境

`RUNTIME_ENV === 'exc'` 时自动去除 `__debugInfo` 中的下游 URL 和请求参数。
